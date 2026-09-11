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
  // addresses — user-service
  // ------------------------------------------------------------------
  //
  // These used to call restaurant-service `/customer-web/addresses`, which
  // are stubs: GET always returns an empty list and every write answers 501
  // "saved address storage is not configured". Saving an address could
  // never succeed. user-service owns the real address book
  // (`user_addresses`), and the web client already uses it.

  static const _addressesPath = '/customers/me/addresses';

  /// GET /customers/me/addresses
  Future<List<CustomerAddress>> fetchAddresses() async {
    try {
      final response = await _client.user.get<dynamic>(_addressesPath);
      return listFrom(
        unwrapApiResponse(response.data),
        keys: const ['addresses', 'items'],
      ).map(CustomerAddress.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// POST /customers/me/addresses — returns the saved address.
  Future<CustomerAddress> addAddress(CustomerAddress address) async {
    try {
      final response = await _client.user.post<dynamic>(
        _addressesPath,
        data: address.toJson(),
      );
      return _addressFrom(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// PATCH /customers/me/addresses/:id — returns the saved address.
  Future<CustomerAddress> updateAddress(
    String id,
    CustomerAddress address,
  ) async {
    try {
      final response = await _client.user.patch<dynamic>(
        '$_addressesPath/$id',
        data: address.toJson(),
      );
      return _addressFrom(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// DELETE /customers/me/addresses/:id
  Future<void> deleteAddress(String id) async {
    try {
      await _client.user.delete<dynamic>('$_addressesPath/$id');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// POST /customers/me/addresses/:id/default
  Future<void> setDefaultAddress(String id) async {
    try {
      await _client.user.post<dynamic>('$_addressesPath/$id/default');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  /// user-service wraps the saved address as `{data: {address: {...}}}`.
  static CustomerAddress _addressFrom(Object? raw) {
    final data = unwrapApiObject(raw);
    final nested = data['address'];
    return CustomerAddress.fromJson(
      nested is Map ? Map<String, dynamic>.from(nested) : data,
    );
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
            id: readString(json, const ['id', 'notification_id']),
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

  /// POST /notifications/device-token
  ///
  /// Without this the FCM token never reaches the server, so no order-status
  /// push can ever be addressed to this device. `platform` is required by the
  /// handler.
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _send('POST', '/notifications/device-token', <String, dynamic>{
      'token': token,
      'platform': platform,
    });
  }

  /// DELETE /notifications/device-token — called on logout so a signed-out
  /// device stops receiving another customer's order updates.
  Future<void> removeDeviceToken(String token) async {
    await _send('DELETE', '/notifications/device-token', <String, dynamic>{
      'token': token,
    });
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

  Future<Map<String, dynamic>> _post(String path, Object? body) async {
    try {
      final response = await _client.restaurant.post<dynamic>(path, data: body);
      return unwrapApiObject(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  // ------------------------------------------------------------------
  // favorites and content
  // ------------------------------------------------------------------

  Future<AppContent> fetchAppContent(String slug) async {
    final data = await _getObject('/customer-web/content/$slug');
    return AppContent(
      title: readString(data, const ['title']),
      body: readString(data, const ['body']),
    );
  }

  Future<List<FavoriteRestaurant>> fetchFavoriteRestaurants() async {
    final raw = await _get('/customer-web/favorites/restaurants');
    final list = listFrom(raw, keys: const ['restaurants']);
    return list.map((json) => FavoriteRestaurant(
      id: readString(json, const ['restaurant_id', 'id']),
      name: readString(json, const ['name']),
      imageUrl: readString(json, const ['image_url', 'image']),
      tags: readString(json, const ['tags']),
      rating: readDouble(json, const ['rating']),
    )).toList();
  }

  Future<bool> toggleFavoriteRestaurant(String restaurantId) async {
    final data = await _post('/customer-web/favorites/restaurants/$restaurantId', const {});
    return readBool(data, const ['is_favorite']);
  }

  Future<List<FavoriteGroceryItem>> fetchFavoriteGroceryItems() async {
    final raw = await _get('/customer-web/favorites/grocery');
    final list = listFrom(raw, keys: const ['items']);
    return list.map((json) => FavoriteGroceryItem(
      productId: readString(json, const ['product_id', 'id']),
      merchantId: readString(json, const ['merchant_id']),
      name: readString(json, const ['name']),
      imageUrl: readString(json, const ['image_url', 'image']),
      sellingPrice: readDouble(json, const ['selling_price']),
      packageSize: readString(json, const ['package_size']),
    )).toList();
  }

  Future<bool> toggleFavoriteGroceryItem(String productId) async {
    final data = await _post('/customer-web/favorites/grocery/$productId', const {});
    return readBool(data, const ['is_favorite']);
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
    // restaurant-service nests the identity under `customer` on both
    // GET and PATCH /customer-web/profile (see customer_web_extended.go —
    // the object sits beside `culinary_profile` and `stats`). Other handlers
    // use `user`, and some return the fields flat. Only `user` was handled
    // before, so the real profile response parsed to empty strings on every
    // field: the account screen showed "Your account / Loading your details…"
    // forever, and checkout rejected the order for a missing name.
    final nested = json['customer'] ?? json['user'] ?? json['profile'];
    final source = nested is Map
        ? <String, dynamic>{...json, ...Map<String, dynamic>.from(nested)}
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
    this.state = '',
    this.landmark = '',
    this.district = '',
    this.locationAccuracyMeters,
  });

  final String id;
  final String label;

  /// House / flat / floor and street / building, as one line.
  final String addressLine1;
  final String area;
  final String city;
  final String pincode;
  final bool isDefault;

  /// The delivery pin, from device GPS when the customer chose "Use current
  /// location". Null for an address typed without a pin.
  final double? latitude;
  final double? longitude;
  final String state;
  final String landmark;

  /// From the pincode lookup; informational.
  final String district;
  final double? locationAccuracyMeters;

  bool get hasPin => latitude != null && longitude != null;

  String get singleLine => [
    addressLine1,
    area,
    city,
    pincode,
  ].where((part) => part.isNotEmpty).join(', ');

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    double? number(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

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
      latitude: number('latitude'),
      longitude: number('longitude'),
      state: readString(json, const ['state']),
      landmark: readString(json, const ['landmark']),
      district: readString(json, const ['district']),
      locationAccuracyMeters: number('location_accuracy_meters'),
    );
  }

  /// Body for POST/PATCH /customers/me/addresses. The pin is sent only as a
  /// pair; older fields keep their names so the API stays compatible.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'address_line1': addressLine1,
    'area': area,
    'city': city,
    'state': state,
    'pincode': pincode,
    'landmark': landmark,
    'district': district,
    'is_default': isDefault,
    if (hasPin) ...{
      'latitude': latitude,
      'longitude': longitude,
      'location_accuracy_meters': ?locationAccuracyMeters,
    },
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
