import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../../core/services/api_exception.dart';
import '../models/app_models.dart';
import 'json_readers.dart';

/// Profile, addresses, payment methods and notifications.
///
/// Profile and addresses exist on **both** services. This uses the
/// restaurant-service `/customer-web/*` variants because they are verifiable in
/// this repository and share the same JWT; the web client happens to call the
/// user-service equivalents. Both are backed by the same customer records.
class AccountRepository {
  const AccountRepository(this._client);

  final ApiClient _client;

  /// GET /customer-web/profile
  Future<CustomerProfile> fetchProfile() async {
    final data = await _getObject('/customer-web/profile');
    return CustomerProfile.fromJson(data);
  }

  /// PATCH /customer-web/profile
  Future<CustomerProfile> updateProfile({
    String? name,
    String? email,
  }) async {
    try {
      final response = await _client.restaurant.patch<dynamic>(
        '/customer-web/profile',
        data: <String, dynamic>{'name': ?name, 'email': ?email},
      );
      return CustomerProfile.fromJson(unwrapApiObject(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// GET /customer-web/me/dashboard-summary
  Future<DashboardSummary> fetchDashboardSummary() async {
    final data = await _getObject('/customer-web/me/dashboard-summary');
    return DashboardSummary(
      totalOrders: readInt(data, const ['total_orders', 'orders_count']),
      totalSavings: readDouble(data, const [
        'total_savings',
        'savings',
      ]).round(),
    );
  }

  // ------------------------------------------------------------------
  // addresses
  // ------------------------------------------------------------------

  /// GET /customer-web/addresses
  Future<List<CustomerAddress>> fetchAddresses() async {
    final raw = await _get('/customer-web/addresses');
    return listFrom(raw, keys: const ['addresses', 'items'])
        .map(CustomerAddress.fromJson)
        .toList(growable: false);
  }

  /// POST /customer-web/addresses
  Future<CustomerAddress> addAddress(CustomerAddress address) async {
    try {
      final response = await _client.restaurant.post<dynamic>(
        '/customer-web/addresses',
        data: address.toJson(),
      );
      return CustomerAddress.fromJson(unwrapApiObject(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// PATCH /customer-web/addresses/:id
  Future<void> updateAddress(String id, CustomerAddress address) async {
    await _send('PATCH', '/customer-web/addresses/$id', address.toJson());
  }

  /// DELETE /customer-web/addresses/:id
  Future<void> deleteAddress(String id) async {
    await _send('DELETE', '/customer-web/addresses/$id', null);
  }

  /// PATCH /customer-web/addresses/:id/default
  Future<void> setDefaultAddress(String id) async {
    await _send('PATCH', '/customer-web/addresses/$id/default', null);
  }

  // ------------------------------------------------------------------
  // payment methods
  // ------------------------------------------------------------------

  /// GET /customer-web/payment-methods
  Future<List<PaymentMethod>> fetchPaymentMethods() async {
    final raw = await _get('/customer-web/payment-methods');
    return listFrom(raw, keys: const ['payment_methods', 'methods', 'items'])
        .map(
          (json) => PaymentMethod(
            id: readString(json, const ['id', 'code', 'method']),
            label: readString(json, const ['label', 'name', 'title']),
            enabled: readBool(json, const [
              'enabled',
              'is_enabled',
              'is_active',
            ], orElse: true),
          ),
        )
        .toList(growable: false);
  }

  // ------------------------------------------------------------------
  // notifications
  // ------------------------------------------------------------------

  /// GET /notifications
  Future<List<AppNotificationItem>> fetchNotifications() async {
    final raw = await _get('/notifications');
    return listFrom(raw, keys: const ['notifications', 'items', 'results'])
        .map(
          (json) => AppNotificationItem(
            title: readString(json, const ['title', 'heading']),
            body: readString(json, const ['body', 'message', 'description']),
            time: readString(json, const ['created_at', 'time', 'sent_at']),
            kind: readString(json, const ['type', 'kind', 'category']),
            unread: !readBool(json, const ['is_read', 'read'], orElse: false),
          ),
        )
        .toList(growable: false);
  }

  /// PATCH /notifications/:id/read
  Future<void> markNotificationRead(String id) async {
    await _send('PATCH', '/notifications/$id/read', null);
  }

  // ------------------------------------------------------------------
  // transport
  // ------------------------------------------------------------------

  Future<Object?> _get(String path) async {
    try {
      final response = await _client.restaurant.get<dynamic>(path);
      return unwrapApiResponse(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> _getObject(String path) async {
    final raw = await _get(path);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> _send(String method, String path, Object? body) async {
    try {
      await _client.restaurant.request<dynamic>(
        path,
        data: body,
        options: Options(method: method),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}

class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String id;
  final String name;
  final String phone;
  final String email;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final source = user is Map
        ? <String, dynamic>{...json, ...Map<String, dynamic>.from(user)}
        : json;
    return CustomerProfile(
      id: readString(source, const ['user_id', 'id', 'customer_id']),
      name: readString(source, const ['name', 'full_name']),
      phone: readString(source, const ['phone', 'mobile']),
      email: readString(source, const ['email']),
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalOrders,
    required this.totalSavings,
  });

  final int totalOrders;
  final int totalSavings;
}

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.label,
    required this.addressLine1,
    required this.area,
    required this.city,
    required this.pincode,
    required this.isDefault,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final String addressLine1;
  final String area;
  final String city;
  final String pincode;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  String get singleLine => [
    addressLine1,
    area,
    city,
    pincode,
  ].where((part) => part.isNotEmpty).join(', ');

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: readString(json, const ['id', 'address_id']),
      label: readString(json, const ['label', 'tag', 'type']),
      addressLine1: readString(json, const [
        'address_line1',
        'address',
        'line1',
      ]),
      area: readString(json, const ['area', 'locality']),
      city: readString(json, const ['city']),
      pincode: readString(json, const ['pincode', 'postal_code', 'zip']),
      isDefault: readBool(json, const ['is_default', 'default']),
      latitude: json['latitude'] is num
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'address_line1': addressLine1,
    'area': area,
    'city': city,
    'pincode': pincode,
    'is_default': isDefault,
    'latitude': ?latitude,
    'longitude': ?longitude,
  };
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.label,
    required this.enabled,
  });

  final String id;
  final String label;
  final bool enabled;
}
