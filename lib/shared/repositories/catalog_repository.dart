import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../../core/services/api_exception.dart';
import '../models/app_models.dart';
import 'json_readers.dart';

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
      restaurants: readList(data, 'restaurants').map(_restaurant).toList(
        growable: false,
      ),
      featuredItems: readList(data, 'featured_items')
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
    return listFrom(raw, keys: const ['restaurants', 'items'])
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

    final categories = listFrom(raw, keys: const ['categories']);
    if (categories.isNotEmpty) {
      return categories
          .map(
            (category) => MenuSection(
              id: readString(category, const ['id']),
              name: readString(category, const ['name']),
              items: readList(category, 'items')
                  .map((item) => _catalogItem(item, storeName: storeName))
                  .toList(growable: false),
            ),
          )
          .where((section) => section.items.isNotEmpty)
          .toList(growable: false);
    }

    // Some deployments return a flat item list instead of categories.
    final items = listFrom(raw, keys: const ['items']);
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

  /// GET /customer-web/categories — home category rail.
  ///
  /// Mirrors the web client's `getCustomerWebCategories`: same radius default
  /// and `include_all`, so the app and web show the same rail.
  Future<List<HomeCategory>> fetchCategories({
    double? lat,
    double? lng,
    double radiusKm = 7,
  }) async {
    final raw = await _get(
      '/customer-web/categories',
      query: <String, dynamic>{
        'lat': ?lat,
        'lng': ?lng,
        'radius_km': radiusKm,
        'include_all': true,
      },
    );
    return listFrom(raw, keys: const ['categories', 'items', 'data'])
        .map(
          (json) => HomeCategory(
            key: readString(json, const ['key', 'category_key', 'slug']),
            name: readString(json, const ['name', 'category_name', 'title']),
            // `image_url` is a URL; `icon` is an icon *name*, not a URL, so the
            // two must not be conflated or the tile tries to load "pizza".
            imageUrl: readString(json, const ['image_url', 'imageUrl']),
            icon: readString(json, const ['icon']),
            itemCount: readInt(json, const ['item_count', 'itemCount']),
          ),
        )
        .where(
          (category) => category.name.isNotEmpty && category.key.isNotEmpty,
        )
        .toList(growable: false);
  }

  /// GET /customer-web/categories/:key/items — dishes within a category.
  Future<List<CatalogItem>> fetchCategoryItems(
    String categoryKey, {
    double? lat,
    double? lng,
    int page = 1,
    int limit = 20,
  }) async {
    final raw = await _get(
      '/customer-web/categories/${Uri.encodeComponent(categoryKey)}/items',
      query: <String, dynamic>{
        'lat': ?lat,
        'lng': ?lng,
        'page': page,
        'limit': limit,
      },
    );
    return listFrom(raw, keys: const ['items', 'results'])
        .map((json) => _catalogItem(json))
        .toList(growable: false);
  }

  /// GET /customer-web/search — cross-restaurant search.
  Future<List<Restaurant>> searchRestaurants(String query) async {
    final raw = await _get(
      '/customer-web/search',
      query: <String, dynamic>{'q': query},
    );
    return listFrom(raw, keys: const ['restaurants', 'items', 'results'])
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
      id: readString(json, const ['id', 'restaurant_id']),
      name: readString(json, const ['name', 'restaurant_name']),
      cuisine: _readCuisine(json),
      rating: readDouble(json, const ['average_rating', 'rating']),
      deliveryMinutes: _readDeliveryMinutes(json),
      distanceKm: readDouble(json, const ['distance_km', 'distance']),
      deliveryFee: 0,
      discount: 0,
      imageUrl: readString(json, const [
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
    final price = readDouble(json, const ['price']).round();
    final original = readDouble(json, const [
      'original_price',
      'mrp',
    ]).round();
    return CatalogItem(
      id: readString(json, const ['id', 'item_id', 'menu_item_id']),
      name: readString(json, const ['name', 'item_name']),
      subtitle: readString(json, const ['description', 'subtitle']),
      store:
          storeName ??
          readString(json, const ['restaurant_name', 'store', 'store_name']),
      price: price,
      originalPrice: original > price ? original : price,
      imageUrl: readString(json, const ['image_url', 'image']),
      type: CatalogItemType.food,
      isVeg: json['is_veg'] == true || json['is_vegetarian'] == true,
      // Variants and addons must survive parsing: an order priced without them
      // undercharges the customer and loses the kitchen's instructions.
      variants: readList(json, 'variants')
          .map(
            (variant) => MenuVariant(
              id: readString(variant, const ['id', 'variant_id']),
              name: readString(variant, const ['name', 'variant_name']),
              price: readDouble(variant, const ['price']).round(),
              isAvailable: readBool(
                variant,
                const ['is_available', 'available'],
                orElse: true,
              ),
            ),
          )
          .where((variant) => variant.id.isNotEmpty)
          .toList(growable: false),
      addons: readList(json, 'addons')
          .map(
            (addon) => MenuAddon(
              id: readString(addon, const ['id', 'addon_id']),
              name: readString(addon, const ['name', 'addon_name']),
              price: readDouble(addon, const ['price']).round(),
              isAvailable: readBool(
                addon,
                const ['is_available', 'available'],
                orElse: true,
              ),
            ),
          )
          .where((addon) => addon.id.isNotEmpty)
          .toList(growable: false),
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

/// One entry in the home category rail.
class HomeCategory {
  const HomeCategory({
    required this.key,
    required this.name,
    required this.imageUrl,
    required this.icon,
    required this.itemCount,
  });

  final String key;
  final String name;

  /// Artwork URL. May be empty — fall back to [icon].
  final String imageUrl;

  /// Icon *name* (not a URL), used when [imageUrl] is empty.
  final String icon;
  final int itemCount;
}

/// Payload of `GET /api/home`.
class HomeFeed {
  const HomeFeed({required this.restaurants, required this.featuredItems});

  final List<Restaurant> restaurants;
  final List<CatalogItem> featuredItems;
}

// -----------------------------------------------------------------------
// mapping helpers
// -----------------------------------------------------------------------

String _readCuisine(Map<String, dynamic> json) {
  // `/customer-web/search` returns `cuisines`; discovery returns
  // `cuisine_types`. Both are arrays, so check each before the scalar keys.
  for (final key in const ['cuisine_types', 'cuisines']) {
    final types = json[key];
    if (types is List && types.isNotEmpty) {
      return types.map((entry) => entry.toString()).join(', ');
    }
  }
  return readString(json, const ['cuisine', 'category', 'type']);
}

/// `estimated_delivery_time` arrives as text like "25-30 mins"; the UI model
/// wants a single number, so the first integer in the string is used.
int _readDeliveryMinutes(Map<String, dynamic> json) {
  // `delivery_time_minutes` is what /customer-web/search returns; the others
  // come from the discovery endpoints and may be text like "25-30 mins".
  for (final key in const [
    'delivery_time_minutes',
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
