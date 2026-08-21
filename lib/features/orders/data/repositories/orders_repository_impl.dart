import 'dart:math';

import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/api_exception.dart';
import '../../../../shared/models/app_models.dart';
import '../../../../shared/repositories/json_readers.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/orders_repository_interface.dart';

/// Cart, checkout and order reads/writes against restaurant-service.
///
/// Mirrors the production web client (`src/services/customerWebApi.ts`,
/// `customerOrdersApi.ts`). Pricing is **never** recomputed on the client —
/// `/cart/validate` and the order responses return the authoritative billing
/// summary and it is rendered verbatim.
class OrdersRepositoryImpl implements OrdersRepositoryInterface {
  const OrdersRepositoryImpl(this._client);

  final ApiClient _client;

  // ------------------------------------------------------------------
  // cart + checkout
  // ------------------------------------------------------------------

  /// POST /customer-web/cart/validate — authoritative totals, taxes and fees.
  Future<Result<BillSummary>> validateCart({
    required String restaurantId,
    required List<CartLine> lines,
    String? couponCode,
  }) async {
    try {
      final data = await _post('/customer-web/cart/validate', <String, dynamic>{
        'restaurant_id': _asIntOrString(restaurantId),
        'items': lines.map(_linePayload).toList(growable: false),
        'coupon_code': ?couponCode,
      });
      return Result.success(_billSummaryFromJson(data));
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }

  /// POST /customer-web/grocery/cart/validate — stock-aware grocery totals.
  Future<Result<BillSummary>> validateGroceryCart({
    required String groceryMerchantId,
    required List<CartLine> lines,
    required double deliveryLatitude,
    required double deliveryLongitude,
  }) async {
    try {
      final data = await _post(
        '/customer-web/grocery/cart/validate',
        <String, dynamic>{
          'grocery_merchant_id': _asIntOrString(groceryMerchantId),
          'items': lines.map(_groceryLinePayload).toList(growable: false),
          'delivery_location': <String, dynamic>{
            'latitude': deliveryLatitude,
            'longitude': deliveryLongitude,
          },
        },
      );
      return Result.success(_billSummaryFromJson(data));
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }

  /// POST /customer-web/coupons/validate.
  Future<Result<CouponResult>> validateCoupon({
    required String code,
    required String restaurantId,
    required int subtotal,
  }) async {
    try {
      final data = await _post(
        '/customer-web/coupons/validate',
        <String, dynamic>{
          'code': code,
          'restaurant_id': _asIntOrString(restaurantId),
          'order_amount': subtotal,
        },
      );
      return Result.success(CouponResult(
        valid: data['valid'] != false,
        code: readString(data, const ['code']),
        discountAmount: readDouble(data, const [
          'discount_amount',
          'discount',
        ]).round(),
        message: readString(data, const ['message']),
      ));
    } on ApiException catch (error) {
      return Result.success(CouponResult(
        valid: false,
        code: code,
        discountAmount: 0,
        message: error.message,
      ));
    }
  }

  /// POST /customer-web/orders — requires JWT and an `Idempotency-Key`.
  ///
  /// The key is generated per checkout attempt and **reused** across retries so
  /// a lost response can never create a second order, matching the guarantee
  /// the backend enforces via `orders_restaurant_client_order_id_uq`.
  Future<Result<PlacedOrder>> placeOrder({
    required String restaurantId,
    required List<CartLine> lines,
    required String idempotencyKey,
    String? addressId,
    String? paymentMethod,
    String? couponCode,
    String? instructions,
  }) async {
    try {
      final response = await _client.restaurant.post<dynamic>(
        '/customer-web/orders',
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: <String, dynamic>{
          'restaurant_id': _asIntOrString(restaurantId),
          'items': lines
              .map(
                (line) => <String, dynamic>{
                  'item_id': _asIntOrString(line.item.id),
                  'quantity': line.quantity,
                },
              )
              .toList(growable: false),
          'address_id': ?_asIntOrStringOrNull(addressId),
          'payment_method': ?paymentMethod,
          'coupon_code': ?couponCode,
          'special_instructions': ?instructions,
        },
      );
      final data = unwrapApiObject(response.data);
      return Result.success(PlacedOrder(
        orderId: readString(data, const ['id', 'order_id']),
        orderNumber: readString(data, const ['order_number', 'display_number']),
        status: readString(data, const ['order_status', 'status']),
        bill: _billSummaryFromJson(data),
      ));
    } on DioException catch (error) {
      return Result.failure(
        Failure.fromApiException(ApiException.fromDioException(error)),
      );
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }

  /// POST /customer-web/grocery/orders — COD grocery checkout.
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
  }) async {
    try {
      final response = await _client.restaurant.post<dynamic>(
        '/customer-web/grocery/orders',
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: <String, dynamic>{
          'grocery_merchant_id': _asIntOrString(groceryMerchantId),
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'payment_method': paymentMethod ?? 'cod',
          'delivery_address': deliveryAddress,
          'delivery_landmark': ?deliveryLandmark,
          'delivery_latitude': deliveryLatitude,
          'delivery_longitude': deliveryLongitude,
          'items': lines.map(_groceryLinePayload).toList(growable: false),
          'notes': ?instructions,
        },
      );
      final data = unwrapApiObject(response.data);
      return Result.success(PlacedOrder(
        orderId: readString(data, const ['grocery_order_id', 'id', 'order_id']),
        orderNumber: readString(data, const [
          'order_number',
          'display_number',
          'grocery_order_id',
        ]),
        status: readString(data, const ['order_status', 'status']),
        bill: _billSummaryFromJson(data),
      ));
    } on DioException catch (error) {
      return Result.failure(
        Failure.fromApiException(ApiException.fromDioException(error)),
      );
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }

  /// Stable key for one checkout attempt.
  static String newIdempotencyKey() {
    final random = Random();
    final suffix = List<String>.generate(
      4,
      (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
    ).join();
    return 'nua-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$suffix';
  }

  // ------------------------------------------------------------------
  // order reads
  // ------------------------------------------------------------------

  /// GET /customer-web/orders — order history.
  Future<Result<List<DeliveryOrder>>> fetchOrders({int page = 1, int limit = 20}) async {
    try {
      final raw = await _get(
        '/customer-web/orders',
        query: <String, dynamic>{'page': page, 'limit': limit},
      );
      return Result.success(listFrom(raw, keys: const ['orders', 'items', 'results'])
          .map(_order)
          .toList(growable: false));
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }

  /// GET /customer-web/orders/active — orders still in progress.
  Future<Result<List<DeliveryOrder>>> fetchActiveOrders() async {
    try {
      final raw = await _get('/customer-web/orders/active');
      return Result.success(listFrom(raw, keys: const ['orders', 'items', 'results'])
          .map(_order)
          .toList(growable: false));
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }

  /// GET /customer-web/orders/:id
  Future<Result<DeliveryOrder>> fetchOrder(String orderId) async {
    try {
      final raw = await _get('/customer-web/orders/$orderId');
      return Result.success(_order(raw is Map ? Map<String, dynamic>.from(raw) : {}));
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }

  /// GET /customer-web/orders/:id/track — live tracking projection.
  Future<Result<OrderTracking>> trackOrder(String orderId) async {
    try {
      final raw = await _get('/customer-web/orders/$orderId/track');
      final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final order = data['order'];
      final source = order is Map ? Map<String, dynamic>.from(order) : data;
      return Result.success(OrderTracking(
        orderId: readString(source, const ['id', 'order_id']),
        status: readString(source, const ['order_status', 'status']),
        statusLabel: readString(source, const ['status_label', 'label']),
        etaMinutes: readInt(source, const [
          'eta_minutes',
          'estimated_minutes',
          'estimated_delivery_minutes',
        ]),
        riderName: readString(source, const ['rider_name', 'delivery_partner']),
        riderPhone: readString(source, const ['rider_phone']),
      ));
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }

  /// GET /customer-web/grocery/orders/:id/track.
  Future<Result<OrderTracking>> trackGroceryOrder(String orderId) async {
    try {
      final raw = await _get('/customer-web/grocery/orders/$orderId/track');
      final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      return Result.success(OrderTracking(
        orderId: readString(data, const ['grocery_order_id', 'id', 'order_id']),
        status: readString(data, const ['order_status', 'status']),
        statusLabel: readString(data, const [
          'status_message',
          'status_label',
          'label',
        ]),
        etaMinutes: readInt(data, const [
          'eta_minutes',
          'estimated_minutes',
          'estimated_delivery_minutes',
        ]),
        riderName: readString(data, const ['rider_name', 'delivery_partner']),
        riderPhone: readString(data, const ['rider_phone']),
      ));
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }

  // ------------------------------------------------------------------
  // transport
  // ------------------------------------------------------------------

  Future<Object?> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _client.restaurant.get<dynamic>(
        path,
        queryParameters: (query == null || query.isEmpty) ? null : query,
      );
      return unwrapApiResponse(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    try {
      final response = await _client.restaurant.post<dynamic>(path, data: body);
      return unwrapApiObject(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  DeliveryOrder _order(Map<String, dynamic> json) {
    final status = readString(json, const [
      'order_status',
      'status',
    ]).toLowerCase();
    return DeliveryOrder(
      id: readString(json, const ['id', 'order_id']),
      store: readString(json, const [
        'restaurant_name',
        'store',
        'outlet_name',
      ]),
      date: readString(json, const ['created_at', 'placed_at', 'order_date']),
      itemCount: _itemCount(json),
      total: readDouble(json, const [
        'total_amount',
        'grand_total',
        'rounded_total_amount',
      ]).round(),
      status: _status(status),
      savings: readDouble(json, const ['discount_amount', 'savings']).round(),
    );
  }

  int _itemCount(Map<String, dynamic> json) {
    final explicit = readInt(json, const ['item_count', 'items_count']);
    if (explicit > 0) return explicit;
    final items = json['items'];
    return items is List ? items.length : 0;
  }

  /// Collapses the backend's nine order statuses onto the three the UI models.
  /// Status strings come from `restaurant-service/services/order_status_contract.go`.
  OrderStatus _status(String status) {
    switch (status) {
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'declined':
        return OrderStatus.cancelled;
      case 'completed':
      case 'delivered':
      case 'done':
      case 'served':
        return OrderStatus.completed;
      default:
        return OrderStatus.active;
    }
  }
}

BillSummary _billSummaryFromJson(Map<String, dynamic> json) {
  // Some endpoints nest the money under `billing`/`summary`.
  final nested = json['billing'] ?? json['summary'] ?? json['bill'];
  final source = nested is Map
      ? <String, dynamic>{...json, ...Map<String, dynamic>.from(nested)}
      : json;
  return BillSummary(
    subtotal: readDouble(source, const ['subtotal', 'item_total']).round(),
    discount: readDouble(source, const [
      'discount_amount',
      'discount',
    ]).round(),
    deliveryFee: readDouble(source, const [
      'delivery_fee',
      'delivery_charge',
    ]).round(),
    packagingCharge: readDouble(source, const [
      'extra_charges',
      'packaging_charge',
    ]).round(),
    cgst: readDouble(source, const ['cgst', 'cgst_amount']),
    sgst: readDouble(source, const ['sgst', 'sgst_amount']),
    taxAmount: readDouble(source, const ['tax_amount', 'taxes']),
    platformFee: readDouble(source, const [
      'platform_fee_amount',
      'platform_fee',
    ]).round(),
    roundOff: readDouble(source, const ['round_off_amount', 'round_off']),
    grandTotal: readDouble(source, const [
      'grand_total',
      'total_amount',
      'rounded_total_amount',
      'payable_amount',
    ]).round(),
    valid: source['valid'] != false,
    message: readString(source, const ['message']),
  );
}

/// Cart line as restaurant-service expects it.
///
/// Matches the production web client's `CartValidateRequestItem`
/// (`src/types/cart.ts`): item, quantity, optional variant, and addon
/// quantities. Omitting these would price the order at base cost and drop the
/// customer's choices before they reach the kitchen.
Map<String, dynamic> _linePayload(CartLine line) {
  return <String, dynamic>{
    'item_id': _asIntOrString(line.item.id),
    'quantity': line.quantity,
    'variant_id': ?_asIntOrStringOrNull(line.variant?.id),
    if (line.addons.isNotEmpty)
      'addons': line.addons
          .map(
            (addon) => <String, dynamic>{
              'addon_id': _asIntOrString(addon.id),
              'quantity': 1,
            },
          )
          .toList(growable: false),
  };
}

Map<String, dynamic> _groceryLinePayload(CartLine line) {
  return <String, dynamic>{
    'grocery_product_id': _asIntOrString(line.item.id),
    'quantity': line.quantity,
  };
}

/// restaurant-service uses numeric ids; send a number when the value is
/// numeric so binding does not reject a quoted id.
Object _asIntOrString(String value) => int.tryParse(value) ?? value;

Object? _asIntOrStringOrNull(String? value) {
  if (value == null || value.isEmpty) return null;
  return int.tryParse(value) ?? value;
}
