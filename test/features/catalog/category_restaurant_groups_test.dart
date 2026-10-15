import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/app/theme/app_theme.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:turquoise_delivery/features/catalog/domain/entities/catalog_entities.dart';
import 'package:turquoise_delivery/features/catalog/domain/restaurant_dish_groups.dart';
import 'package:turquoise_delivery/features/catalog/presentation/category_items_screen.dart';
import 'package:turquoise_delivery/features/catalog/providers/catalog_providers.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

CatalogItem _dish(
  String id,
  String name, {
  String store = 'Iconic',
  String storeId = '1',
  int price = 49,
  double? distanceKm,
  String deliveryTime = '',
  double? rating,
  bool? isOpen,
  String logo = '',
}) => CatalogItem(
  id: id,
  name: name,
  subtitle: '',
  store: store,
  price: price,
  originalPrice: price,
  imageUrl: '',
  type: CatalogItemType.food,
  storeId: storeId,
  storeDistanceKm: distanceKm,
  storeDeliveryTime: deliveryTime,
  storeRating: rating,
  storeIsOpen: isOpen,
  storeLogoUrl: logo,
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.data);
  final Map<String, dynamic> data;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'success': true, 'data': data}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('groupDishesByRestaurant', () {
    test('dishes are grouped under their restaurant, in first-seen order', () {
      final groups = groupDishesByRestaurant([
        _dish('1', 'Masala Fries', store: 'Iconic', storeId: '1'),
        _dish('2', 'Peri Peri Fries', store: 'Khalsa Pizza', storeId: '2'),
        _dish('3', 'Salted Fries', store: 'Iconic', storeId: '1'),
      ]);

      expect(groups.map((g) => g.name), ['Iconic', 'Khalsa Pizza']);
      expect(groups[0].items.map((i) => i.name), [
        'Masala Fries',
        'Salted Fries',
      ]);
      expect(groups[1].items.map((i) => i.name), ['Peri Peri Fries']);
    });

    test('two restaurants with the same name stay separate by id', () {
      final groups = groupDishesByRestaurant([
        _dish('1', 'Fries', store: 'Cafe', storeId: '10'),
        _dish('2', 'Fries', store: 'Cafe', storeId: '11'),
      ]);
      expect(groups, hasLength(2));
    });

    test('rows without a restaurant id group by name and are not openable', () {
      final groups = groupDishesByRestaurant([
        _dish('1', 'Fries', store: 'Cafe', storeId: ''),
        _dish('2', 'Wedges', store: 'cafe', storeId: ''),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.storeId, isEmpty);
      expect(groups.single.items, hasLength(2));
    });

    test('restaurant details come from the first row that has them', () {
      final group = groupDishesByRestaurant([
        _dish('1', 'A'),
        _dish(
          '2',
          'B',
          distanceKm: 1.8,
          deliveryTime: '25 mins',
          rating: 4.3,
          isOpen: false,
          logo: 'https://x/logo.png',
        ),
      ]).single;
      expect(group.distanceKm, 1.8);
      expect(group.deliveryTime, '25 mins');
      expect(group.rating, 4.3);
      expect(group.isClosed, isTrue);
      expect(group.logoUrl, 'https://x/logo.png');
    });

    test('nothing is invented when the rows do not say', () {
      final group = groupDishesByRestaurant([_dish('1', 'A')]).single;
      expect(group.distanceKm, isNull);
      expect(group.rating, isNull);
      expect(group.isOpen, isNull);
      expect(group.isClosed, isFalse, reason: 'unknown is not closed');
    });

    test('an empty list gives no groups', () {
      expect(groupDishesByRestaurant(const []), isEmpty);
    });
  });

  group('category item parsing', () {
    test('keeps the restaurant details the server sends', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _Adapter({
          'items': [
            {
              'item_id': 5,
              'name': 'Masala Fries',
              'price': 49,
              'restaurant_id': 7,
              'restaurant_name': 'Iconic',
              'restaurant_logo': 'https://x/logo.png',
              'distance_km': 1.84,
              'delivery_time': '25 mins',
              'restaurant_is_open': false,
              'rating': 4.3,
            },
            {
              'item_id': 6,
              'name': 'Salted Fries',
              'price': 39,
              'restaurant_id': 8,
              'restaurant_name': 'Khalsa Pizza',
            },
          ],
        });
      final repo = CatalogRepositoryImpl(
        ApiClient(restaurantDio: dio, userDio: dio),
      );

      final result = await repo.fetchCategoryItems('fries');
      final items = result.dataOrNull!;

      expect(items[0].storeId, '7');
      expect(items[0].store, 'Iconic');
      expect(items[0].storeLogoUrl, 'https://x/logo.png');
      expect(items[0].storeDistanceKm, 1.84);
      expect(items[0].storeDeliveryTime, '25 mins');
      expect(items[0].storeIsOpen, isFalse);
      expect(items[0].storeRating, 4.3);
      // A row that says nothing about the restaurant leaves it unknown.
      expect(items[1].storeDistanceKm, isNull);
      expect(items[1].storeRating, isNull);
      expect(items[1].storeIsOpen, isNull);
      expect(items[1].storeLogoUrl, isEmpty);
    });
  });

  group('category screen', () {
    Future<List<String>> pump(
      WidgetTester tester,
      List<CatalogItem> dishes,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pushed = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const CategoryItemsScreen(categoryKey: 'fries', title: 'Fries'),
          ),
          GoRoute(
            path: '/restaurant/:id',
            builder: (_, state) {
              pushed.add('restaurant/${state.pathParameters['id']}');
              return const Scaffold(body: Text('restaurant page'));
            },
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          categoryItemsProvider('fries').overrideWith((ref) async => dishes),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return pushed;
    }

    testWidgets('shows the restaurants that serve it, with their dishes', (
      tester,
    ) async {
      await pump(tester, [
        _dish(
          '1',
          'Masala Fries',
          store: 'Iconic',
          storeId: '1',
          distanceKm: 1.8,
          deliveryTime: '25 mins',
          rating: 4.3,
        ),
        _dish('3', 'Salted Fries', store: 'Iconic', storeId: '1', price: 39),
        _dish('2', 'Peri Peri Fries', store: 'Khalsa Pizza', storeId: '2'),
      ]);

      expect(find.text('2 restaurants serve Fries'), findsOneWidget);
      expect(find.text('Iconic'), findsOneWidget);
      expect(find.text('Khalsa Pizza'), findsOneWidget);
      expect(find.textContaining('★ 4.3'), findsOneWidget);
      expect(find.textContaining('1.8 km'), findsOneWidget);
      expect(find.text('Masala Fries'), findsOneWidget);
      expect(find.text('Salted Fries'), findsOneWidget);
      expect(find.text('Peri Peri Fries'), findsOneWidget);
    });

    testWidgets('a single restaurant is worded in the singular', (
      tester,
    ) async {
      await pump(tester, [_dish('1', 'Masala Fries')]);
      expect(find.text('1 restaurant serves Fries'), findsOneWidget);
    });

    testWidgets('tapping a restaurant opens its menu', (tester) async {
      final pushed = await pump(tester, [
        _dish('1', 'Masala Fries', store: 'Iconic', storeId: '7'),
      ]);

      await tester.tap(find.text('Iconic'));
      await tester.pumpAndSettle();

      expect(pushed, ['restaurant/7']);
      expect(find.text('restaurant page'), findsOneWidget);
    });

    testWidgets('a closed restaurant is labelled and cannot be added from', (
      tester,
    ) async {
      await pump(tester, [
        _dish('1', 'Masala Fries', store: 'Night Owl', storeId: '4', isOpen: false),
      ]);

      expect(find.textContaining('Closed now'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(find.text('Night Owl is closed right now.'), findsOneWidget);
    });
  });
}
