import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/di_providers.dart';
import '../../../shared/repositories/referral_repository.dart';

/// Unified referral programme providers.
///
/// Kept beside the existing engagement providers rather than replacing them:
/// the Refer-and-Earn screen still reads `referralSummaryProvider` from the
/// older `/customer-web/referrals` endpoint, and both continue to work.
final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepository(ref.watch(apiClientProvider));
});

/// The customer's referral dashboard: code, share link, reward terms and the
/// list of people they referred.
final referralDashboardProvider = FutureProvider<ReferralDashboard>((ref) {
  return ref.watch(referralRepositoryProvider).fetchDashboard();
});

/// Rewards the customer can spend right now. Empty is the normal state for
/// most customers, so consumers should render nothing rather than an error.
final referralDiscountsProvider = FutureProvider<List<ReferralDiscount>>((ref) {
  return ref.watch(referralRepositoryProvider).fetchDiscounts();
});
