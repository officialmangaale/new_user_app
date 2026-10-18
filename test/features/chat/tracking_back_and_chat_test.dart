import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/services/api_exception.dart';
import 'package:turquoise_delivery/features/chat/domain/chat_models.dart';
import 'package:turquoise_delivery/features/chat/presentation/chat_screen.dart';
import 'package:turquoise_delivery/features/chat/providers/chat_controller.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/features/tracking/presentation/tracking_screen.dart';

import 'chat_test_support.dart';

/// The real tracking and chat screens inside the app's router shape: Orders,
/// /tracking/:id and /tracking/:id/chat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No stored token, so the tracking screen does not open its order socket.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  OrderTracking order({
    String status = 'preparing',
    String riderName = '',
    String riderPhone = '',
  }) => OrderTracking(
    orderId: '16303',
    status: status,
    statusLabel: '',
    etaMinutes: 0,
    riderName: riderName,
    riderPhone: riderPhone,
  );

  late GoRouter router;
  late FakeGateway gateway;

  Future<void> pumpApp(
    WidgetTester tester, {
    required String initialLocation,
    OrderTracking? tracking,
    FakeGateway? chat,
  }) async {
    gateway = chat ?? FakeGateway();
    final data = tracking ?? order(riderName: 'Amrit', riderPhone: '9990000001');
    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/orders',
          builder: (_, _) => const Scaffold(body: Text('ORDERS PAGE')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME PAGE')),
        ),
        GoRoute(
          path: '/tracking/:id',
          builder: (_, state) =>
              TrackingScreen(orderId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/tracking/:id/chat',
          builder: (_, state) => ChatScreen(
            orderId: state.pathParameters['id']!,
            riderName: state.uri.queryParameters['rider'] ?? '',
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderTrackingProvider.overrideWith((ref, request) async => data),
          chatGatewayProvider.overrideWithValue(gateway),
          chatTokenReaderProvider.overrideWithValue(() async => 'token'),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  // Unmount so the screens dispose their timers; a leftover periodic timer
  // fails the test.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  String location() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
    // Let a route transition finish before asserting on what is on screen.
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> showChatButton(WidgetTester tester) => tester.dragUntilVisible(
    find.byKey(const Key('tracking-chat')),
    find.byType(CustomScrollView),
    const Offset(0, -200),
  );

  group('tracking back navigation', () {
    testWidgets('shows a visible back arrow before the order title',
        (tester) async {
      await pumpApp(tester, initialLocation: '/tracking/16303');

      final back = find.byKey(const Key('tracking-back'));
      expect(back, findsOneWidget);
      expect(find.text('Order #16303'), findsOneWidget);
      // Top-left: left of the title.
      expect(
        tester.getTopLeft(back).dx,
        lessThan(tester.getTopLeft(find.text('Order #16303')).dx),
      );
      await unmount(tester);
    });

    testWidgets('normal navigation: the arrow returns to the previous screen',
        (tester) async {
      await pumpApp(tester, initialLocation: '/orders');
      router.push('/tracking/16303');
      await settle(tester);
      expect(find.byKey(const Key('tracking-back')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-back')));
      await settle(tester);

      expect(find.text('ORDERS PAGE'), findsOneWidget);
      expect(location(), '/orders');
      await unmount(tester);
    });

    testWidgets('system back follows the same rule when there is history',
        (tester) async {
      await pumpApp(tester, initialLocation: '/orders');
      router.push('/tracking/16303');
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text('ORDERS PAGE'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
        'deep link / notification: the arrow falls back to Home, not out of the app',
        (tester) async {
      await pumpApp(tester, initialLocation: '/tracking/16303');
      expect(router.canPop(), isFalse);

      await tester.tap(find.byKey(const Key('tracking-back')));
      await settle(tester);

      expect(find.text('HOME PAGE'), findsOneWidget);
      expect(location(), '/home');
      await unmount(tester);
    });

    testWidgets('deep link: system back lands on Home as well',
        (tester) async {
      await pumpApp(tester, initialLocation: '/tracking/16303');

      final handled = await tester.binding.handlePopRoute();
      await settle(tester);

      // The app handled it (did not hand it to the OS to close the app).
      expect(handled, isTrue);
      expect(find.text('HOME PAGE'), findsOneWidget);
      expect(location(), '/home');
      await unmount(tester);
    });
  });

  group('rider chat from tracking', () {
    testWidgets('no rider assigned: no chat button at all', (tester) async {
      await pumpApp(
        tester,
        initialLocation: '/tracking/16303',
        tracking: order(status: 'preparing'),
      );
      await tester.dragUntilVisible(
        find.text('Finding a delivery partner').first,
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );

      expect(find.byKey(const Key('tracking-chat')), findsNothing);
      expect(find.text('Chat'), findsNothing);
      await unmount(tester);
    });

    testWidgets('rider assigned: Chat is active and opens this order\'s chat',
        (tester) async {
      await pumpApp(
        tester,
        initialLocation: '/tracking/16303',
        chat: FakeGateway(initial: [serverMsg(1, 'I have picked it up')]),
      );
      await showChatButton(tester);
      await tester.pump();

      await tester.tap(find.byKey(const Key('tracking-chat')));
      await settle(tester);

      // On the chat screen, for this order.
      expect(find.byKey(const Key('chat-back')), findsOneWidget);
      final inChat = find.byType(ChatScreen);
      expect(
        find.descendant(of: inChat, matching: find.text('Amrit')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: inChat, matching: find.text('Order #16303')),
        findsOneWidget,
      );
      expect(find.text('I have picked it up'), findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('customer sends a message and sees it as sent', (tester) async {
      await pumpApp(tester, initialLocation: '/tracking/16303/chat?rider=Amrit');
      await settle(tester);

      await tester.enterText(find.byKey(const Key('chat-input')), 'Gate 2');
      await tester.tap(find.byKey(const Key('chat-send')));
      await settle(tester);

      expect(find.text('Gate 2'), findsOneWidget);
      expect(gateway.stored.single.body, 'Gate 2');
      expect(find.byKey(const Key('chat-sending')), findsNothing);
      expect(find.byKey(const Key('chat-retry')), findsNothing);
      await unmount(tester);
    });

    testWidgets('a failed send shows "Failed to send" and Retry resends it',
        (tester) async {
      final failing = FakeGateway()
        ..failures = 1
        ..failSendWith = const ApiException(
          statusCode: 0,
          message: 'Network error',
        );
      await pumpApp(
        tester,
        initialLocation: '/tracking/16303/chat?rider=Amrit',
        chat: failing,
      );
      await settle(tester);

      await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
      await tester.tap(find.byKey(const Key('chat-send')));
      await settle(tester);

      expect(find.text('Failed to send · Retry'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-retry')));
      await settle(tester);

      expect(find.text('Failed to send · Retry'), findsNothing);
      expect(failing.stored, hasLength(1));
      await unmount(tester);
    });

    testWidgets('a rider message appears live while the chat is open',
        (tester) async {
      await pumpApp(tester, initialLocation: '/tracking/16303/chat?rider=Amrit');
      await settle(tester);

      gateway.riderSays(5, 'Outside now');
      await settle(tester);

      expect(find.text('Outside now'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('after delivery the chat is read-only: history, no composer',
        (tester) async {
      await pumpApp(
        tester,
        initialLocation: '/tracking/16303/chat?rider=Amrit',
        chat: FakeGateway(
          availability: ended,
          initial: [serverMsg(1, 'Delivered. Enjoy!')],
        ),
      );
      await settle(tester);

      expect(find.text('Delivered. Enjoy!'), findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsNothing);
      expect(find.byKey(const Key('chat-send')), findsNothing);
      expect(find.byKey(const Key('chat-closed')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('delivered order: the Chat button is no longer active',
        (tester) async {
      await pumpApp(
        tester,
        initialLocation: '/tracking/16303',
        tracking: order(status: 'delivered', riderName: 'Amrit'),
      );
      await showChatButton(tester);
      await tester.pump();

      await tester.tap(find.byKey(const Key('tracking-chat')));
      await settle(tester);

      // Still on tracking: nothing opened.
      expect(find.byKey(const Key('chat-back')), findsNothing);
      expect(find.byKey(const Key('tracking-back')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('unread messages show a badge on the Chat button',
        (tester) async {
      await pumpApp(
        tester,
        initialLocation: '/tracking/16303',
        chat: FakeGateway(
          availability: const ChatAvailability(
            canSend: true,
            riderAssigned: true,
            unreadCount: 2,
          ),
        ),
      );
      await showChatButton(tester);
      await tester.pump();

      expect(find.byKey(const Key('chat-unread-badge')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('chat opened from a notification: back goes to tracking, then Home',
        (tester) async {
      await pumpApp(tester, initialLocation: '/tracking/16303/chat?rider=Amrit');
      await settle(tester);
      expect(router.canPop(), isFalse);

      await tester.tap(find.byKey(const Key('chat-back')));
      await settle(tester);
      expect(location(), '/tracking/16303');
      expect(find.byKey(const Key('tracking-back')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-back')));
      await settle(tester);
      expect(location(), '/home');
      await unmount(tester);
    });

    testWidgets('back from chat returns to the tracking screen it came from',
        (tester) async {
      await pumpApp(tester, initialLocation: '/tracking/16303');
      await showChatButton(tester);
      await tester.pump();
      await tester.tap(find.byKey(const Key('tracking-chat')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('chat-back')));
      await settle(tester);

      expect(find.byKey(const Key('chat-back')), findsNothing);
      expect(find.byKey(const Key('tracking-back')), findsOneWidget);
      await unmount(tester);
    });
  });
}
