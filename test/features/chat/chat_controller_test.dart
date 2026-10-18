import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/services/api_exception.dart';
import 'package:turquoise_delivery/features/chat/domain/chat_models.dart';
import 'package:turquoise_delivery/features/chat/providers/chat_controller.dart';

import 'chat_test_support.dart';

void main() {
  late FakeGateway gateway;
  late ProviderContainer container;

  ProviderContainer makeContainer(FakeGateway g) {
    final c = ProviderContainer(
      overrides: [
        chatGatewayProvider.overrideWithValue(g),
        chatTokenReaderProvider.overrideWithValue(() async => 'token'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ChatSession session() => container.read(chatControllerProvider('16303'));
  ChatController controller() =>
      container.read(chatControllerProvider('16303').notifier);

  /// Keeps the autoDispose provider alive for the length of a test.
  void open() {
    container.listen(chatControllerProvider('16303'), (_, _) {});
  }

  group('history and realtime', () {
    test('loads the conversation, then goes live', () async {
      gateway = FakeGateway(initial: [serverMsg(1, 'On my way')]);
      container = makeContainer(gateway);
      open();
      expect(session().loading, isTrue);
      await settle();

      expect(session().loading, isFalse);
      expect(session().messages.map((m) => m.body), ['On my way']);
      expect(session().connection, ChatConnection.live);
      expect(gateway.events$, hasLength(1));
    });

    test('a message from the rider arrives in realtime and is marked read',
        () async {
      gateway = FakeGateway();
      container = makeContainer(gateway);
      open();
      await settle();

      gateway.riderSays(7, 'I am at the gate');
      await settle();

      expect(session().messages.single.body, 'I am at the gate');
      expect(session().messages.single.fromMe, isFalse);
      expect(gateway.readUpTo, [7]);
    });

    test('the same realtime message delivered twice is shown once', () async {
      gateway = FakeGateway();
      container = makeContainer(gateway);
      open();
      await settle();

      gateway.riderSays(7, 'hello');
      gateway.events$.last.add(serverMsg(7, 'hello'));
      await settle();

      expect(session().messages, hasLength(1));
    });

    test('a failed first load offers retry instead of a blank screen',
        () async {
      gateway = FakeGateway()
        ..failFetchWith = const ApiException(statusCode: 0, message: 'offline');
      container = makeContainer(gateway);
      open();
      await settle();

      expect(session().loading, isFalse);
      expect(session().loadError, isNotNull);
      expect(session().messages, isEmpty);

      gateway.failFetchWith = null;
      gateway.stored.add(serverMsg(1, 'hi'));
      await controller().reload();
      await settle();

      expect(session().loadError, isNull);
      expect(session().messages.single.body, 'hi');
    });
  });

  group('sending', () {
    test('a sent message shows immediately, then settles as sent', () async {
      gateway = FakeGateway();
      container = makeContainer(gateway);
      open();
      await settle();

      final pending = controller().send('Please call me');
      // Optimistic: visible before the server has answered.
      expect(session().messages.single.delivery, ChatDelivery.sending);
      await pending;

      expect(session().messages, hasLength(1));
      final sent = session().messages.single;
      expect(sent.delivery, ChatDelivery.sent);
      expect(sent.messageId, isNotNull);
      expect(sent.fromMe, isTrue);
    });

    test('blank and over-long messages are not sent', () async {
      gateway = FakeGateway();
      container = makeContainer(gateway);
      open();
      await settle();

      await controller().send('   ');
      await controller().send('x' * (chatMaxBodyLength + 1));

      expect(gateway.sendCalls, 0);
      expect(session().messages, isEmpty);
    });

    test('a failed send is marked failed and retry reuses the client id',
        () async {
      gateway = FakeGateway()
        ..failures = 1
        ..failSendWith = const ApiException(
          statusCode: 0,
          message: 'Network error',
        );
      container = makeContainer(gateway);
      open();
      await settle();

      await controller().send('Gate 2 please');
      final failed = session().messages.single;
      expect(failed.delivery, ChatDelivery.failed);
      expect(session().notice, isNotNull);

      await controller().retry(failed.clientMessageId);

      expect(session().messages, hasLength(1));
      expect(session().messages.single.delivery, ChatDelivery.sent);
      // Same id both times: the server can recognise it as one message.
      expect(gateway.sentClientIds.toSet(), hasLength(1));
      expect(gateway.sendCalls, 2);
      expect(gateway.stored, hasLength(1));
    });

    test('a send the server stored but whose response was lost is not duplicated',
        () async {
      gateway = FakeGateway()..storeThenLoseResponse = true;
      container = makeContainer(gateway);
      open();
      await settle();

      await controller().send('One more thing');
      final lost = session().messages.single;
      // The app only saw a network error, so it offers Retry...
      expect(lost.delivery, ChatDelivery.failed);
      // ...but the server already has the message.
      expect(gateway.stored, hasLength(1));

      await controller().retry(lost.clientMessageId);

      // Retry reused the client id, so the server replayed the stored message.
      expect(gateway.stored, hasLength(1));
      expect(session().messages, hasLength(1));
      expect(session().messages.single.delivery, ChatDelivery.sent);
    });

    test('sending is refused while chat is closed', () async {
      gateway = FakeGateway(
        availability: const ChatAvailability(reason: 'no_rider'),
      );
      container = makeContainer(gateway);
      open();
      await settle();

      await controller().send('hello?');

      expect(gateway.sendCalls, 0);
      expect(session().availability.canSend, isFalse);
      expect(
        session().availability.closedMessage,
        contains('once a delivery partner is assigned'),
      );
      // Nothing to listen to before a rider exists.
      expect(gateway.events$, isEmpty);
    });

    test('the server closing chat mid-send fails the message and refreshes',
        () async {
      gateway = FakeGateway()
        ..failures = 1
        ..failSendWith = const ApiException(
          statusCode: 409,
          code: 'CHAT_CLOSED',
          message: 'closed',
        );
      container = makeContainer(gateway);
      open();
      await settle();
      final fetchesBefore = gateway.fetchCalls;

      gateway.availability = ended;
      await controller().send('too late');
      await settle();

      expect(session().messages.single.delivery, ChatDelivery.failed);
      expect(session().notice, contains('chat is closed'));
      expect(gateway.fetchCalls, greaterThan(fetchesBefore));
      expect(session().availability.readOnly, isTrue);
    });
  });

  group('delivery finished', () {
    test('history is shown read-only with no socket and no composer',
        () async {
      gateway = FakeGateway(
        availability: ended,
        initial: [serverMsg(1, 'Delivered, enjoy')],
      );
      container = makeContainer(gateway);
      open();
      await settle();

      expect(session().messages.single.body, 'Delivered, enjoy');
      expect(session().availability.canSend, isFalse);
      expect(session().availability.readOnly, isTrue);
      expect(gateway.events$, isEmpty);
    });
  });

  group('reconnect', () {
    test('after a drop it fetches only what was missed, then resumes',
        () async {
      gateway = FakeGateway(initial: [serverMsg(1, 'first')]);
      container = makeContainer(gateway);
      open();
      await settle();

      // Connection drops; two messages arrive while the app is offline.
      gateway.stored
        ..add(serverMsg(2, 'second'))
        ..add(serverMsg(3, 'third'));
      gateway.dropSocket();
      await settle();
      expect(session().connection, ChatConnection.reconnecting);

      // The backoff timer's first wait is one second.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await settle();

      expect(session().messages.map((m) => m.body), [
        'first',
        'second',
        'third',
      ]);
      // It asked only for what followed message 1.
      expect(gateway.fetchAfter.last, 1);
      expect(session().connection, ChatConnection.live);
      expect(gateway.events$, hasLength(2));
    });

    test('refresh() on resume pulls newer messages without duplicating',
        () async {
      gateway = FakeGateway(initial: [serverMsg(1, 'a')]);
      container = makeContainer(gateway);
      open();
      await settle();

      gateway.stored.add(serverMsg(2, 'b'));
      await controller().refresh();
      await controller().refresh();

      expect(session().messages.map((m) => m.body), ['a', 'b']);
    });
  });

  group('reassignment', () {
    test('history is kept and new messages simply go on the same thread',
        () async {
      gateway = FakeGateway(
        initial: [serverMsg(1, 'to rider one', mine: true)],
      );
      container = makeContainer(gateway);
      open();
      await settle();

      // Backend swaps the rider; the customer's thread is unchanged.
      gateway.availability = live;
      await controller().send('to rider two');

      expect(session().messages.map((m) => m.body), [
        'to rider one',
        'to rider two',
      ]);
      expect(session().messages.every((m) => m.fromMe), isTrue);
    });
  });
}
