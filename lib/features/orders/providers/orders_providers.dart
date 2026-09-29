import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/di_providers.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../app_state/providers/location_providers.dart';
import '../../cart/providers/cart_controller.dart';
import '../../app_state/providers/app_controller.dart';
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

final validateGroceryCartUseCaseProvider = Provider<ValidateGroceryCartUseCase>(
  (ref) {
    return ValidateGroceryCartUseCase(ref.watch(ordersRepositoryProvider));
  },
);

final placeOrderUseCaseProvider = Provider<PlaceOrderUseCase>((ref) {
  return PlaceOrderUseCase(ref.watch(ordersRepositoryProvider));
});

final placeGroceryOrderUseCaseProvider = Provider<PlaceGroceryOrderUseCase>((
  ref,
) {
  return PlaceGroceryOrderUseCase(ref.watch(ordersRepositoryProvider));
});

final trackOrderUseCaseProvider = Provider<TrackOrderUseCase>((ref) {
  return TrackOrderUseCase(ref.watch(ordersRepositoryProvider));
});

final fetchOrdersUseCaseProvider = Provider<FetchOrdersUseCase>((ref) {
  return FetchOrdersUseCase(ref.watch(ordersRepositoryProvider));
});

final fetchGroceryOrdersUseCaseProvider = Provider<FetchGroceryOrdersUseCase>((
  ref,
) {
  return FetchGroceryOrdersUseCase(ref.watch(ordersRepositoryProvider));
});

final fetchActiveOrdersUseCaseProvider = Provider<FetchActiveOrdersUseCase>((
  ref,
) {
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
// The providers below are autoDispose because they hold data belonging to one
// signed-in customer. Without it their value survives in the container after
// logout, and the next person on a shared device sees the previous customer's
// orders, name, phone, addresses or payment methods. This matches
// favorites_provider.dart, which already scopes per-customer data this way.
final ordersProvider = FutureProvider.autoDispose<List<DeliveryOrder>>((
  ref,
) async {
  final result = await ref.watch(fetchOrdersUseCaseProvider)();
  return result.when(
    success: (data) => data,
    failure: (failure) => throw failure,
  );
});

final activeOrdersProvider = FutureProvider.autoDispose<List<DeliveryOrder>>((
  ref,
) async {
  final result = await ref.watch(fetchActiveOrdersUseCaseProvider)();
  return result.when(
    success: (data) => data,
    failure: (failure) => throw failure,
  );
});

class OrderTrackingRequest {
  const OrderTrackingRequest({
    required this.orderId,
    this.mode = DeliveryMode.food,
  });

  final String orderId;
  final DeliveryMode mode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderTrackingRequest &&
          other.orderId == orderId &&
          other.mode == mode;

  @override
  int get hashCode => Object.hash(orderId, mode);
}

final orderTrackingProvider =
    FutureProvider.family<OrderTracking, OrderTrackingRequest>((
      ref,
      request,
    ) async {
      final useCase = ref.watch(trackOrderUseCaseProvider);
      final result = await useCase(request.orderId, mode: request.mode);
      return result.when(
        success: (data) => data,
        failure: (failure) => throw failure,
      );
    });

final notificationsProvider = FutureProvider<List<AppNotificationItem>>((ref) {
  return ref.watch(accountRepositoryProvider).fetchNotifications();
});

final profileProvider = FutureProvider.autoDispose<CustomerProfile>((ref) {
  return ref.watch(accountRepositoryProvider).fetchProfile();
});

final addressesProvider = FutureProvider.autoDispose<List<CustomerAddress>>((
  ref,
) {
  return ref.watch(accountRepositoryProvider).fetchAddresses();
});

final paymentMethodsProvider = FutureProvider.autoDispose<List<PaymentMethod>>((
  ref,
) {
  return ref.watch(accountRepositoryProvider).fetchPaymentMethods();
});

/// Authoritative bill for the current cart.
///
/// Totals, taxes, fees and round-off are whatever `/customer-web/cart/validate`
/// returns — the app never computes money itself. Recomputes whenever the cart
/// changes so the checkout button always shows the amount the backend will
/// actually charge.
class CartCoupon extends Notifier<String> {
  @override
  String build() {
    ref.watch(cartControllerProvider.select((s) => s.cartRestaurantId));
    ref.watch(appControllerProvider.select((s) => s.authenticated));
    return '';
  }

  void setCode(String code) => state = code.trim();
}

final cartCouponProvider = NotifierProvider<CartCoupon, String>(CartCoupon.new);

final cartBillProvider = FutureProvider<BillSummary>((ref) async {
  final cart = ref.watch(cartControllerProvider);
  final lines = ref.watch(cartLinesProvider);
  final coupon = ref.watch(cartCouponProvider);
  final authenticated = ref.watch(
    appControllerProvider.select((s) => s.authenticated),
  );
  final foodValidator = ref.watch(validateCartUseCaseProvider);
  final groceryValidator = ref.watch(validateGroceryCartUseCaseProvider);
  // Register dependencies before any async gap.
  final addressesFuture = authenticated
      ? ref.watch(addressesProvider.future)
      : null;
  final locationFuture = ref.watch(currentLocationProvider.future);
  if (lines.isEmpty) throw StateError('Your cart is empty.');
  final addresses = addressesFuture == null
      ? const <CustomerAddress>[]
      : await addressesFuture;
  final address =
      addresses.where((a) => a.isDefault).firstOrNull ?? addresses.firstOrNull;
  final location = address?.hasPin == true ? null : await locationFuture;
  final latitude = address?.hasPin == true
      ? address!.latitude
      : location?.latitude;
  final longitude = address?.hasPin == true
      ? address!.longitude
      : location?.longitude;
  if (latitude == null || longitude == null) {
    throw StateError('Add a delivery location to see prices.');
  }
  final grocery = lines.first.item.type == CatalogItemType.grocery;
  final result = grocery
      ? await groceryValidator(
          groceryMerchantId: cart.cartGroceryMerchantId.isNotEmpty
              ? cart.cartGroceryMerchantId
              : lines.first.item.storeId,
          lines: lines,
          deliveryLatitude: latitude,
          deliveryLongitude: longitude,
        )
      : await foodValidator(
          restaurantId: cart.cartRestaurantId,
          lines: lines,
          couponCode: coupon.isEmpty ? null : coupon,
          deliveryLatitude: latitude,
          deliveryLongitude: longitude,
        );
  return result.when(
    success: (bill) => bill,
    failure: (failure) => throw failure,
  );
}, retry: (_, _) => null);
