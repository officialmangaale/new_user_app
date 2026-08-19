import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/di_providers.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../cart/providers/cart_controller.dart';
import '../data/repositories/orders_repository_impl.dart';
import '../domain/repositories/orders_repository_interface.dart';
import '../domain/use_cases/orders_use_cases.dart';

final ordersRepositoryProvider = Provider<OrdersRepositoryInterface>((ref) {
  return OrdersRepositoryImpl(ref.watch(apiClientProvider));
});

// Use Cases
final validateCartUseCaseProvider = Provider<ValidateCartUseCase>((ref) {
  return ValidateCartUseCase(ref.watch(ordersRepositoryProvider));
});

final placeOrderUseCaseProvider = Provider<PlaceOrderUseCase>((ref) {
  return PlaceOrderUseCase(ref.watch(ordersRepositoryProvider));
});

final trackOrderUseCaseProvider = Provider<TrackOrderUseCase>((ref) {
  return TrackOrderUseCase(ref.watch(ordersRepositoryProvider));
});

final fetchOrdersUseCaseProvider = Provider<FetchOrdersUseCase>((ref) {
  return FetchOrdersUseCase(ref.watch(ordersRepositoryProvider));
});

final fetchActiveOrdersUseCaseProvider = Provider<FetchActiveOrdersUseCase>((ref) {
  return FetchActiveOrdersUseCase(ref.watch(ordersRepositoryProvider));
});

final fetchOrderUseCaseProvider = Provider<FetchOrderUseCase>((ref) {
  return FetchOrderUseCase(ref.watch(ordersRepositoryProvider));
});

final validateCouponUseCaseProvider = Provider<ValidateCouponUseCase>((ref) {
  return ValidateCouponUseCase(ref.watch(ordersRepositoryProvider));
});


// Account Repository (To be moved in Phase 5)
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(apiClientProvider));
});

// Data Providers (Unwrap Results)

/// Order history. Requires a signed-in customer.
final ordersProvider = FutureProvider<List<DeliveryOrder>>((ref) async {
  final result = await ref.watch(fetchOrdersUseCaseProvider)();
  return result.when(
    success: (data) => data,
    failure: (failure) => throw failure,
  );
});

final activeOrdersProvider = FutureProvider<List<DeliveryOrder>>((ref) async {
  final result = await ref.watch(fetchActiveOrdersUseCaseProvider)();
  return result.when(
    success: (data) => data,
    failure: (failure) => throw failure,
  );
});

final orderTrackingProvider = FutureProvider.family<OrderTracking, String>((
  ref,
  orderId,
) async {
  final result = await ref.watch(trackOrderUseCaseProvider)(orderId);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw failure,
  );
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
    cartControllerProvider.select((state) => state.cartRestaurantId),
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

  final result = await ref.watch(validateCartUseCaseProvider)(
    restaurantId: restaurantId,
    lines: lines,
  );

  return result.when(
    success: (data) => data,
    failure: (failure) => throw failure,
  );
});
