import '../../../../core/error/result.dart';
import '../../../../shared/models/app_models.dart';

abstract class OrdersRepositoryInterface {
  Future<Result<BillSummary>> validateCart({
    required String restaurantId,
    required List<CartLine> lines,
    String? couponCode,
  });

  Future<Result<BillSummary>> validateGroceryCart({
    required String groceryMerchantId,
    required List<CartLine> lines,
    required double deliveryLatitude,
    required double deliveryLongitude,
  });

  Future<Result<CouponResult>> validateCoupon({
    required String code,
    required String restaurantId,
    required int subtotal,
  });

  Future<Result<PlacedOrder>> placeOrder({
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
  });

  Future<Result<PlacedOrder>> placeGroceryOrder({
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
  });

  Future<Result<List<DeliveryOrder>>> fetchOrders({int page = 1, int limit = 20});

  Future<Result<List<DeliveryOrder>>> fetchActiveOrders();

  Future<Result<DeliveryOrder>> fetchOrder(String orderId);

  Future<Result<OrderTracking>> trackOrder(String orderId);

  Future<Result<OrderTracking>> trackGroceryOrder(String orderId);
}
