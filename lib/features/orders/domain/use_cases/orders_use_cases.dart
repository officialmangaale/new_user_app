import '../../../../core/error/result.dart';
import '../../../../shared/models/app_models.dart';
import '../repositories/orders_repository_interface.dart';

class ValidateCartUseCase {
  const ValidateCartUseCase(this._repository);
  final OrdersRepositoryInterface _repository;

  Future<Result<BillSummary>> call({
    required String restaurantId,
    required List<CartLine> lines,
    String? couponCode,
  }) {
    return _repository.validateCart(
      restaurantId: restaurantId,
      lines: lines,
      couponCode: couponCode,
    );
  }
}

class ValidateGroceryCartUseCase {
  const ValidateGroceryCartUseCase(this._repository);
  final OrdersRepositoryInterface _repository;

  Future<Result<BillSummary>> call({
    required String groceryMerchantId,
    required List<CartLine> lines,
    required double deliveryLatitude,
    required double deliveryLongitude,
  }) {
    return _repository.validateGroceryCart(
      groceryMerchantId: groceryMerchantId,
      lines: lines,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
    );
  }
}

class PlaceOrderUseCase {
  const PlaceOrderUseCase(this._repository);
  final OrdersRepositoryInterface _repository;

  Future<Result<PlacedOrder>> call({
    required String restaurantId,
    required List<CartLine> lines,
    required String idempotencyKey,
    required String customerName,
    required String customerPhone,
    required String deliveryAddressLine1,
    required double deliveryLatitude,
    required double deliveryLongitude,
    String? deliveryArea,
    String? deliveryCity,
    String? deliveryPincode,
    String? deliveryLandmark,
    String? paymentMethod,
    String? couponCode,
    String? instructions,
  }) {
    return _repository.placeOrder(
      restaurantId: restaurantId,
      lines: lines,
      idempotencyKey: idempotencyKey,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddressLine1: deliveryAddressLine1,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      deliveryArea: deliveryArea,
      deliveryCity: deliveryCity,
      deliveryPincode: deliveryPincode,
      deliveryLandmark: deliveryLandmark,
      paymentMethod: paymentMethod,
      couponCode: couponCode,
      instructions: instructions,
    );
  }
}

class PlaceGroceryOrderUseCase {
  const PlaceGroceryOrderUseCase(this._repository);
  final OrdersRepositoryInterface _repository;

  Future<Result<PlacedOrder>> call({
    required String groceryMerchantId,
    required List<CartLine> lines,
    required String idempotencyKey,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required double deliveryLatitude,
    required double deliveryLongitude,
    String? deliveryLandmark,
    String? paymentMethod,
    String? instructions,
  }) {
    return _repository.placeGroceryOrder(
      groceryMerchantId: groceryMerchantId,
      lines: lines,
      idempotencyKey: idempotencyKey,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      deliveryLandmark: deliveryLandmark,
      paymentMethod: paymentMethod,
      instructions: instructions,
    );
  }
}

class TrackOrderUseCase {
  const TrackOrderUseCase(this._repository);
  final OrdersRepositoryInterface _repository;

  Future<Result<OrderTracking>> call(
    String orderId, {
    DeliveryMode mode = DeliveryMode.food,
  }) {
    return mode == DeliveryMode.grocery
        ? _repository.trackGroceryOrder(orderId)
        : _repository.trackOrder(orderId);
  }
}

class FetchOrdersUseCase {
  const FetchOrdersUseCase(this._repository);
  final OrdersRepositoryInterface _repository;

  Future<Result<List<DeliveryOrder>>> call({int page = 1, int limit = 20}) {
    return _repository.fetchOrders(page: page, limit: limit);
  }
}

class FetchActiveOrdersUseCase {
  const FetchActiveOrdersUseCase(this._repository);
  final OrdersRepositoryInterface _repository;

  Future<Result<List<DeliveryOrder>>> call() {
    return _repository.fetchActiveOrders();
  }
}

class FetchOrderUseCase {
  const FetchOrderUseCase(this._repository);
  final OrdersRepositoryInterface _repository;

  Future<Result<DeliveryOrder>> call(String orderId) {
    return _repository.fetchOrder(orderId);
  }
}

class ValidateCouponUseCase {
  const ValidateCouponUseCase(this._repository);
  final OrdersRepositoryInterface _repository;

  Future<Result<CouponResult>> call({
    required String code,
    required String restaurantId,
    required int subtotal,
  }) {
    return _repository.validateCoupon(
      code: code,
      restaurantId: restaurantId,
      subtotal: subtotal,
    );
  }
}
