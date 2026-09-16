import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/error/result.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/core/services/grocery_push_open_broker.dart';
import 'package:turquoise_delivery/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:turquoise_delivery/features/orders/domain/use_cases/orders_use_cases.dart';
import 'package:turquoise_delivery/features/orders/presentation/orders_screen.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/features/tracking/domain/grocery_tracking.dart';
import 'package:turquoise_delivery/features/tracking/presentation/tracking_screen.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

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

(OrdersRepositoryImpl, _StubAdapter) repositoryServing(Map<String, dynamic> body) {
  final adapter = _StubAdapter(body);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  return (OrdersRepositoryImpl(ApiClient(restaurantDio: dio, userDio: dio)), adapter);
}

GroceryOrderSummary _summary(String id) => GroceryOrderSummary(
  id: id,
  merchantName: 'Anita Daily Needs',
  status: 'packing',
  statusLabel: 'Items are being packed',
  total: 310,
  itemCount: 2,
  createdAt: DateTime.utc(2026, 9, 15, 10),
);

class _PagedGroceryOrders implements FetchGroceryOrdersUseCase {
  final requestedPages = <int>[];

  @override
  Future<Result<GroceryOrderPage>> call({int page = 1, int limit = 10}) async {
    requestedPages.add(page);
    // Page 2 repeats order 2: a new order arrived and shifted the pages.
    return Result.success(
      page == 1
          ? GroceryOrderPage(orders: [_summary('3'), _summary('2')], hasMore: true)
          : GroceryOrderPage(orders: [_summary('2'), _summary('1')], hasMore: false),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(GroceryPushOpenBroker.instance.reset);

  test('grocery history comes from its own paginated endpoint', () async {
    final (repository, adapter) = repositoryServing({
      'success': true,
      'data': {
        'orders': [
          {
            'grocery_order_id': 12,
            'order_type': 'grocery',
            'grocery_merchant_id': 7,
            'merchant_name': 'Anita Daily Needs',
            'order_status': 'packing',
            'status_message': 'Items are being packed',
            'grand_total': 310.5,
            'item_count': 2,
            'created_at': '2026-09-15T10:00:00Z',
          },
        ],
        'pagination': {'page': 2, 'limit': 10, 'has_more': true},
      },
    });

    final page = (await repository.fetchGroceryOrders(page: 2)).dataOrNull;

    expect(adapter.requests.single.path, '/customer-web/grocery/orders');
    expect(adapter.requests.single.queryParameters['page'], '2');
    expect(page, isNotNull);
    expect(page!.hasMore, isTrue);
    final order = page.orders.single;
    expect(order.id, '12');
    expect(order.merchantName, 'Anita Daily Needs');
    expect(order.status, 'packing');
    expect(order.total, closeTo(310.5, 1e-9));
    expect(order.itemCount, 2);
    expect(order.isFinished, isFalse);
  });

  test('grocery tracking carries the shop reason and recorded steps', () async {
    final (repository, adapter) = repositoryServing({
      'success': true,
      'data': {
        'grocery_order_id': 12,
        'order_type': 'grocery',
        'merchant': {'grocery_merchant_id': 7, 'name': 'Anita Daily Needs'},
        'order_status': 'rejected',
        'status_message': 'Rejected by grocery merchant',
        'status_reason': 'Shop closing early',
        'timeline': [
          {'status': 'placed', 'label': 'Order placed', 'timestamp': '2026-09-15T10:00:00Z'},
          {'status': 'rejected', 'label': 'Rejected by grocery merchant', 'timestamp': '2026-09-15T10:03:00Z'},
        ],
      },
    });

    final tracking = (await repository.trackGroceryOrder('12')).dataOrNull;

    expect(adapter.requests.single.path, '/customer-web/grocery/orders/12/track');
    expect(tracking, isNotNull);
    expect(tracking!.orderType, 'grocery');
    expect(tracking.status, 'rejected');
    expect(tracking.statusReason, 'Shop closing early');
    expect(tracking.restaurantName, 'Anita Daily Needs');
    expect(tracking.timeline.map((e) => e.status), ['placed', 'rejected']);
    expect(tracking.timeline.last.at, DateTime.utc(2026, 9, 15, 10, 3));
    expect(tracking.riderName, isEmpty);
  });

  test('grocery progress follows the grocery lifecycle, not the rider steps', () {
    expect(groceryTrackingIndex('placed'), 0);
    expect(groceryTrackingIndex('packing'), 2);
    expect(groceryTrackingIndex('out_for_delivery'), 4);
    expect(groceryTrackingIndex('rejected', reached: ['placed']), 0);
    expect(groceryTrackingIndex('cancelled', reached: ['placed', 'accepted', 'packing']), 2);
    expect(isGroceryOrderStopped('Cancelled'), isTrue);
    expect(isGroceryOrderStopped('delivered'), isFalse);
    expect(groceryStatusTitle('rejected'), 'Declined by the shop');
    expect(groceryTrackingStepLabels, isNot(contains('Rider assigned')));
  });

  group('grocery tracking screen', () {
    Future<void> pump(WidgetTester tester, OrderTracking tracking) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderTrackingProvider.overrideWith((ref, request) async => tracking),
          ],
          child: const MaterialApp(
            home: TrackingScreen(orderId: '12', mode: DeliveryMode.grocery),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('shows the shop progress and never a rider', (tester) async {
      await pump(
        tester,
        const OrderTracking(
          orderId: '12',
          status: 'packing',
          statusLabel: 'Items are being packed',
          etaMinutes: 0,
          riderName: '',
          riderPhone: '',
          restaurantName: 'Anita Daily Needs',
          orderType: 'grocery',
        ),
      );

      expect(find.text('Grocery order #12'), findsOneWidget);
      expect(find.text('Packing your order'), findsOneWidget);
      expect(find.text('Anita Daily Needs'), findsOneWidget);
      expect(find.text('Packing'), findsOneWidget);
      expect(find.textContaining('delivery partner'), findsNothing);
      expect(find.text('Open in Google Maps'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a declined order shows the reason from the shop', (tester) async {
      await pump(
        tester,
        const OrderTracking(
          orderId: '12',
          status: 'rejected',
          statusLabel: 'Rejected by grocery merchant',
          etaMinutes: 0,
          riderName: '',
          riderPhone: '',
          orderType: 'grocery',
          statusReason: 'Shop closing early',
          timeline: [
            TrackingTimelineEntry(status: 'placed', label: 'Order placed'),
            TrackingTimelineEntry(status: 'rejected', label: 'Rejected by grocery merchant'),
          ],
        ),
      );

      expect(find.text('Declined by the shop'), findsOneWidget);
      expect(find.text('Shop closing early'), findsOneWidget);
      expect(find.text('Rejected by grocery merchant'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('the grocery tab pages on its own and never repeats an order', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final grocery = _PagedGroceryOrders();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersProvider.overrideWith((ref) async => const <DeliveryOrder>[]),
          fetchGroceryOrdersUseCaseProvider.overrideWithValue(grocery),
        ],
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No active orders'), findsOneWidget, reason: 'food history is unchanged');

    await tester.tap(find.text('Grocery'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('grocery_order_3')), findsOneWidget);
    expect(find.byKey(const ValueKey('grocery_order_2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('grocery_orders_load_more')));
    await tester.pumpAndSettle();
    for (final id in ['3', '2', '1']) {
      expect(find.byKey(ValueKey('grocery_order_$id')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('grocery_orders_load_more')), findsNothing);
    expect(grocery.requestedPages, [1, 2]);
  });

  test('only customer grocery notifications open grocery tracking', () {
    expect(
      GroceryOrderPushTarget.fromData({
        'type': 'grocery_order_status_updated',
        'order_type': 'grocery',
        'recipient_type': 'customer',
        'action_type': 'openGroceryOrder',
        'orderId': '12',
        'status': 'packed',
      }),
      const GroceryOrderPushTarget('12'),
    );
    expect(GroceryOrderPushTarget.fromData({'type': 'order_status_updated', 'orderId': '12'}), isNull);
    expect(GroceryOrderPushTarget.fromData({'action_type': 'openGroceryOrder', 'orderId': '../12'}), isNull);

    final opened = <GroceryOrderPushTarget>[];
    GroceryPushOpenBroker.instance.publishOpened({'action_type': 'openGroceryOrder', 'orderId': '12'});
    expect(opened, isEmpty);
    GroceryPushOpenBroker.instance.attach(opened.add);
    expect(opened, [const GroceryOrderPushTarget('12')], reason: 'a cold-start tap waits for the app');
  });
}
