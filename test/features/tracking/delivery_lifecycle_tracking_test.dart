import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/features/tracking/domain/tracking_refresh_policy.dart';
import 'package:turquoise_delivery/features/tracking/domain/tracking_timeline.dart';
import 'package:turquoise_delivery/features/tracking/presentation/tracking_screen.dart';

/// The customer side of the delivery lifecycle: what restaurant-service's
/// GET /customer-web/orders/:id/track returns after a rider accepts and at
/// each rider step, and what the tracking screen makes of it.

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

String step(String order, {String delivery = '', bool rider = false}) =>
    trackingTimelineSteps[trackingTimelineIndex(
      orderStatus: order,
      deliveryStatus: delivery,
      riderAssigned: rider,
    )];

void main() {
  group('timeline', () {
    test(
      'before a rider: confirmed, then preparing (ready is not "Rider assigned")',
      () {
        expect(step('confirmed'), 'Order confirmed');
        expect(step('preparing'), 'Preparing');
        expect(step('ready'), 'Preparing');
      },
    );

    test(
      'a rider accepting moves the timeline, whatever the kitchen is doing',
      () {
        expect(
          step('confirmed', delivery: 'rider_assigned', rider: true),
          'Rider assigned',
        );
        expect(
          step('preparing', delivery: 'rider_assigned', rider: true),
          'Rider assigned',
        );
        expect(
          step('ready', delivery: 'rider_assigned', rider: true),
          'Rider assigned',
        );
        // A rider name alone (older backend without delivery_status) is enough.
        expect(step('preparing', rider: true), 'Rider assigned');
      },
    );

    test(
      'pickup shows "Picked up" although the order is already out_for_delivery',
      () {
        expect(
          step('out_for_delivery', delivery: 'picked_up', rider: true),
          'Picked up',
        );
        expect(
          step('out_for_delivery', delivery: 'out_for_delivery', rider: true),
          'On the way',
        );
        // Older backends without delivery_status keep their previous mapping.
        expect(step('out_for_delivery', rider: true), 'On the way');
      },
    );

    test('delivered is final from either field', () {
      expect(
        step('delivered', delivery: 'out_for_delivery', rider: true),
        'Delivered',
      );
      expect(
        step('out_for_delivery', delivery: 'delivered', rider: true),
        'Delivered',
      );
      expect(step('completed'), 'Delivered');
    });
  });

  group('refresh', () {
    final t0 = DateTime(2026, 9, 11, 12);

    test('polls every 5 seconds while a partner is being found, 15 after', () {
      bool due(int seconds, {required bool awaiting}) => isTrackingRefreshDue(
        lastRefreshAt: t0,
        now: t0.add(Duration(seconds: seconds)),
        awaitingRider: awaiting,
      );
      expect(due(5, awaiting: true), isTrue);
      expect(due(4, awaiting: true), isFalse);
      expect(due(5, awaiting: false), isFalse);
      expect(due(15, awaiting: false), isTrue);
      expect(
        isTrackingRefreshDue(
          lastRefreshAt: null,
          now: t0,
          awaitingRider: false,
        ),
        isTrue,
      );
    });
  });

  test('the tracking snapshot carries delivery_status and the rider', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _StubAdapter({
        'status': 'success',
        'data': {
          'order_id': 13356,
          'order_status': 'ready',
          'status_message': 'Ready for Rider Pickup',
          'delivery_status': 'rider_assigned',
          'rider': {
            'name': 'Aman',
            'phone': '9876543210',
            'vehicle_type': 'bike',
          },
        },
      });
    final repository = OrdersRepositoryImpl(
      ApiClient(restaurantDio: dio, userDio: dio),
    );

    final tracking = (await repository.trackOrder('13356')).dataOrNull!;
    expect(tracking.status, 'ready');
    expect(tracking.deliveryStatus, 'rider_assigned');
    expect(tracking.riderName, 'Aman');
  });

  group('tracking screen', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    Future<void> pump(WidgetTester tester, OrderTracking tracking) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderTrackingProvider.overrideWith(
              (ref, request) async => tracking,
            ),
          ],
          child: const MaterialApp(home: TrackingScreen(orderId: '13356')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    OrderTracking snapshot({
      required String status,
      String deliveryStatus = '',
      String riderName = '',
    }) => OrderTracking(
      orderId: '13356',
      status: status,
      statusLabel: '',
      etaMinutes: 0,
      riderName: riderName,
      riderPhone: '',
      deliveryStatus: deliveryStatus,
    );

    testWidgets(
      'after a rider accepts, the rider replaces "Finding a delivery partner"',
      (tester) async {
        await pump(
          tester,
          snapshot(
            status: 'preparing',
            deliveryStatus: 'rider_assigned',
            riderName: 'Aman',
          ),
        );
        expect(find.text('Finding a delivery partner'), findsNothing);
        expect(find.text('Rider assigned'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'a ready order with no rider is still "Preparing", with the partner being found',
      (tester) async {
        await pump(tester, snapshot(status: 'ready'));
        expect(find.text('Preparing'), findsWidgets);
        expect(find.text('Finding a delivery partner'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('pickup shows "Picked up"', (tester) async {
      await pump(
        tester,
        snapshot(
          status: 'out_for_delivery',
          deliveryStatus: 'picked_up',
          riderName: 'Aman',
        ),
      );
      expect(find.text('Picked up'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
