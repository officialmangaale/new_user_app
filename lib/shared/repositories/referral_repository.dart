import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../../core/services/api_exception.dart';
import 'json_readers.dart';

/// The unified referral programme (restaurant-service `internal/referralcore`,
/// migrations 088/089).
///
/// Deliberately separate from [EngagementRepository], which serves the older
/// `/customer-web/referrals` endpoints that the Refer-and-Earn screen already
/// uses. Both continue to work: this one adds what the older one cannot
/// express — the reward terms, whether the programme is currently live, and
/// multi-use discounts with their remaining uses.
///
/// Money crosses the wire as integer milli-rupees, matching the backend. It is
/// converted to rupees only at the point of display.
class ReferralRepository {
  const ReferralRepository(this._client);

  final ApiClient _client;

  /// The customer programme. The other two programme types exist for the
  /// restaurant-owner and rider apps and are never requested from here.
  static const String customerProgram = 'customer_referral';

  /// GET /referrals/customer_referral/me
  Future<ReferralDashboard> fetchDashboard() async {
    final data = await _getObject('/referrals/$customerProgram/me');
    return ReferralDashboard.fromJson(data);
  }

  /// GET /referrals/customer_referral/discounts
  ///
  /// Only what the customer can actually spend right now: available, unexpired
  /// and with uses left. The backend filters, so the app never has to decide
  /// whether a reward is still usable.
  Future<List<ReferralDiscount>> fetchDiscounts() async {
    try {
      final response = await _client.restaurant.get<dynamic>(
        '/referrals/$customerProgram/discounts',
      );
      return unwrapApiList(response.data)
          .map(ReferralDiscount.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// POST /referrals/customer_referral/apply
  ///
  /// A rejected code is a normal outcome, not an error: the backend answers
  /// 200 with `applied: false` and a message written for the customer.
  Future<ApplyReferralResult> applyCode(String code, {String? deviceId}) async {
    try {
      final response = await _client.restaurant.post<dynamic>(
        '/referrals/$customerProgram/apply',
        data: <String, dynamic>{'code': code, 'device_id': ?deviceId},
      );
      return ApplyReferralResult.fromJson(unwrapApiObject(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// GET /referrals/customer_referral/validate?code=…
  ///
  /// A read-only pre-check for a signup or checkout form. Creates nothing.
  Future<bool> validateCode(String code) async {
    try {
      final response = await _client.restaurant.get<dynamic>(
        '/referrals/$customerProgram/validate',
        queryParameters: <String, dynamic>{'code': code},
      );
      return readBool(unwrapApiObject(response.data), const ['valid']);
    } on DioException {
      // A failed pre-check must never block the form; the real decision is
      // made by apply().
      return false;
    }
  }

  Future<Map<String, dynamic>> _getObject(String path) async {
    try {
      final response = await _client.restaurant.get<dynamic>(path);
      return unwrapApiObject(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}

/// The customer's referral screen, as the backend describes it.
class ReferralDashboard {
  const ReferralDashboard({
    required this.enabled,
    required this.code,
    required this.shareLink,
    required this.shareMessage,
    required this.rewardSummary,
    required this.pendingCount,
    required this.qualifiedCount,
    required this.rewardedCount,
    required this.totalEarnedMillis,
    required this.referrals,
  });

  /// False when the programme is switched off. The screen still shows the code
  /// so a customer's existing links keep meaning something, but it should not
  /// promise a reward.
  final bool enabled;
  final String code;
  final String shareLink;
  final String shareMessage;

  /// Human sentence built server-side, e.g. "50% off your next 3 orders", so
  /// the app never assembles reward wording from parts and cannot drift from
  /// what the admin panel shows.
  final String rewardSummary;

  final int pendingCount;
  final int qualifiedCount;
  final int rewardedCount;
  final int totalEarnedMillis;
  final List<ReferralEntry> referrals;

  factory ReferralDashboard.fromJson(Map<String, dynamic> json) {
    final rawReferrals = json['referrals'];
    return ReferralDashboard(
      enabled: readBool(json, const ['enabled']),
      code: readString(json, const ['code']),
      shareLink: readString(json, const ['share_link']),
      shareMessage: readString(json, const ['share_message']),
      rewardSummary: readString(json, const ['reward_summary']),
      pendingCount: readInt(json, const ['pending_count']),
      qualifiedCount: readInt(json, const ['qualified_count']),
      rewardedCount: readInt(json, const ['rewarded_count']),
      totalEarnedMillis: readInt(json, const ['total_earned_millis']),
      referrals: rawReferrals is List
          ? rawReferrals
                .whereType<Map>()
                .map((e) => ReferralEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
          : const <ReferralEntry>[],
    );
  }
}

/// One referral on the customer's list. The referred person is identified only
/// by a masked name — a referrer can see that their referral converted, not
/// harvest contact details.
class ReferralEntry {
  const ReferralEntry({
    required this.referralId,
    required this.status,
    required this.maskedName,
    required this.rewardMillis,
  });

  final String referralId;
  final String status;
  final String maskedName;
  final int rewardMillis;

  factory ReferralEntry.fromJson(Map<String, dynamic> json) {
    return ReferralEntry(
      referralId: readString(json, const ['referral_id']),
      status: readString(json, const ['status']),
      maskedName: readString(json, const ['masked_name']),
      rewardMillis: readInt(json, const ['reward_millis']),
    );
  }

  /// Customer-facing wording for a lifecycle state. The raw states are
  /// operational vocabulary and mean nothing to a customer.
  String get label => switch (status) {
    'pending' => 'Waiting for their first order',
    'fraud_review' => 'Being reviewed',
    'qualified' || 'reward_pending' => 'Reward on its way',
    'rewarded' => 'Reward earned',
    'rejected' => 'Not eligible',
    'expired' => 'Expired',
    'reversed' => 'Reversed',
    _ => status,
  };

  bool get isEarned => status == 'rewarded';
}

/// A reward the customer can apply to an order right now.
class ReferralDiscount {
  const ReferralDiscount({
    required this.rewardId,
    required this.rewardType,
    required this.amountMillis,
    required this.percent,
    required this.maxDiscountMillis,
    required this.totalUses,
    required this.remainingUses,
    required this.summary,
  });

  final int rewardId;
  final String rewardType;
  final int amountMillis;
  final double percent;
  final int maxDiscountMillis;
  final int totalUses;
  final int remainingUses;
  final String summary;

  factory ReferralDiscount.fromJson(Map<String, dynamic> json) {
    return ReferralDiscount(
      rewardId: readInt(json, const ['reward_id']),
      rewardType: readString(json, const ['reward_type']),
      amountMillis: readInt(json, const ['amount_millis']),
      percent: readDouble(json, const ['percent']),
      maxDiscountMillis: readInt(json, const ['max_discount_millis']),
      totalUses: readInt(json, const ['total_uses']),
      remainingUses: readInt(json, const ['remaining_uses']),
      summary: readString(json, const ['summary']),
    );
  }

  /// Mirrors `Reward.DiscountFor` on the backend so the cart can preview the
  /// saving. The server recomputes it at redemption — this is display only and
  /// is never trusted as the amount actually applied.
  int discountFor(int orderMillis) {
    if (orderMillis <= 0) return 0;
    var discount = switch (rewardType) {
      'percent_discount' => (orderMillis * percent / 100).floor(),
      'flat_discount' => amountMillis,
      _ => 0,
    };
    if (maxDiscountMillis > 0 && discount > maxDiscountMillis) {
      discount = maxDiscountMillis;
    }
    if (discount > orderMillis) discount = orderMillis;
    return discount;
  }
}

/// Outcome of typing a referral code.
class ApplyReferralResult {
  const ApplyReferralResult({
    required this.applied,
    required this.message,
    required this.heldForReview,
  });

  final bool applied;
  final String message;

  /// True when the referral was accepted but held for a fraud check, so the
  /// app can set the right expectation instead of promising a reward.
  final bool heldForReview;

  factory ApplyReferralResult.fromJson(Map<String, dynamic> json) {
    return ApplyReferralResult(
      applied: readBool(json, const ['applied']),
      message: readString(json, const ['message']),
      heldForReview: readBool(json, const ['held_for_review']),
    );
  }
}
