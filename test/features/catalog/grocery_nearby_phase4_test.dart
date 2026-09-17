import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/error/result.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/core/services/location_service.dart';
import 'package:turquoise_delivery/features/app_state/providers/location_providers.dart';
import 'package:turquoise_delivery/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:turquoise_delivery/features/catalog/domain/entities/catalog_entities.dart';
import 'package:turquoise_delivery/features/catalog/domain/repositories/catalog_repository_interface.dart';
import 'package:turquoise_delivery/features/catalog/providers/catalog_providers.dart';

/// Serves one canned JSON body and records the requested URLs.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final Map<String, dynamic> body;
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(CatalogRepositoryImpl, _StubAdapter) _repositoryServing(
  Map<String, dynamic> data,
) {
  final adapter = _StubAdapter({'success': true, 'data': data});
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  return (
    CatalogRepositoryImpl(ApiClient(restaurantDio: dio, userDio: dio)),
    adapter,
  );
}

const _milk = <String, dynamic>{
  'grocery_product_id': 11,
  'grocery_merchant_id': 7,
  'grocery_category_id': 3,
  'name': 'Toned Milk',
  'brand': 'Amul',
  'mrp': 30,
  'selling_price': 28,
  'package_size': '500 ml',
  'is_available': true,
  'category_key': 'dairy',
  'category_name': 'Dairy',
  'merchant_name': 'Anita Daily Needs',
  'merchant_distance_km': 1.2,
  'delivery_time': '30-45 mins',
  'delivery_fee': 20,
};

/// Records what the providers ask for; any other call fails the test.
class _RecordingCatalog implements CatalogRepositoryInterface {
  final productCalls = <Map<String, Object?>>[];
  final detailCalls = <String>[];
  var categoryCalls = 0;

  static const _item = CatalogItem(
    id: '11',
    name: 'Toned Milk',
    subtitle: '',
    store: 'Anita Daily Needs',
    price: 28,
    originalPrice: 30,
    imageUrl: '',
    type: CatalogItemType.grocery,
    storeId: '7',
  );

  @override
  Future<Result<GroceryProductPage>> fetchNearbyGroceryProducts({
    required double lat,
    required double lng,
    double radiusKm = 7,
    String? categoryKey,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    productCalls.add({
      'lat': lat,
      'categoryKey': categoryKey,
      'search': search,
      'limit': limit,
    });
    return Result.success(
      const GroceryProductPage(items: [_item], hasMore: false),
    );
  }

  @override
  Future<Result<List<HomeCategory>>> fetchNearbyGroceryCategories({
    required double lat,
    required double lng,
    double radiusKm = 7,
  }) async {
    categoryCalls++;
    return Result.success(const [
      HomeCategory(
        key: 'dairy',
        name: 'Dairy',
        imageUrl: '',
        icon: 'grocery',
        itemCount: 2,
      ),
    ]);
  }

  @override
  Future<Result<CatalogItem>> fetchGroceryProductDetail(
    String productId, {
    required double lat,
    required double lng,
    double radiusKm = 7,
  }) async {
    detailCalls.add(productId);
    return Result.success(_item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected catalog call: ${invocation.memberName}');
}

ProviderContainer _containerWith(
  _RecordingCatalog catalog, {
  UserLocation? location = const UserLocation(latitude: 12.9, longitude: 77.5),
}) {
  final container = ProviderContainer(
    // A failing provider must fail the test at once, not be retried.
    retry: (_, _) => null,
    overrides: [
      catalogRepositoryProvider.overrideWithValue(catalog),
      currentLocationProvider.overrideWith((ref) async => location),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('CatalogRepositoryImpl nearby grocery', () {
    test('products page reads shop details and has_more', () async {
      final (repo, adapter) = _repositoryServing({
        'products': [_milk],
        'page': 2,
        'limit': 10,
        'has_more': true,
      });

      final result = await repo.fetchNearbyGroceryProducts(
        lat: 12.9,
        lng: 77.5,
        categoryKey: ' Dairy ',
        search: 'milk',
        page: 2,
        limit: 10,
      );

      final page = result.when(
        success: (data) => data,
        failure: (f) => fail('$f'),
      );
      expect(page.hasMore, isTrue);
      final item = page.items.single;
      expect(item.id, '11');
      expect(item.store, 'Anita Daily Needs');
      expect(item.storeId, '7');
      expect(item.price, 28);
      expect(item.originalPrice, 30);
      expect(item.type, CatalogItemType.grocery);

      final uri = adapter.requests.single;
      expect(uri.path, '/customer-web/grocery/products');
      expect(uri.queryParameters, {
        'lat': '12.9',
        'lng': '77.5',
        'radius_km': '7.0',
        'category_key': 'Dairy',
        'search': 'milk',
        'page': '2',
        'limit': '10',
      });
    });

    test('categories use the merged key and product count', () async {
      final (repo, adapter) = _repositoryServing({
        'categories': [
          {
            'category_key': 'dairy',
            'name': 'Dairy',
            'merchant_count': 2,
            'product_count': 5,
          },
          {'category_key': '', 'name': 'Broken'},
        ],
      });

      final result = await repo.fetchNearbyGroceryCategories(
        lat: 12.9,
        lng: 77.5,
      );

      final categories = result.when(
        success: (data) => data,
        failure: (f) => fail('$f'),
      );
      expect(categories, hasLength(1));
      expect(categories.single.key, 'dairy');
      expect(categories.single.name, 'Dairy');
      expect(categories.single.itemCount, 5);
      expect(adapter.requests.single.path, '/customer-web/grocery/categories');
    });

    test('product detail is fetched by id', () async {
      final (repo, adapter) = _repositoryServing({'product': _milk});

      final result = await repo.fetchGroceryProductDetail(
        '11',
        lat: 12.9,
        lng: 77.5,
      );

      final item = result.when(
        success: (data) => data,
        failure: (f) => fail('$f'),
      );
      expect(item.id, '11');
      expect(item.store, 'Anita Daily Needs');
      expect(adapter.requests.single.path, '/customer-web/grocery/products/11');
    });

    test('product detail without a product is a failure', () async {
      final (repo, _) = _repositoryServing({'other': true});

      final result = await repo.fetchGroceryProductDetail(
        '11',
        lat: 12.9,
        lng: 77.5,
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('grocery providers use every nearby shop', () {
    test('home products, categories, category items and search', () async {
      final catalog = _RecordingCatalog();
      final container = _containerWith(catalog);

      expect(
        await container.read(nearbyGroceryProductsProvider.future),
        hasLength(1),
      );
      expect(
        (await container.read(groceryCategoriesProvider.future)).single.key,
        'dairy',
      );
      await container.read(groceryCategoryItemsProvider('dairy').future);
      await container.read(grocerySearchResultsProvider('milk').future);

      expect(catalog.categoryCalls, 1);
      expect(catalog.productCalls, [
        {'lat': 12.9, 'categoryKey': null, 'search': null, 'limit': 20},
        {'lat': 12.9, 'categoryKey': 'dairy', 'search': null, 'limit': 50},
        {'lat': 12.9, 'categoryKey': null, 'search': 'milk', 'limit': 50},
      ]);
    });

    test('product detail resolves ids outside the home list', () async {
      final catalog = _RecordingCatalog();
      final container = _containerWith(catalog);

      final item = await container.read(
        groceryProductDetailProvider('99').future,
      );

      expect(item.name, 'Toned Milk');
      expect(catalog.detailCalls, ['99']);
      expect(catalog.productCalls, isEmpty);
    });

    test('without a location nothing is requested', () async {
      final catalog = _RecordingCatalog();
      final container = _containerWith(catalog, location: null);

      expect(
        await container.read(nearbyGroceryProductsProvider.future),
        isEmpty,
      );
      expect(await container.read(groceryCategoriesProvider.future), isEmpty);
      await expectLater(
        container.read(groceryProductDetailProvider('11').future),
        throwsA(isA<Exception>()),
      );
      expect(catalog.productCalls, isEmpty);
      expect(catalog.detailCalls, isEmpty);
      expect(catalog.categoryCalls, 0);
    });
  });
}
