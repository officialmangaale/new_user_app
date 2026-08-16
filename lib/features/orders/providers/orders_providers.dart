import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../../shared/repositories/orders_repository.dart';
import '../../app_state/providers/app_controller.dart';
import '../../authentication/providers/auth_providers.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider));
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(apiClientProvider));
});

/// Order history. Requires a signed-in customer.
final ordersProvider = FutureProvider<List<DeliveryOrder>>((ref) {
  return ref.watch(ordersRepositoryProvider).fetchOrders();
});

final activeOrdersProvider = FutureProvider<List<DeliveryOrder>>((ref) {
  return ref.watch(ordersRepositoryProvider).fetchActiveOrders();
});

final orderTrackingProvider = FutureProvider.family<OrderTracking, String>((
  ref,
  orderId,
) {
  return ref.watch(ordersRepositoryProvider).trackOrder(orderId);
});

final notificationsProvider = FutureProvider<List<AppNotificationItem>>((ref) {
  return ref.watch(accountRepositoryProvider).fetchNotifications();
});

final profileProvider = FutureProvider<CustomerProfile>((ref) {
  return ref.watch(accountRepositoryProvider).fetchProfile();
});

final addressesProvider = FutureProvider<List<CustomerAddress>>((ref) {
  return ref.watch(accountRepositoryProvider).fetchAddresses();
});

final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) {
  return ref.watch(accountRepositoryProvider).fetchPaymentMethods();
});

/// Authoritative bill for the current cart.
///
/// Totals, taxes, fees and round-off are whatever `/customer-web/cart/validate`
/// returns — the app never computes money itself. Recomputes whenever the cart
/// changes so the checkout button always shows the amount the backend will
/// actually charge.
final cartBillProvider = FutureProvider<BillSummary>((ref) async {
  final restaurantId = ref.watch(
    appControllerProvider.select((state) => state.cartRestaurantId),
  );
  final lines = ref.watch(cartLinesProvider);

  if (lines.isEmpty || restaurantId.isEmpty) {
    return const BillSummary(
      subtotal: 0,
      discount: 0,
      deliveryFee: 0,
      packagingCharge: 0,
      cgst: 0,
      sgst: 0,
      taxAmount: 0,
      platformFee: 0,
      roundOff: 0,
      grandTotal: 0,
      valid: false,
      message: 'Your cart is empty.',
    );
  }

  return ref
      .watch(ordersRepositoryProvider)
      .validateCart(restaurantId: restaurantId, lines: lines);
});
