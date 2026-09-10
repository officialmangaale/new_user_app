import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/storage/referral_storage.dart';

/// A referral link is opened before the customer has an account, so the code
/// has to survive until signup. These pin what is kept, refused and expired.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  final storage = ReferralStorage();
  final now = DateTime(2026, 9, 10);

  group('code shape', () {
    test('accepts a customer code in any casing', () {
      for (final raw in ['MG7KQP4XAB', 'mg7kqp4xab', '  MG7KQP4XAB  ']) {
        expect(ReferralStorage.isCustomerReferralCode(raw), isTrue, reason: raw);
      }
    });

    // A customer attributed to a rider programme would never qualify.
    test('refuses codes from the other programmes', () {
      expect(ReferralStorage.isCustomerReferralCode('MDF4A3M8TG'), isFalse);
      expect(ReferralStorage.isCustomerReferralCode('MR7KQP4XAB'), isFalse);
    });

    test('refuses the wrong shape', () {
      for (final bad in ['MG7KQP4X', 'MG7KQP4XABX', 'MG7KQP4X!', '', null]) {
        expect(ReferralStorage.isCustomerReferralCode(bad), isFalse, reason: '$bad');
      }
    });
  });

  group('storing', () {
    test('stores the first valid code', () async {
      expect(await storage.storePendingCode('MG7KQP4XAB', now: now), isTrue);
      expect(await storage.readPendingCode(now: now), 'MG7KQP4XAB');
    });

    test('upper-cases what was pasted', () async {
      await storage.storePendingCode('mg7kqp4xab', now: now);
      expect(await storage.readPendingCode(now: now), 'MG7KQP4XAB');
    });

    // The server keeps the first attribution, so the app must not promise a
    // different referrer.
    test('keeps the first referrer when a second link is opened', () async {
      await storage.storePendingCode('MG7KQP4XAB', now: now);
      expect(await storage.storePendingCode('MGAAAAAAAA', now: now), isFalse);
      expect(await storage.readPendingCode(now: now), 'MG7KQP4XAB');
    });

    test('never stores a code from another programme', () async {
      expect(await storage.storePendingCode('MDF4A3M8TG', now: now), isFalse);
      expect(await storage.readPendingCode(now: now), isNull);
    });
  });

  group('expiry', () {
    test('a code past the retention window is not returned', () async {
      await storage.storePendingCode('MG7KQP4XAB', now: now);
      final later = now.add(ReferralStorage.ttl + const Duration(days: 1));
      expect(await storage.readPendingCode(now: later), isNull);
    });

    test('a code inside the window is still returned', () async {
      await storage.storePendingCode('MG7KQP4XAB', now: now);
      final later = now.add(ReferralStorage.ttl - const Duration(hours: 1));
      expect(await storage.readPendingCode(now: later), 'MG7KQP4XAB');
    });

    // Reading an expired code clears it, so a stale referral cannot resurface.
    test('an expired code is discarded, not merely hidden', () async {
      await storage.storePendingCode('MG7KQP4XAB', now: now);
      final later = now.add(ReferralStorage.ttl + const Duration(days: 1));
      await storage.readPendingCode(now: later);
      expect(await storage.readPendingCode(now: now), isNull);
    });
  });

  test('clearing removes the code', () async {
    await storage.storePendingCode('MG7KQP4XAB', now: now);
    await storage.clearPendingCode();
    expect(await storage.readPendingCode(now: now), isNull);
  });
}
