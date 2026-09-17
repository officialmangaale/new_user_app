import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/features/tracking/presentation/tracking_screen.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

/// A grocery shop's own rider on the customer's tracking screen (Phase 5a).
void main() {
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

  OrderTracking grocery({
    required String status,
    String riderName = '',
    String riderPhone = '',
  }) => OrderTracking(
    orderId: '12',
    status: status,
    statusLabel: '',
    etaMinutes: 0,
    riderName: riderName,
    riderPhone: riderPhone,
    restaurantName: 'Anita Daily Needs',
    orderType: 'grocery',
  );

  testWidgets('an assigned shop rider is named with their number', (
    tester,
  ) async {
    await pump(
      tester,
      grocery(
        status: 'out_for_delivery',
        riderName: 'Ravi Kumar',
        riderPhone: '9876543210',
      ),
    );

    expect(find.text('Delivered by Ravi Kumar'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(
      find.textContaining('Live rider location is not available'),
      findsOneWidget,
    );
    // Still no platform rider features.
    expect(find.text('Open in Google Maps'), findsNothing);
    expect(find.textContaining('delivery partner'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('without a rider the shop-delivery copy stays', (tester) async {
    await pump(tester, grocery(status: 'packed'));

    expect(find.textContaining('Delivered by'), findsNothing);
    expect(
      find.textContaining('The shop packs and delivers this order'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
