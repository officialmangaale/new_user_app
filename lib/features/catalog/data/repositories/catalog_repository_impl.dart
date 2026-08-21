import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/api_exception.dart';
import '../../../../shared/repositories/json_readers.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../domain/repositories/catalog_repository_interface.dart';

/// Catalog reads against restaurant-service.
///
/// Every path here is already used in production by the food-ordering web
/// client (`src/services/restaurantApi.ts`); no backend change was required.
///
/// Field names are read defensively because restaurant-service returns
/// different aliases per endpoint — the web client solves this the same way in
/// `src/utils/apiAdapters.ts`.
class CatalogRepositoryImpl implements CatalogRepositoryInterface {
  const CatalogRepositoryImpl(this._client);

  final ApiClient _client;

  Future<Result<T>> _run<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on ApiException catch (e) {
      return Result.failure(Failure.fromApiException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<HomeFeed>> fetchHomeFeed({double? lat, double? lng}) {
    return _run(() async {
      final data = await _getObject(
        '/api/home',
        query: <String, dynamic>{
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );
      final restaurantRows = readList(data, 'restaurants');
      final trending = await _get(
        '/customer-web/trending-items',
        query: <String, dynamic>{
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          'limit': 12,
        },
      );
      return HomeFeed(
        restaurants: (restaurantRows.isNotEmpty
                ? restaurantRows
                : readList(data, 'recommended_restaurants'))
            .map(_restaurant)
            .toList(growable: false),
        featuredItems: listFrom(trending, keys: const ['items'])
            .map((json) => _catalogItem(json))
            .toList(growable: false),
      );
    });
  }

  @override
  Future<Result<List<Restaurant>>> fetchRestaurants({
    double? lat,
    double? lng,
    double radiusKm = 7,
    int page = 1,
    int limit = 20,
  }) {
    return _run(() async {
      final raw = await _get(
        '/api/restaurants',
        query: <String, dynamic>{
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (lat != null && lng != null) 'radius_km': radiusKm,
          'page': page,
          'limit': limit,
        },
      );
      return listFrom(raw, keys: const ['restaurants', 'items'])
          .map(_restaurant)
          .toList(growable: false);
    });
  }

  @override
  Future<Result<List<Restaurant>>> fetchGroceryMerchants({
    required double lat,
    required double lng,
    double radiusKm = 7,
    int limit = 20,
  }) {
    return _run(() async {
      final raw = await _get(
        '/customer-web/grocery/merchants',
        query: <String, dynamic>{
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
          'limit': limit,
        },
      );
      return listFrom(raw, keys: const ['merchants', 'items', 'results'])
          .map(_groceryMerchant)
          .toList(growable: false);
    });
  }

  @override
  Future<Result<Restaurant>> fetchRestaurantDetail(String restaurantId) {
    return _run(() async {
      final data = await _getObject('/restaurants/public/$restaurantId');
      return _restaurant(data);
    });
  }

  @override
  Future<Result<List<MenuSection>>> fetchRestaurantMenu(
    String restaurantId, {
    String? storeName,
  }) {
    return _run(() async {
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
                    .map(
                      (item) => _catalogItem(
                        item,
                        storeName: storeName,
                        storeId: restaurantId,
                      ),
                    )
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
              .map(
                (item) => _catalogItem(
                  item,
                  storeName: storeName,
                  storeId: restaurantId,
                ),
              )
              .toList(growable: false),
        ),
      ];
    });
  }

  @override
  Future<Result<List<HomeCategory>>> fetchCategories({
    double? lat,
    double? lng,
    double radiusKm = 7,
  }) {
    return _run(() async {
      final raw = await _get(
        '/customer-web/categories',
        query: <String, dynamic>{
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          'radius_km': radiusKm,
          'include_all': true,
        },
      );
      return listFrom(raw, keys: const ['categories', 'items', 'data'])
          .map(
            (json) => HomeCategory(
              key: readString(json, const ['key', 'category_key', 'slug']),
              name: readString(json, const ['name', 'category_name', 'title']),
              imageUrl: readString(json, const ['image_url', 'imageUrl']),
              icon: readString(json, const ['icon']),
              itemCount: readInt(json, const ['item_count', 'itemCount']),
            ),
          )
          .where(
            (category) => category.name.isNotEmpty && category.key.isNotEmpty,
          )
          .toList(growable: false);
    });
  }

  @override
  Future<Result<List<HomeCategory>>> fetchGroceryCategories(String merchantId) {
    return _run(() async {
      final raw = await _get(
        '/customer-web/grocery/merchants/$merchantId/categories',
      );
      return listFrom(raw, keys: const ['categories', 'items', 'data'])
          .map(
            (json) => HomeCategory(
              key: readString(json, const [
                'grocery_category_id',
                'id',
                'category_id',
              ]),
              name: readString(json, const ['name', 'category_name', 'title']),
              imageUrl: readString(json, const ['image_url', 'imageUrl']),
              icon: 'grocery',
              itemCount: 0,
            ),
          )
          .where(
            (category) => category.name.isNotEmpty && category.key.isNotEmpty,
          )
          .toList(growable: false);
    });
  }

  @override
  Future<Result<List<CatalogItem>>> fetchCategoryItems(
    String categoryKey, {
    double? lat,
    double? lng,
    int page = 1,
    int limit = 20,
  }) {
    return _run(() async {
      final raw = await _get(
        '/customer-web/categories/${Uri.encodeComponent(categoryKey)}/items',
        query: <String, dynamic>{
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          'page': page,
          'limit': limit,
        },
      );
      return listFrom(raw, keys: const ['items', 'results'])
          .map((json) => _catalogItem(json))
          .toList(growable: false);
    });
  }

  @override
  Future<Result<List<CatalogItem>>> fetchGroceryProducts(
    String merchantId, {
    required double lat,
    required double lng,
    String? merchantName,
    String? categoryId,
    String? search,
  }) {
    return _run(() async {
      final raw = await _get(
        '/customer-web/grocery/merchants/$merchantId/products',
        query: <String, dynamic>{
          'lat': lat,
          'lng': lng,
          if (categoryId != null && categoryId.isNotEmpty)
            'category_id': categoryId,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      return listFrom(raw, keys: const ['products', 'items', 'results'])
          .map((json) => _groceryProduct(json, storeName: merchantName))
          .toList(growable: false);
    });
  }

  @override
  Future<Result<List<Restaurant>>> searchRestaurants(String query) {
    return _run(() async {
      final raw = await _get(
        '/customer-web/search',
        query: <String, dynamic>{'q': query},
      );
      return listFrom(raw, keys: const ['restaurants', 'items', 'results'])
          .map(_restaurant)
          .toList(growable: false);
    });
  }

  @override
  Future<Result<CatalogSearchResults>> searchCatalog(
    String query, {
    double? lat,
    double? lng,
  }) {
    return _run(() async {
      final data = await _getObject(
        '/customer-web/search',
        query: <String, dynamic>{
          'q': query,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );
      return CatalogSearchResults(
        items: readList(data, 'dishes')
            .map((json) => _catalogItem(json))
            .toList(growable: false),
        restaurants: readList(data, 'restaurants')
            .map(_restaurant)
            .toList(growable: false),
      );
    });
  }

  @override
  Future<Result<CatalogItem>> fetchItemDetail(String itemId) {
    return _run(() async {
      final data = await _getObject('/customer-web/catalog/items/$itemId');
      return _catalogItem(data);
    });
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

  Restaurant _restaurant(Map<String, dynamic> json) {
    return Restaurant(
      id: readString(json, const ['id', 'restaurant_id']),
      name: readString(json, const ['name', 'restaurant_name']),
      cuisine: _readCuisine(json),
      rating: readDouble(json, const ['average_rating', 'rating']),
      deliveryMinutes: _readDeliveryMinutes(json),
      distanceKm: readDouble(json, const ['distance_km', 'distance']),
      deliveryFee: readDouble(json, const [
        'delivery_fee',
        'delivery_charge',
      ]).round(),
      discount: readDouble(json, const [
        'discount',
        'discount_percent',
        'offer_discount',
      ]).round(),
      imageUrl: readString(json, const [
        'image_url',
        'banner_url',
        'cover_image_url',
        'background_image_url',
        'logo_url',
      ]),
      foodShare: readBool(json, const [
        'food_share',
        'foodshare',
        'is_food_share_enabled',
      ]),
    );
  }

  CatalogItem _catalogItem(
    Map<String, dynamic> json, {
    String? storeName,
    String? storeId,
  }) {
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
      storeId: storeId ?? readString(json, const ['restaurant_id', 'store_id']),
      categoryId: readString(json, const ['category_id']),
      isVeg: json['is_veg'] == true || json['is_vegetarian'] == true,
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

  Restaurant _groceryMerchant(Map<String, dynamic> json) {
    final availableProducts = readInt(json, const [
      'available_products_count',
      'products_count',
      'item_count',
    ]);
    final description = readString(json, const ['description']);
    final distance = readDouble(json, const ['distance_km', 'distance']);
    return Restaurant(
      id: readString(json, const ['grocery_merchant_id', 'merchant_id', 'id']),
      name: readString(json, const ['name', 'store_name']),
      cuisine: description.isNotEmpty
          ? description
          : availableProducts > 0
              ? '$availableProducts products available'
              : 'Daily essentials',
      rating: readDouble(json, const ['rating', 'average_rating']),
      deliveryMinutes: _readGroceryDeliveryMinutes(json),
      distanceKm: distance,
      deliveryFee: readDouble(json, const [
        'delivery_fee',
        'delivery_charge',
      ]).round(),
      discount: 0,
      imageUrl: readString(json, const [
        'banner_url',
        'logo_url',
        'image_url',
      ]),
    );
  }

  CatalogItem _groceryProduct(
    Map<String, dynamic> json, {
    String? storeName,
  }) {
    final price = readDouble(json, const ['selling_price', 'price']).round();
    final original = readDouble(json, const ['mrp', 'original_price']).round();
    return CatalogItem(
      id: readString(json, const ['grocery_product_id', 'product_id', 'id']),
      name: readString(json, const ['name', 'product_name']),
      subtitle: _groceryProductSubtitle(json),
      store: storeName ??
          readString(json, const ['merchant_name', 'store', 'store_name']),
      price: price,
      originalPrice: original > price ? original : price,
      imageUrl: readString(json, const ['image_url', 'image']),
      type: CatalogItemType.grocery,
      storeId: readString(json, const [
        'grocery_merchant_id',
        'merchant_id',
        'store_id',
      ]),
      categoryId: readString(json, const [
        'grocery_category_id',
        'category_id',
      ]),
      isVeg: true,
    );
  }
}

// -----------------------------------------------------------------------
// mapping helpers
// -----------------------------------------------------------------------

String _readCuisine(Map<String, dynamic> json) {
  for (final key in const ['cuisine_types', 'cuisines']) {
    final types = json[key];
    if (types is List && types.isNotEmpty) {
      return types.map((entry) => entry.toString()).join(', ');
    }
  }
  return readString(json, const ['cuisine', 'category', 'type']);
}

int _readDeliveryMinutes(Map<String, dynamic> json) {
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

int _readGroceryDeliveryMinutes(Map<String, dynamic> json) {
  final explicit = readInt(json, const [
    'delivery_minutes',
    'estimated_delivery_minutes',
  ]);
  if (explicit > 0) return explicit;
  final deliveryTime = readString(json, const ['delivery_time']);
  final match = RegExp(r'\d+').firstMatch(deliveryTime);
  if (match != null) return int.tryParse(match.group(0) ?? '') ?? 30;
  return 30;
}

String _groceryProductSubtitle(Map<String, dynamic> json) {
  final parts = <String>[
    readString(json, const ['brand']),
    readString(json, const ['package_size']),
    readString(json, const ['unit']),
  ].where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.isNotEmpty) return parts.join(' • ');
  return readString(json, const ['description', 'subtitle']);
}
