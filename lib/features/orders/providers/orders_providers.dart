import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/di_providers.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../app_state/providers/location_providers.dart';
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

final validateGroceryCartUseCaseProvider =
    Provider<ValidateGroceryCartUseCase>((ref) {
  return ValidateGroceryCartUseCase(ref.watch(ordersRepositoryProvider));
});

final placeOrderUseCaseProvider = Provider<PlaceOrderUseCase>((ref) {
  return PlaceOrderUseCase(ref.watch(ordersRepositoryProvider));
});

final placeGroceryOrderUseCaseProvider =
    Provider<PlaceGroceryOrderUseCase>((ref) {
  return PlaceGroceryOrderUseCase(ref.watch(ordersRepositoryProvider));
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
  final groceryMerchantId = ref.watch(
    cartControllerProvider.select((state) => state.cartGroceryMerchantId),
  );
  final lines = ref.watch(cartLinesProvider);

  if (lines.isEmpty) {
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

  final grocery = lines.first.item.type == CatalogItemType.grocery;
  if (grocery) {
    final effectiveGroceryMerchantId = groceryMerchantId.isNotEmpty
        ? groceryMerchantId
        : lines.first.item.storeId;
    if (effectiveGroceryMerchantId.isEmpty) {
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
        message: 'Please reopen the grocery store and add items again.',
      );
    }
    final location = await ref.watch(currentLocationProvider.future);
    if (location == null) {
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
        message: 'Turn on location to price grocery delivery near you.',
      );
    }
    final result = await ref.watch(validateGroceryCartUseCaseProvider)(
      groceryMerchantId: effectiveGroceryMerchantId,
      lines: lines,
      deliveryLatitude: location.latitude,
      deliveryLongitude: location.longitude,
    );
    return result.when(
      success: (data) => data,
      failure: (failure) => throw failure,
    );
  }

  if (restaurantId.isEmpty) {
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
      message: 'Please reopen the restaurant and add items again.',
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
