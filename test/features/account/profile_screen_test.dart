import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/error/failures.dart';
import 'package:turquoise_delivery/features/account/presentation/profile_screen.dart';
import 'package:turquoise_delivery/features/account/providers/engagement_providers.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';
import 'package:turquoise_delivery/shared/repositories/engagement_repository.dart';

const _wallet = WalletStatement(
  balance: 0, currency: 'INR', status: 'active', transactions: [],
);
const _referral = ReferralSummary(
  code: 'X', shareMessage: '', totalReferrals: 0,
  pendingCount: 0, rewardedCount: 0, totalEarned: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({
        'auth_token': 'test-token',
        'guest_authenticated': true,
      }));

  Future<void> pumpProfile(
    WidgetTester tester, {
    required Future<CustomerProfile> Function() profile,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => profile()),
          walletProvider.overrideWith((ref) async => _wallet),
          referralSummaryProvider.overrideWith((ref) async => _referral),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a loaded profile shows the name, phone and Edit profile',
      (tester) async {
    await pumpProfile(
      tester,
      profile: () async => const CustomerProfile(
        id: 'usr_91',
        name: 'Gursevak',
        phone: '9876543210',
        email: 'g@example.com',
      ),
    );

    expect(find.text('Gursevak'), findsOneWidget);
    expect(find.textContaining('43210'), findsOneWidget,
        reason: 'the masked phone should be shown');
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Loading your details…'), findsNothing);
  });

  testWidgets('a failed profile load says so instead of loading forever',
      (tester) async {
    await pumpProfile(
      tester,
      profile: () async => throw const NetworkFailure('offline'),
    );

    expect(find.textContaining('Could not load your details'), findsOneWidget);
    expect(find.text('Loading your details…'), findsNothing);
    // The account is still signed in, so editing stays available.
    expect(find.text('Edit profile'), findsOneWidget);
  });
}
