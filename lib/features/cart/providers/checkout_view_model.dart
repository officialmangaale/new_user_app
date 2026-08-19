import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../shared/models/app_models.dart';
import '../../orders/providers/orders_providers.dart';
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
}
