import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../../shared/repositories/orders_repository.dart';
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
