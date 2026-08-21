import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/di_providers.dart';
import '../../../core/error/failures.dart';
import '../../../shared/models/app_models.dart';
import '../../orders/providers/orders_providers.dart';
import '../../app_state/providers/location_providers.dart';
import 'cart_controller.dart';

final checkoutViewModelProvider =
    AutoDisposeAsyncNotifierProvider<CheckoutViewModel, void>(() {
  return CheckoutViewModel();
});

class CheckoutViewModel extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<Result<PlacedOrder>> placeOrder({
    required String idempotencyKey,
    required String paymentMethod,
  }) async {
    final cartState = ref.read(cartControllerProvider);
    final lines = ref.read(cartLinesProvider);

    if (lines.isEmpty) {
      final failure = const ValidationFailure('Your cart is empty.');
      state = AsyncValue.error(failure, StackTrace.current);
      return Result.failure(failure);
    }

    if (lines.first.item.type == CatalogItemType.grocery) {
      return _placeGroceryOrder(
        cartState: cartState,
        lines: lines,
        idempotencyKey: idempotencyKey,
        paymentMethod: paymentMethod,
      );
    }

    if (cartState.cartRestaurantId.isEmpty) {
      final failure = const ValidationFailure(
        'We could not tell which restaurant this cart belongs to. '
        'Please reopen the restaurant and add items again.',
      );
      state = AsyncValue.error(failure, StackTrace.current);
      return Result.failure(failure);
    }

    state = const AsyncValue.loading();

    final result = await ref.read(placeOrderUseCaseProvider)(
      restaurantId: cartState.cartRestaurantId,
      lines: lines,
      idempotencyKey: idempotencyKey,
      paymentMethod: paymentMethod,
    );

    return result.when(
      success: (placedOrder) {
        state = const AsyncValue.data(null);
        ref.read(cartControllerProvider.notifier).clearCart();
        ref.invalidate(ordersProvider);
        return Result.success(placedOrder);
      },
      failure: (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
        return Result.failure(failure);
      },
    );
  }

  Future<Result<PlacedOrder>> _placeGroceryOrder({
    required CartState cartState,
    required List<CartLine> lines,
    required String idempotencyKey,
    required String paymentMethod,
  }) async {
    final merchantId = cartState.cartGroceryMerchantId.isNotEmpty
        ? cartState.cartGroceryMerchantId
        : lines.first.item.storeId;
    if (merchantId.isEmpty) {
      final failure = const ValidationFailure(
        'We could not tell which grocery store this basket belongs to. '
        'Please reopen the grocery section and add items again.',
      );
      state = AsyncValue.error(failure, StackTrace.current);
      return Result.failure(failure);
    }

    state = const AsyncValue.loading();

    final location = await ref.read(currentLocationProvider.future);
    final profile = await _readProfile();
    final address = await _readDefaultAddress();
    final latitude = location?.latitude ?? address?.latitude;
    final longitude = location?.longitude ?? address?.longitude;
    if (latitude == null || longitude == null) {
      final failure = const ValidationFailure(
        'Turn on location or save an address with location to place a grocery order.',
      );
      state = AsyncValue.error(failure, StackTrace.current);
      return Result.failure(failure);
    }

    final storedPhone = await ref.read(authStorageProvider).readUserPhone();
    final customerPhone = (profile?.phone ?? storedPhone ?? '').trim();
    if (customerPhone.length < 10) {
      final failure = const ValidationFailure(
        'Please update your phone number before placing a grocery order.',
      );
      state = AsyncValue.error(failure, StackTrace.current);
      return Result.failure(failure);
    }

    final deliveryAddress = (address?.singleLine.trim().isNotEmpty ?? false)
        ? address!.singleLine
        : 'Current location';

    final result = await ref.read(placeGroceryOrderUseCaseProvider)(
      groceryMerchantId: merchantId,
      lines: lines,
      idempotencyKey: idempotencyKey,
      customerName: profile?.name ?? '',
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      deliveryLatitude: latitude,
      deliveryLongitude: longitude,
      deliveryLandmark: address?.area,
      paymentMethod: paymentMethod,
    );

    return result.when(
      success: (placedOrder) {
        state = const AsyncValue.data(null);
        ref.read(cartControllerProvider.notifier).clearCart();
        ref.invalidate(ordersProvider);
        return Result.success(placedOrder);
      },
      failure: (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
        return Result.failure(failure);
      },
    );
  }

  Future<CustomerProfile?> _readProfile() async {
    try {
      return await ref.read(accountRepositoryProvider).fetchProfile();
    } catch (_) {
      return null;
    }
  }

  Future<CustomerAddress?> _readDefaultAddress() async {
    try {
      final addresses = await ref
          .read(accountRepositoryProvider)
          .fetchAddresses();
      if (addresses.isEmpty) return null;
      for (final address in addresses) {
        if (address.isDefault) return address;
      }
      return addresses.first;
    } catch (_) {
      return null;
    }
  }
}
