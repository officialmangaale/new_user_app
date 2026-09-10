import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/providers/engagement_providers.dart';
import '../../account/providers/referral_providers.dart';
import '../../orders/providers/orders_providers.dart';

/// Providers whose cached value belongs to one signed-in customer.
///
/// None of these are `autoDispose`, so without an explicit invalidation their
/// value outlives the session that produced it. On a shared device the next
/// person to sign in would briefly see the previous customer's addresses,
/// payment methods, order history, wallet balance and profile — their name and
/// phone number — until each provider happened to refetch.
///
/// Catalog, search and location providers are deliberately absent: they hold
/// public data that is identical for every customer, and clearing them would
/// only cause needless refetching.
///
/// **When adding a provider that returns data for the signed-in customer, add
/// it here too.** That is the whole contract of this file.
void invalidateSessionScopedProviders(Ref ref) {
  // Account and identity
  ref.invalidate(profileProvider);
  ref.invalidate(addressesProvider);
  ref.invalidate(paymentMethodsProvider);

  // Orders
  ref.invalidate(ordersProvider);
  ref.invalidate(activeOrdersProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(cartBillProvider);

  // Wallet, referrals and shared orders
  ref.invalidate(walletProvider);
  ref.invalidate(referralSummaryProvider);
  ref.invalidate(sharedGroupsProvider);
  ref.invalidate(sharedGroupProvider);
  ref.invalidate(referralDashboardProvider);
  ref.invalidate(referralDiscountsProvider);
}
