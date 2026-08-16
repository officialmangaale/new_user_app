import 'dart:math';

import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../../core/services/api_exception.dart';
import '../models/app_models.dart';
import 'json_readers.dart';

/// Cart, checkout and order reads/writes against restaurant-service.
///
/// Mirrors the production web client (`src/services/customerWebApi.ts`,
/// `customerOrdersApi.ts`). Pricing is **never** recomputed on the client —
/// `/cart/validate` and the order responses return the authoritative billing
/// summary and it is rendered verbatim.
class OrdersRepository {
  const OrdersRepository(this._client);

  final ApiClient _client;

  // ------------------------------------------------------------------
  // cart + checkout
  // ------------------------------------------------------------------

  /// POST /customer-web/cart/validate — authoritative totals, taxes and fees.
  Future<BillSummary> validateCart({
    required String restaurantId,
    required List<CartLine> lines,
    String? couponCode,
  }) async {
    final data = await _post('/customer-web/cart/validate', <String, dynamic>{
      'restaurant_id': _asIntOrString(restaurantId),
      'items': lines
          .map(
            (line) => <String, dynamic>{
              'item_id': _asIntOrString(line.item.id),
              'quantity': line.quantity,
            },
          )
          .toList(growable: false),
      'coupon_code': ?couponCode,
    });
    return BillSummary.fromJson(data);
  }

  /// POST /customer-web/coupons/validate.
  Future<CouponResult> validateCoupon({
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
      return CouponResult(
        valid: data['valid'] != false,
        code: readString(data, const ['code']),
        discountAmount: readDouble(data, const [
          'discount_amount',
          'discount',
        ]).round(),
        message: readString(data, const ['message']),
      );
    } on ApiException catch (error) {
      return CouponResult(
        valid: false,
        code: code,
        discountAmount: 0,
        message: error.message,
      );
    }
  }

  /// POST /customer-web/orders — requires JWT and an `Idempotency-Key`.
  ///
  /// The key is generated per checkout attempt and **reused** across retries so
  /// a lost response can never create a second order, matching the guarantee
  /// the backend enforces via `orders_restaurant_client_order_id_uq`.
  Future<PlacedOrder> placeOrder({
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
      return PlacedOrder(
        orderId: readString(data, const ['id', 'order_id']),
        orderNumber: readString(data, const ['order_number', 'display_number']),
        status: readString(data, const ['order_status', 'status']),
        bill: BillSummary.fromJson(data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
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
  Future<List<DeliveryOrder>> fetchOrders({int page = 1, int limit = 20}) async {
    final raw = await _get(
      '/customer-web/orders',
      query: <String, dynamic>{'page': page, 'limit': limit},
    );
    return listFrom(raw, keys: const ['orders', 'items', 'results'])
        .map(_order)
        .toList(growable: false);
  }

  /// GET /customer-web/orders/active — orders still in progress.
  Future<List<DeliveryOrder>> fetchActiveOrders() async {
    final raw = await _get('/customer-web/orders/active');
    return listFrom(raw, keys: const ['orders', 'items', 'results'])
        .map(_order)
        .toList(growable: false);
  }

  /// GET /customer-web/orders/:id
  Future<DeliveryOrder> fetchOrder(String orderId) async {
    final raw = await _get('/customer-web/orders/$orderId');
    return _order(raw is Map ? Map<String, dynamic>.from(raw) : {});
  }

  /// GET /customer-web/orders/:id/track — live tracking projection.
  Future<OrderTracking> trackOrder(String orderId) async {
    final raw = await _get('/customer-web/orders/$orderId/track');
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final order = data['order'];
    final source = order is Map ? Map<String, dynamic>.from(order) : data;
    return OrderTracking(
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
    );
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

/// Authoritative bill returned by the backend. Never computed on device.
class BillSummary {
  const BillSummary({
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.packagingCharge,
    required this.cgst,
    required this.sgst,
    required this.taxAmount,
    required this.platformFee,
    required this.roundOff,
    required this.grandTotal,
    required this.valid,
    required this.message,
  });

  final int subtotal;
  final int discount;
  final int deliveryFee;
  final int packagingCharge;
  final double cgst;
  final double sgst;
  final double taxAmount;
  final int platformFee;
  final double roundOff;
  final int grandTotal;
  final bool valid;
  final String message;

  factory BillSummary.fromJson(Map<String, dynamic> json) {
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
}

class CouponResult {
  const CouponResult({
    required this.valid,
    required this.code,
    required this.discountAmount,
    required this.message,
  });

  final bool valid;
  final String code;
  final int discountAmount;
  final String message;
}

class PlacedOrder {
  const PlacedOrder({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.bill,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final BillSummary bill;
}

class OrderTracking {
  const OrderTracking({
    required this.orderId,
    required this.status,
    required this.statusLabel,
    required this.etaMinutes,
    required this.riderName,
    required this.riderPhone,
  });

  final String orderId;
  final String status;
  final String statusLabel;
  final int etaMinutes;
  final String riderName;
  final String riderPhone;
}

/// restaurant-service uses numeric ids; send a number when the value is
/// numeric so binding does not reject a quoted id.
Object _asIntOrString(String value) => int.tryParse(value) ?? value;

Object? _asIntOrStringOrNull(String? value) {
  if (value == null || value.isEmpty) return null;
  return int.tryParse(value) ?? value;
}
