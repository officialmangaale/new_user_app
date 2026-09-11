import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/features/tracking/presentation/tracking_screen.dart';

/// Renders the real tracking screen, so a mistake in how the screen wires the
/// rider state — not just in the rule itself — is caught.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No stored token, so the screen does not try to open a WebSocket.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpTracking(WidgetTester tester, OrderTracking tracking) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderTrackingProvider.overrideWith((ref, request) async => tracking),
        ],
        child: const MaterialApp(home: TrackingScreen(orderId: '13279')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  // Unmount so the screen disposes its poll timer; a leftover periodic timer
  // fails the test.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  OrderTracking order({required String status, String riderName = '', String riderPhone = ''}) =>
      OrderTracking(
        orderId: '13279',
        status: status,
        statusLabel: '',
        etaMinutes: 0,
        riderName: riderName,
        riderPhone: riderPhone,
      );

  Future<void> scrollToCard(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.textContaining(RegExp('delivery partner|restaurant|Amrit', caseSensitive: false)).last,
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
  }

  // The reported order: accepted, preparing, no rider.
  testWidgets('an accepted order with no rider says a partner is being found',
      (tester) async {
    await pumpTracking(tester, order(status: 'preparing'));
    await scrollToCard(tester);

    expect(find.text('Finding a delivery partner'), findsWidgets);
    // Everything that used to imply a rider existed is gone.
    expect(find.text('Assigned by restaurant'), findsNothing);
    expect(find.text('Call'), findsNothing);
    expect(find.text('Chat'), findsNothing);

    await unmount(tester);
  });

  testWidgets('before the restaurant accepts, it does not claim a search has started',
      (tester) async {
    await pumpTracking(tester, order(status: 'pending'));
    await scrollToCard(tester);

    expect(find.text('Waiting for the restaurant'), findsOneWidget);
    expect(find.text('Finding a delivery partner'), findsNothing);
    expect(find.text('Chat'), findsNothing);

    await unmount(tester);
  });

  // The existing behaviour that must not regress.
  testWidgets('an assigned rider still gets the full card with call and chat',
      (tester) async {
    await pumpTracking(
      tester,
      order(status: 'preparing', riderName: 'Amrit', riderPhone: '9990000001'),
    );
    await scrollToCard(tester);

    expect(find.text('Amrit'), findsWidgets);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Finding a delivery partner'), findsNothing);

    await unmount(tester);
  });

  // With a rider but no phone, the card must not guess how they were assigned.
  testWidgets('an assigned rider without a phone is not described as restaurant-assigned',
      (tester) async {
    await pumpTracking(tester, order(status: 'preparing', riderName: 'Amrit'));
    await scrollToCard(tester);

    expect(find.text('Assigned by restaurant'), findsNothing);
    expect(find.text('Your delivery partner'), findsOneWidget);

    await unmount(tester);
  });
}
