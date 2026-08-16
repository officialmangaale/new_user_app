import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/engagement_repository.dart';
import '../../authentication/providers/auth_providers.dart';

final engagementRepositoryProvider = Provider<EngagementRepository>((ref) {
  return EngagementRepository(ref.watch(apiClientProvider));
});

final walletProvider = FutureProvider<WalletStatement>((ref) {
  return ref.watch(engagementRepositoryProvider).fetchWallet();
});

final referralSummaryProvider = FutureProvider<ReferralSummary>((ref) {
  return ref.watch(engagementRepositoryProvider).fetchReferrals();
});

/// Joinable groups for the active delivery mode.
final sharedGroupsProvider = FutureProvider.family<List<SharedGroup>, DeliveryMode>(
  (ref, mode) {
    return ref.watch(engagementRepositoryProvider).fetchSharedGroups(mode: mode);
  },
);

final sharedGroupProvider = FutureProvider.family<SharedGroupDetail, String>((
  ref,
  groupId,
) {
  return ref.watch(engagementRepositoryProvider).fetchSharedGroup(groupId);
});
