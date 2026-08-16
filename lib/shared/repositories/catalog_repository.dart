import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../../core/services/api_exception.dart';
import '../models/app_models.dart';

/// Catalog reads against restaurant-service.
///
/// Every path here is already used in production by the food-ordering web
/// client (`src/services/restaurantApi.ts`); no backend change was required.
///
/// Field names are read defensively because restaurant-service returns
/// different aliases per endpoint — the web client solves this the same way in
/// `src/utils/apiAdapters.ts`. Where the backend genuinely does not return a
/// value the UI model needs (per-restaurant `deliveryFee` / `discount`), the
/// value is defaulted rather than invented; see the notes on [_restaurant].
class CatalogRepository {
  const CatalogRepository(this._client);

  final ApiClient _client;

  /// GET /api/home — offers, categories, restaurants, featured items.
  Future<HomeFeed> fetchHomeFeed({double? lat, double? lng}) async {
    final data = await _getObject(
      '/api/home',
      query: <String, dynamic>{'lat': ?lat, 'lng': ?lng},
    );
    return HomeFeed(
      restaurants: _readList(data, 'restaurants').map(_restaurant).toList(
        growable: false,
      ),
      featuredItems: _readList(data, 'featured_items')
          .map((json) => _catalogItem(json))
          .toList(growable: false),
    );
  }

  /// GET /api/restaurants — nearby / browse listing.
  Future<List<Restaurant>> fetchRestaurants({
    double? lat,
    double? lng,
    double radiusKm = 7,
    int page = 1,
    int limit = 20,
  }) async {
    final raw = await _get(
      '/api/restaurants',
      query: <String, dynamic>{
        'lat': ?lat,
        'lng': ?lng,
        if (lat != null && lng != null) 'radius_km': radiusKm,
        'page': page,
        'limit': limit,
      },
    );
    return _listFrom(raw, keys: const ['restaurants', 'items'])
        .map(_restaurant)
        .toList(growable: false);
  }

  /// GET /restaurants/public/:id — public restaurant detail.
  Future<Restaurant> fetchRestaurantDetail(String restaurantId) async {
    final data = await _getObject('/restaurants/public/$restaurantId');
    return _restaurant(data);
  }

  /// GET /api/restaurants/:id/menu/online, falling back to /menu.
  ///
  /// The fallback mirrors the web client exactly: the `online` variant is
  /// preferred, and the standard menu is used when it is unavailable.
  Future<List<MenuSection>> fetchRestaurantMenu(
    String restaurantId, {
    String? storeName,
  }) async {
    Object? raw;
    try {
      raw = await _get('/api/restaurants/$restaurantId/menu/online');
    } on ApiException {
      raw = await _get('/api/restaurants/$restaurantId/menu');
    }

    final categories = _listFrom(raw, keys: const ['categories']);
    if (categories.isNotEmpty) {
      return categories
          .map(
            (category) => MenuSection(
              id: _readString(category, const ['id']),
              name: _readString(category, const ['name']),
              items: _readList(category, 'items')
                  .map((item) => _catalogItem(item, storeName: storeName))
                  .toList(growable: false),
            ),
          )
          .where((section) => section.items.isNotEmpty)
          .toList(growable: false);
    }

    // Some deployments return a flat item list instead of categories.
    final items = _listFrom(raw, keys: const ['items']);
    if (items.isEmpty) return const <MenuSection>[];
    return <MenuSection>[
      MenuSection(
        id: 'all',
        name: 'Menu',
        items: items
            .map((item) => _catalogItem(item, storeName: storeName))
            .toList(growable: false),
      ),
    ];
  }

  /// GET /customer-web/search — cross-restaurant search.
  Future<List<Restaurant>> searchRestaurants(String query) async {
    final raw = await _get(
      '/customer-web/search',
      query: <String, dynamic>{'q': query},
    );
    return _listFrom(raw, keys: const ['restaurants', 'items', 'results'])
        .map(_restaurant)
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------
  // transport
  // ---------------------------------------------------------------------

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

  Future<Map<String, dynamic>> _getObject(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final raw = await _get(path, query: query);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  // ---------------------------------------------------------------------
  // mapping into the app's existing UI models
  // ---------------------------------------------------------------------

  /// Maps a backend restaurant onto the app's existing [Restaurant] model.
  ///
  /// `deliveryFee` and `discount` are **not** returned per-restaurant by these
  /// endpoints, so they default to 0 rather than being fabricated. Authoritative
  /// fees come from `/customer-web/cart/validate` at checkout.
  Restaurant _restaurant(Map<String, dynamic> json) {
    return Restaurant(
      id: _readString(json, const ['id', 'restaurant_id']),
      name: _readString(json, const ['name', 'restaurant_name']),
      cuisine: _readCuisine(json),
      rating: _readDouble(json, const ['average_rating', 'rating']),
      deliveryMinutes: _readDeliveryMinutes(json),
      distanceKm: _readDouble(json, const ['distance_km', 'distance']),
      deliveryFee: 0,
      discount: 0,
      imageUrl: _readString(json, const [
        'image_url',
        'banner_url',
        'cover_image_url',
        'background_image_url',
        'logo_url',
      ]),
    );
  }

  /// Maps a backend menu item / featured item onto [CatalogItem].
  ///
  /// `originalPrice` falls back to `price`, which renders as "no discount"
  /// rather than inventing a strike-through price the backend never sent.
  CatalogItem _catalogItem(Map<String, dynamic> json, {String? storeName}) {
    final price = _readDouble(json, const ['price']).round();
    final original = _readDouble(json, const [
      'original_price',
      'mrp',
    ]).round();
    return CatalogItem(
      id: _readString(json, const ['id', 'item_id', 'menu_item_id']),
      name: _readString(json, const ['name', 'item_name']),
      subtitle: _readString(json, const ['description', 'subtitle']),
      store:
          storeName ??
          _readString(json, const ['restaurant_name', 'store', 'store_name']),
      price: price,
      originalPrice: original > price ? original : price,
      imageUrl: _readString(json, const ['image_url', 'image']),
      type: CatalogItemType.food,
      isVeg: json['is_veg'] == true || json['is_vegetarian'] == true,
    );
  }
}

/// Grouped menu section returned by [CatalogRepository.fetchRestaurantMenu].
class MenuSection {
  const MenuSection({
    required this.id,
    required this.name,
    required this.items,
  });

  final String id;
  final String name;
  final List<CatalogItem> items;
}

/// Payload of `GET /api/home`.
class HomeFeed {
  const HomeFeed({required this.restaurants, required this.featuredItems});

  final List<Restaurant> restaurants;
  final List<CatalogItem> featuredItems;
}

// -----------------------------------------------------------------------
// defensive readers
// -----------------------------------------------------------------------

List<Map<String, dynamic>> _listFrom(Object? raw, {required List<String> keys}) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
  if (raw is Map) {
    for (final key in keys) {
      final nested = raw[key];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false);
      }
    }
  }
  return const <Map<String, dynamic>>[];
}

List<Map<String, dynamic>> _readList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) {
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

double _readDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

String _readCuisine(Map<String, dynamic> json) {
  final types = json['cuisine_types'];
  if (types is List && types.isNotEmpty) {
    return types.map((entry) => entry.toString()).join(', ');
  }
  return _readString(json, const ['cuisine', 'category', 'type']);
}

/// `estimated_delivery_time` arrives as text like "25-30 mins"; the UI model
/// wants a single number, so the first integer in the string is used.
int _readDeliveryMinutes(Map<String, dynamic> json) {
  for (final key in const [
    'estimated_delivery_time',
    'delivery_time',
    'delivery_minutes',
  ]) {
    final value = json[key];
    if (value is num) return value.toInt();
    if (value is String) {
      final match = RegExp(r'\d+').firstMatch(value);
      if (match != null) return int.tryParse(match.group(0)!) ?? 0;
    }
  }
  return 0;
}
