import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turquoise_delivery/core/services/grocery_push_open_broker.dart';
import 'package:turquoise_delivery/core/services/ongoing_order_notification.dart';
import 'package:turquoise_delivery/features/home/presentation/widgets/live_order_banner.dart';
import 'package:turquoise_delivery/features/orders/providers/live_orders_provider.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

void main() {
  group('LiveOrderNotice.fromPushData', () {
    Map<String, dynamic> push(String status, {String? recipient}) => {
      'type': 'order_status_updated',
      'recipient_type': recipient ?? 'customer',
      'orderId': '4821',
      'status': status,
    };

    test('an in-progress status becomes an ongoing notice', () {
      final notice = LiveOrderNotice.fromPushData(push('preparing'));
      expect(notice, isNotNull);
      expect(notice!.orderId, '4821');
      expect(notice.body, 'Being prepared');
      expect(notice.grocery, isFalse);
    });

    test('out for delivery reads as on the way', () {
      expect(
        LiveOrderNotice.fromPushData(push('out_for_delivery'))!.body,
        'On the way to you',
      );
    });

    test('finished statuses produce no notice, only a cancel', () {
      for (final s in ['delivered', 'cancelled', 'rejected', 'completed']) {
        expect(LiveOrderNotice.fromPushData(push(s)), isNull, reason: s);
        expect(LiveOrderNotice.finishedOrderId(push(s)), '4821', reason: s);
      }
    });

    test('restaurant/rider alerts and promotions never create one', () {
      expect(
        LiveOrderNotice.fromPushData(push('preparing', recipient: 'restaurant')),
        isNull,
      );
      expect(
        LiveOrderNotice.fromPushData({'type': 'promo', 'orderId': '1'}),
        isNull,
      );
      expect(
        LiveOrderNotice.fromPushData({
          'type': 'order_status_updated',
          'orderId': 'abc',
          'status': 'preparing',
        }),
        isNull,
      );
    });
  });

  group('FoodOrderPushTarget', () {
    test('a food status push opens that order', () {
      final target = FoodOrderPushTarget.fromData({
        'type': 'order_status_updated',
        'recipient_type': 'customer',
        'order_id': '77',
      });
      expect(target, const FoodOrderPushTarget('77'));
    });

    test('grocery pushes stay with the grocery target', () {
      final data = {
        'type': 'order_status_updated',
        'recipient_type': 'customer',
        'order_type': 'grocery',
        'orderId': '9',
      };
      expect(FoodOrderPushTarget.fromData(data), isNull);
      expect(GroceryOrderPushTarget.fromData(data), isNotNull);
    });

    test('the ongoing notification payload routes to tracking', () {
      final notice = LiveOrderNotice.fromPushData({
        'type': 'order_status_updated',
        'orderId': '4821',
        'status': 'ready',
      })!;
      // What OngoingOrderNotification stores as the tap payload.
      final payload = {
        'type': 'order_status_updated',
        'recipient_type': 'customer',
        'order_id': notice.orderId,
        'orderId': notice.orderId,
      };
      expect(
        FoodOrderPushTarget.fromData(payload),
        const FoodOrderPushTarget('4821'),
      );
    });

    test('the broker keeps a tap that arrives before the app is ready', () {
      final broker = GroceryPushOpenBroker.instance..reset();
      FoodOrderPushTarget? opened;
      broker.publishOpened({
        'type': 'order_status_updated',
        'recipient_type': 'customer',
        'orderId': '5',
      });
      broker.attachFood((t) => opened = t);
      expect(opened, const FoodOrderPushTarget('5'));
      broker.reset();
    });
  });

  group('LiveOrderBanner', () {
    Future<void> pump(WidgetTester tester, List<LiveOrder> orders) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: LiveOrderBanner()),
          ),
          GoRoute(
            path: '/tracking/:id',
            builder: (_, s) =>
                Scaffold(body: Text('tracking ${s.pathParameters['id']}')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveOrdersProvider.overrideWith((ref) async => orders),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows nothing without a live order', (tester) async {
      await pump(tester, const []);
      expect(find.byKey(const Key('live-order-banner')), findsNothing);
    });

    testWidgets('shows the order and opens tracking on tap', (tester) async {
      await pump(tester, const [
        LiveOrder(
          id: '4821',
          store: 'Spice Route',
          mode: DeliveryMode.grocery,
          statusLabel: 'Packing your order',
        ),
        LiveOrder(id: '4822', store: 'Burger Club', mode: DeliveryMode.food),
      ]);
      expect(find.text('Spice Route'), findsOneWidget);
      expect(find.textContaining('Packing your order'), findsOneWidget);
      expect(find.textContaining('+1 more'), findsOneWidget);
      expect(find.text('Track order'), findsOneWidget);

      await tester.tap(find.byKey(const Key('live-order-banner')));
      await tester.pumpAndSettle();
      expect(find.text('tracking 4821'), findsOneWidget);
    });
  });
}
