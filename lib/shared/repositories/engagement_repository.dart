import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../../core/services/api_exception.dart';
import '../models/app_models.dart';
import 'json_readers.dart';

/// Wallet, referrals and shared (group-buy) orders.
///
/// Backed by the customer-engagement endpoints added in restaurant-service
/// (migration 079). All are restaurant-scoped to the authenticated customer.
class EngagementRepository {
  const EngagementRepository(this._client);

  final ApiClient _client;

  // ------------------------------------------------------------------
  // wallet
  // ------------------------------------------------------------------

  /// GET /customer-web/wallet
  Future<WalletStatement> fetchWallet() async {
    final data = await _getObject('/customer-web/wallet');
    final balance = data['balance'];
    final balanceJson = balance is Map
        ? Map<String, dynamic>.from(balance)
        : <String, dynamic>{};

    return WalletStatement(
      balance: readDouble(balanceJson, const ['balance']),
      currency: readString(balanceJson, const ['currency']),
      status: readString(balanceJson, const ['status']),
      transactions: readList(data, 'entries')
          .map(
            (entry) => WalletTransaction(
              title: _entryTitle(entry),
              date: readString(entry, const ['created_at']),
              amount: readDouble(entry, const ['amount']).round(),
              iconName: _entryIcon(readString(entry, const ['entry_type'])),
            ),
          )
          .toList(growable: false),
    );
  }

  String _entryTitle(Map<String, dynamic> entry) {
    final description = readString(entry, const ['description']);
    if (description.isNotEmpty) return description;
    return switch (readString(entry, const ['entry_type'])) {
      'referral_reward' => 'Referral reward',
      'refund' => 'Refund',
      'cashback' => 'Cashback',
      'debit' => 'Paid from wallet',
      _ => 'Wallet credit',
    };
  }

  String _entryIcon(String entryType) => switch (entryType) {
    'referral_reward' => 'people',
    'refund' => 'undo',
    'cashback' => 'savings',
    'debit' => 'shopping_bag',
    _ => 'account_balance_wallet',
  };

  // ------------------------------------------------------------------
  // referrals
  // ------------------------------------------------------------------

  /// GET /customer-web/referrals
  Future<ReferralSummary> fetchReferrals() async {
    final data = await _getObject('/customer-web/referrals');
    return ReferralSummary(
      code: readString(data, const ['code']),
      shareMessage: readString(data, const ['share_message']),
      totalReferrals: readInt(data, const ['total_referrals']),
      pendingCount: readInt(data, const ['pending_count']),
      rewardedCount: readInt(data, const ['rewarded_count']),
      totalEarned: readDouble(data, const ['total_earned']).round(),
    );
  }

  /// POST /customer-web/referrals/apply
  Future<void> applyReferralCode(String code) async {
    await _post('/customer-web/referrals/apply', <String, dynamic>{
      'code': code,
    });
  }

  // ------------------------------------------------------------------
  // shared (group-buy) orders
  // ------------------------------------------------------------------

  /// GET /customer-web/shared-orders
  Future<List<SharedGroup>> fetchSharedGroups({
    DeliveryMode? mode,
    double? lat,
    double? lng,
  }) async {
    final raw = await _get(
      '/customer-web/shared-orders',
      query: <String, dynamic>{
        'mode': ?mode?.name,
        'lat': ?lat,
        'lng': ?lng,
      },
    );
    return listFrom(raw, keys: const ['groups'])
        .map(_group)
        .toList(growable: false);
  }

  /// GET /customer-web/shared-orders/:groupId
  Future<SharedGroupDetail> fetchSharedGroup(String groupId) async {
    final data = await _getObject('/customer-web/shared-orders/$groupId');
    final group = data['group'];
    return SharedGroupDetail(
      group: _group(
        group is Map ? Map<String, dynamic>.from(group) : <String, dynamic>{},
      ),
      joined: group is Map && group['joined'] == true,
      participants: readList(data, 'participants')
          .map(
            (participant) => SharedGroupParticipant(
              userId: readString(participant, const ['user_id']),
              name: readString(participant, const ['name']),
              isHost: readBool(participant, const ['is_host']),
            ),
          )
          .toList(growable: false),
    );
  }

  /// POST /customer-web/shared-orders
  Future<SharedGroup> createSharedGroup({
    required String restaurantId,
    required String title,
    required int requiredParticipants,
    required int maxParticipants,
    DeliveryMode mode = DeliveryMode.food,
    String? subtitle,
    int? expiresInMinutes,
  }) async {
    final data = await _post('/customer-web/shared-orders', <String, dynamic>{
      'restaurant_id': int.tryParse(restaurantId) ?? restaurantId,
      'title': title,
      'subtitle': ?subtitle,
      'mode': mode.name,
      'required_participants': requiredParticipants,
      'max_participants': maxParticipants,
      'expires_in_minutes': ?expiresInMinutes,
    });
    return _group(data);
  }

  /// POST /customer-web/shared-orders/:groupId/join
  Future<void> joinSharedGroup(String groupId) async {
    await _post('/customer-web/shared-orders/$groupId/join', null);
  }

  /// POST /customer-web/shared-orders/:groupId/leave
  Future<void> leaveSharedGroup(String groupId) async {
    await _post('/customer-web/shared-orders/$groupId/leave', null);
  }

  /// Maps a backend group onto the app's existing [SharedGroup] model.
  ///
  /// `savings` is a rupee figure the backend does not return — the discount is
  /// expressed as a percentage ladder — so it stays 0 rather than being
  /// fabricated. The real saving is applied by `/cart/validate` at checkout.
  SharedGroup _group(Map<String, dynamic> json) {
    return SharedGroup(
      id: readString(json, const ['group_id']),
      title: readString(json, const ['title']),
      subtitle: readString(json, const ['subtitle', 'restaurant_name']),
      participants: readInt(json, const ['participant_count']),
      requiredParticipants: readInt(json, const ['required_participants']),
      distanceKm: readDouble(json, const ['distance_km']),
      minutesLeft: readInt(json, const ['minutes_left']),
      currentDiscount: readDouble(json, const ['current_discount']).round(),
      maximumDiscount: readDouble(json, const ['maximum_discount']).round(),
      deliveryDiscount: readDouble(json, const ['delivery_discount']).round(),
      savings: 0,
      imageUrl: readString(json, const ['image_url']),
      mode: readString(json, const ['mode']) == 'grocery'
          ? DeliveryMode.grocery
          : DeliveryMode.food,
    );
  }

  // ------------------------------------------------------------------
  // transport
  // ------------------------------------------------------------------

  Future<Object?> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _client.restaurant.get<dynamic>(
        path,
        queryParameters: (query == null || query.isEmpty) ? null : query,
      );
      return unwrapApiResponse(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> _getObject(String path) async {
    final raw = await _get(path);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _post(String path, Object? body) async {
    try {
      final response = await _client.restaurant.post<dynamic>(path, data: body);
      return unwrapApiObject(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}

class WalletStatement {
  const WalletStatement({
    required this.balance,
    required this.currency,
    required this.status,
    required this.transactions,
  });

  final double balance;
  final String currency;
  final String status;
  final List<WalletTransaction> transactions;
}

class ReferralSummary {
  const ReferralSummary({
    required this.code,
    required this.shareMessage,
    required this.totalReferrals,
    required this.pendingCount,
    required this.rewardedCount,
    required this.totalEarned,
  });

  final String code;
  final String shareMessage;
  final int totalReferrals;
  final int pendingCount;
  final int rewardedCount;
  final int totalEarned;
}

class SharedGroupParticipant {
  const SharedGroupParticipant({
    required this.userId,
    required this.name,
    required this.isHost,
  });

  final String userId;
  final String name;
  final bool isHost;
}

class SharedGroupDetail {
  const SharedGroupDetail({
    required this.group,
    required this.joined,
    required this.participants,
  });

  final SharedGroup group;
  final bool joined;
  final List<SharedGroupParticipant> participants;
}
