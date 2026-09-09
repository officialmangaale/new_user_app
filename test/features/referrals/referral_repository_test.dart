import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/shared/repositories/referral_repository.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

ReferralRepository repositoryServing(Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = _StubAdapter(body);
  return ReferralRepository(ApiClient(restaurantDio: dio, userDio: dio));
}

void main() {
  group('dashboard', () {
    test('parses the live customer programme', () async {
      final repository = repositoryServing({
        'status': 'success',
        'data': {
          'program_type': 'customer_referral',
          'enabled': true,
          'code': 'MG7KQP4XAB',
          'share_link': 'https://mangaale.com/r/MG7KQP4XAB',
          'share_message': 'Order on Mangaale with my code MG7KQP4XAB.',
          'reward_summary': '50% off your next 3 orders',
          'pending_count': 2,
          'qualified_count': 1,
          'rewarded_count': 4,
          'total_earned_millis': 200000,
          'referrals': [
            {
              'referral_id': 11,
              'status': 'rewarded',
              'masked_name': 'Amrit K.',
              'reward_millis': 50000,
            },
            {
              'referral_id': 12,
              'status': 'pending',
              'masked_name': 'New user',
              'reward_millis': 0,
            },
          ],
        },
      });

      final dashboard = await repository.fetchDashboard();

      expect(dashboard.enabled, isTrue);
      expect(dashboard.code, 'MG7KQP4XAB');
      // The wording comes from the server so the app and admin panel cannot
      // describe the same offer differently.
      expect(dashboard.rewardSummary, '50% off your next 3 orders');
      expect(dashboard.rewardedCount, 4);
      expect(dashboard.referrals, hasLength(2));
      expect(dashboard.referrals.first.isEarned, isTrue);
      expect(dashboard.referrals.first.maskedName, 'Amrit K.');
    });

    test('a disabled programme still yields a usable screen', () async {
      final repository = repositoryServing({
        'data': {
          'enabled': false,
          'code': 'MG7KQP4XAB',
          'share_link': 'https://mangaale.com/r/MG7KQP4XAB',
          'reward_summary': '',
          'referrals': [],
        },
      });

      final dashboard = await repository.fetchDashboard();

      expect(dashboard.enabled, isFalse);
      // The code survives so links already shared keep meaning something.
      expect(dashboard.code, 'MG7KQP4XAB');
      expect(dashboard.rewardSummary, isEmpty);
      expect(dashboard.referrals, isEmpty);
    });

    test('missing fields degrade rather than throw', () async {
      final repository = repositoryServing({'data': {}});
      final dashboard = await repository.fetchDashboard();
      expect(dashboard.code, isEmpty);
      expect(dashboard.pendingCount, 0);
      expect(dashboard.referrals, isEmpty);
    });
  });

  group('referral status labels', () {
    test('every lifecycle state reads as something a customer understands', () {
      String labelFor(String status) => ReferralEntry(
            referralId: '1',
            status: status,
            maskedName: 'A',
            rewardMillis: 0,
          ).label;

      expect(labelFor('pending'), 'Waiting for their first order');
      expect(labelFor('fraud_review'), 'Being reviewed');
      expect(labelFor('qualified'), 'Reward on its way');
      expect(labelFor('reward_pending'), 'Reward on its way');
      expect(labelFor('rewarded'), 'Reward earned');
      expect(labelFor('rejected'), 'Not eligible');

      // "fraud_review" must never be shown raw: it accuses the customer.
      for (final status in ['pending', 'fraud_review', 'reward_pending']) {
        expect(labelFor(status), isNot(contains('_')));
        expect(labelFor(status).toLowerCase(), isNot(contains('fraud')));
      }
    });
  });

  group('discounts', () {
    test('parses remaining uses of a multi-use reward', () async {
      final repository = repositoryServing({
        'data': [
          {
            'reward_id': 7,
            'reward_type': 'percent_discount',
            'amount_millis': 0,
            'percent': 50,
            'max_discount_millis': 0,
            'total_uses': 3,
            'remaining_uses': 2,
            'summary': '50% off your next 2 orders',
          },
        ],
      });

      final discounts = await repository.fetchDiscounts();

      expect(discounts, hasLength(1));
      expect(discounts.single.remainingUses, 2);
      expect(discounts.single.totalUses, 3);
      expect(discounts.single.summary, '50% off your next 2 orders');
    });

    test('no discounts is a normal empty list, not a failure', () async {
      final repository = repositoryServing({'data': []});
      expect(await repository.fetchDiscounts(), isEmpty);
    });

    // Must agree with Reward.DiscountFor in internal/referralcore/models.go.
    test('discount maths matches the backend', () {
      const fiftyPercent = ReferralDiscount(
        rewardId: 1,
        rewardType: 'percent_discount',
        amountMillis: 0,
        percent: 50,
        maxDiscountMillis: 0,
        totalUses: 3,
        remainingUses: 3,
        summary: '',
      );

      // The ₹70 order from the checkout screen.
      expect(fiftyPercent.discountFor(70000), 35000);
      expect(fiftyPercent.discountFor(200000), 100000);
      expect(fiftyPercent.discountFor(0), 0);

      const capped = ReferralDiscount(
        rewardId: 1,
        rewardType: 'percent_discount',
        amountMillis: 0,
        percent: 50,
        maxDiscountMillis: 120000,
        totalUses: 3,
        remainingUses: 3,
        summary: '',
      );
      // A ₹1000 order is capped at ₹120 rather than giving ₹500 away.
      expect(capped.discountFor(1000000), 120000);
      expect(capped.discountFor(100000), 50000);

      const flat = ReferralDiscount(
        rewardId: 2,
        rewardType: 'flat_discount',
        amountMillis: 100000,
        percent: 0,
        maxDiscountMillis: 0,
        totalUses: 1,
        remainingUses: 1,
        summary: '',
      );
      // Never discount more than the order is worth.
      expect(flat.discountFor(40000), 40000);

      const walletCredit = ReferralDiscount(
        rewardId: 3,
        rewardType: 'wallet_credit',
        amountMillis: 50000,
        percent: 0,
        maxDiscountMillis: 0,
        totalUses: 1,
        remainingUses: 1,
        summary: '',
      );
      // A wallet credit is not an order discount.
      expect(walletCredit.discountFor(200000), 0);
    });
  });

  group('applying a code', () {
    test('a rejected code is a message, not an exception', () async {
      final repository = repositoryServing({
        'data': {'applied': false, 'message': 'That referral code is not valid.'},
      });

      final result = await repository.applyCode('NOPE');

      expect(result.applied, isFalse);
      expect(result.message, 'That referral code is not valid.');
    });

    test('a code held for review is reported honestly', () async {
      final repository = repositoryServing({
        'data': {
          'applied': true,
          'status': 'fraud_review',
          'message':
              'Referral code applied. It is being reviewed and your reward will follow once confirmed.',
          'held_for_review': true,
        },
      });

      final result = await repository.applyCode('MG7KQP4XAB');

      expect(result.applied, isTrue);
      // The customer must not be promised a reward that is still under review.
      expect(result.heldForReview, isTrue);
      expect(result.message, contains('reviewed'));
    });
  });
}
