import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/di_providers.dart';
import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../app_state/providers/location_providers.dart';
import '../../orders/providers/orders_providers.dart';
import 'cart_controller.dart';

/// Deliberately **not** `autoDispose`.
///
/// Checkout is driven entirely through `ref.read(...notifier).placeOrder()` —
/// no widget ever watches this provider, so an auto-disposing notifier has zero
/// listeners and Riverpod tears it down at the first async gap. `placeOrder`
/// awaits a GPS fix (up to 12 s), so every `ref` use and every `state =` after
/// that gap threw `Cannot use the Ref … after it has been disposed`. The throw
/// escaped to the zone and the tap appeared to do nothing at all.
///
/// The notifier holds no resources and `build()` is empty, so keeping it alive
/// for the session costs nothing and removes the whole failure class.
final checkoutViewModelProvider =
    AsyncNotifierProvider<CheckoutViewModel, void>(CheckoutViewModel.new);

class CheckoutViewModel extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<Result<PlacedOrder>> placeOrder({
    required String idempotencyKey,
    required String paymentMethod,
    String? instructions,
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
        instructions: instructions,
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

    final profile = await _readProfile();
    final address = await _readDefaultAddress();
    final storedName = await ref.read(authStorageProvider).readUserName();
    final storedPhone = await ref.read(authStorageProvider).readUserPhone();
    // `??` only falls back on null, but the profile endpoint returns empty
    // strings for fields the customer has not filled in — so an unset name
    // must fall through to the stored session value, not block checkout.
    final customerName = _firstNonEmpty([profile?.name, storedName]);
    if (customerName.isEmpty) {
      final failure = const ValidationFailure(
        'Please update your name before placing an order.',
      );
      state = AsyncValue.error(failure, StackTrace.current);
      return Result.failure(failure);
    }

    final customerPhone = _firstNonEmpty([profile?.phone, storedPhone]);
    if (customerPhone.length < 10) {
      final failure = const ValidationFailure(
        'Please update your phone number before placing an order.',
      );
      state = AsyncValue.error(failure, StackTrace.current);
      return Result.failure(failure);
    }

    final delivery = await _resolveDelivery(address);
    if (delivery.failure != null) {
      state = AsyncValue.error(delivery.failure!, StackTrace.current);
      return Result.failure(delivery.failure!);
    }
    final deliveryAddress = delivery.address!;

    final result = await ref.read(placeOrderUseCaseProvider)(
      restaurantId: cartState.cartRestaurantId,
      lines: lines,
      idempotencyKey: idempotencyKey,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddressLine1: deliveryAddress.addressLine1,
      deliveryLatitude: delivery.latitude!,
      deliveryLongitude: delivery.longitude!,
      deliveryArea: _nonEmpty(deliveryAddress.area),
      deliveryCity: _nonEmpty(deliveryAddress.city),
      deliveryPincode: _nonEmpty(deliveryAddress.pincode),
      deliveryLandmark: _nonEmpty(deliveryAddress.landmark),
      paymentMethod: paymentMethod,
      instructions: instructions,
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
    String? instructions,
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

    final profile = await _readProfile();
    final address = await _readDefaultAddress();
    final delivery = await _resolveDelivery(address);
    if (delivery.failure != null) {
      state = AsyncValue.error(delivery.failure!, StackTrace.current);
      return Result.failure(delivery.failure!);
    }
    final deliveryAddress = delivery.address!;

    final storedPhone = await ref.read(authStorageProvider).readUserPhone();
    final customerPhone = _firstNonEmpty([profile?.phone, storedPhone]);
    if (customerPhone.length < 10) {
      final failure = const ValidationFailure(
        'Please update your phone number before placing a grocery order.',
      );
      state = AsyncValue.error(failure, StackTrace.current);
      return Result.failure(failure);
    }

    final result = await ref.read(placeGroceryOrderUseCaseProvider)(
      groceryMerchantId: merchantId,
      lines: lines,
      idempotencyKey: idempotencyKey,
      customerName: _firstNonEmpty([profile?.name]),
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress.singleLine,
      deliveryLatitude: delivery.latitude!,
      deliveryLongitude: delivery.longitude!,
      deliveryLandmark: _nonEmpty(deliveryAddress.landmark),
      paymentMethod: paymentMethod,
      instructions: instructions,
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

  /// Where the order goes, or why it cannot be placed.
  ///
  /// A saved address is required: a "Current location" order carries no
  /// house or flat number, so the rider cannot find the door.
  ///
  /// The address's own pin is used when it has one. The device location used
  /// to take priority, so an order to "Home" placed from the office was
  /// pinned at the office. The device location is now only a fallback for an
  /// address saved without a pin, and GPS is not awaited when it is not
  /// needed.
  Future<_DeliveryTarget> _resolveDelivery(CustomerAddress? address) async {
    if (address == null || address.addressLine1.trim().isEmpty) {
      return const _DeliveryTarget.failed(
        ValidationFailure('Add a delivery address to place your order.'),
      );
    }
    if (address.hasPin) {
      return _DeliveryTarget(address, address.latitude!, address.longitude!);
    }
    final location = await ref.read(currentLocationProvider.future);
    if (location == null) {
      return const _DeliveryTarget.failed(
        ValidationFailure(
          'Pin this address so your rider can find you: edit it and tap '
          '"Use current location", or turn on location.',
        ),
      );
    }
    return _DeliveryTarget(address, location.latitude, location.longitude);
  }

  static String? _nonEmpty(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// First value that is neither null nor blank, trimmed. Empty when there is
  /// none — the caller decides whether that is fatal.
  static String _firstNonEmpty(List<String?> candidates) {
    for (final candidate in candidates) {
      final text = candidate?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
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

class _DeliveryTarget {
  const _DeliveryTarget(
    CustomerAddress this.address,
    double this.latitude,
    double this.longitude,
  ) : failure = null;

  const _DeliveryTarget.failed(ValidationFailure this.failure)
    : address = null,
      latitude = null,
      longitude = null;

  final CustomerAddress? address;
  final double? latitude;
  final double? longitude;
  final ValidationFailure? failure;
}
