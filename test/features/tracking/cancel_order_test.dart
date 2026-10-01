import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/error/failures.dart';
import 'package:turquoise_delivery/core/error/result.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/orders/domain/repositories/orders_repository_interface.dart';
import 'package:turquoise_delivery/features/orders/domain/use_cases/orders_use_cases.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/features/tracking/presentation/tracking_screen.dart';

/// A customer can cancel a food order only while it is pending. The control is
/// shown only then, asks for confirmation, calls the backend, and reports the
/// server's own reason when it is refused.

class _CancelCalls extends CancelOrderUseCase {
  _CancelCalls(this.result) : super(_Unused());

  final Result<void> result;
  final List<String> cancelled = [];

  @override
  Future<Result<void>> call(String orderId) async {
    cancelled.add(orderId);
    return result;
  }
}

// CancelOrderUseCase needs a repository to construct; it is never used because
// call() is overridden.
class _Unused implements OrdersRepositoryInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // No stored token, so the screen does not try to open a WebSocket.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  OrderTracking order(String status) => OrderTracking(
    orderId: '13279',
    status: status,
    statusLabel: '',
    etaMinutes: 0,
    riderName: '',
    riderPhone: '',
  );

  Future<void> pump(
    WidgetTester tester,
    String status, {
    _CancelCalls? cancel,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderTrackingProvider.overrideWith(
            (ref, request) async => order(status),
          ),
          if (cancel != null)
            cancelOrderUseCaseProvider.overrideWithValue(cancel),
        ],
        child: const MaterialApp(home: TrackingScreen(orderId: '13279')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  final cancelButton = find.byKey(const ValueKey('cancel_order_button'));

  testWidgets('cancel is offered only while the order is pending', (
    tester,
  ) async {
    await pump(tester, 'pending');
    expect(cancelButton, findsOneWidget);
    await unmount(tester);

    for (final status in [
      'confirmed',
      'preparing',
      'ready',
      'out_for_delivery',
      'delivered',
      'cancelled',
    ]) {
      await pump(tester, status);
      expect(
        cancelButton,
        findsNothing,
        reason: 'no cancel once the order is $status',
      );
      await unmount(tester);
    }
  });

  testWidgets('declining the confirmation does nothing', (tester) async {
    final calls = _CancelCalls(Result.success(null));
    await pump(tester, 'pending', cancel: calls);

    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget);
    await tester.tap(find.text('Keep order'));
    await tester.pumpAndSettle();

    expect(calls.cancelled, isEmpty);
    await unmount(tester);
  });

  testWidgets('confirming cancels the order and says so', (tester) async {
    final calls = _CancelCalls(Result.success(null));
    await pump(tester, 'pending', cancel: calls);

    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_cancel_order')));
    await tester.pumpAndSettle();

    expect(calls.cancelled, ['13279']);
    expect(find.text('Your order was cancelled.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a refusal shows the server reason and never claims success', (
    tester,
  ) async {
    const reason =
        'The restaurant has already accepted your order, so it can no longer be cancelled here.';
    final calls = _CancelCalls(
      Result.failure(const ServerFailure(reason, statusCode: 409)),
    );
    await pump(tester, 'pending', cancel: calls);

    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_cancel_order')));
    await tester.pumpAndSettle();

    expect(find.text(reason), findsOneWidget);
    expect(find.text('Your order was cancelled.'), findsNothing);
    await unmount(tester);
  });
}
