import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/features/chat/domain/chat_models.dart';

void main() {
  group('server payload', () {
    test('parses a message and decides ownership from the sender role', () {
      final mine = ChatMessage.fromJson({
        'id': 12,
        'order_id': 16303,
        'sender_role': 'customer',
        'body': 'Gate 2',
        'client_message_id': 'c-abc-12345',
        'created_at': '2026-10-15T10:00:00Z',
        'read': true,
      })!;
      expect(mine.fromMe, isTrue);
      expect(mine.messageId, 12);
      expect(mine.clientMessageId, 'c-abc-12345');
      expect(mine.read, isTrue);

      final theirs = ChatMessage.fromJson({
        'id': 13,
        'sender_role': 'rider',
        'body': 'Coming',
        'created_at': '2026-10-15T10:01:00Z',
      })!;
      expect(theirs.fromMe, isFalse);
      // A message without a client id still gets a stable key.
      expect(theirs.clientMessageId, 'server-13');
    });

    test('rejects malformed messages instead of showing blanks', () {
      expect(ChatMessage.fromJson(null), isNull);
      expect(ChatMessage.fromJson({'id': 1}), isNull);
      expect(ChatMessage.fromJson({'body': 'x'}), isNull);
    });

    test('availability reads the server state', () {
      final state = ChatAvailability.fromJson({
        'can_send': false,
        'read_only': true,
        'reason': 'closed',
        'rider_assigned': true,
        'unread_count': 3,
      });
      expect(state.canSend, isFalse);
      expect(state.readOnly, isTrue);
      expect(state.unreadCount, 3);
      expect(state.closedMessage, contains('ended'));
      expect(ChatAvailability.fromJson(null).canSend, isFalse);
    });

    test('no-rider state explains when chat will open', () {
      const state = ChatAvailability(reason: 'no_rider');
      expect(state.closedMessage, contains('assigned'));
    });
  });

  group('merge', () {
    ChatMessage server(int id, String body, {String? client}) => ChatMessage(
      clientMessageId: client ?? 'server-$id',
      body: body,
      fromMe: true,
      createdAt: DateTime(2026),
      messageId: id,
    );

    test('a server copy replaces the optimistic one with the same client id',
        () {
      final pending = ChatMessage(
        clientMessageId: 'c-1',
        body: 'hi',
        fromMe: true,
        createdAt: DateTime(2026),
        delivery: ChatDelivery.sending,
      );
      final merged = mergeChatMessages(
        [pending],
        [server(5, 'hi', client: 'c-1')],
      );
      expect(merged, hasLength(1));
      expect(merged.single.messageId, 5);
      expect(merged.single.delivery, ChatDelivery.sent);
    });

    test('orders by server id and keeps unsent messages last', () {
      final pending = ChatMessage(
        clientMessageId: 'c-9',
        body: 'typing',
        fromMe: true,
        createdAt: DateTime(2026),
        delivery: ChatDelivery.failed,
      );
      final merged = mergeChatMessages(
        [pending, server(3, 'three')],
        [server(1, 'one'), server(2, 'two')],
      );
      expect(merged.map((m) => m.body), ['one', 'two', 'three', 'typing']);
    });

    test('lastServerMessageId ignores unsent messages', () {
      final pending = ChatMessage(
        clientMessageId: 'c-9',
        body: 'x',
        fromMe: true,
        createdAt: DateTime(2026),
      );
      expect(lastServerMessageId([pending]), 0);
      expect(lastServerMessageId([pending, server(8, 'a'), server(4, 'b')]), 8);
    });
  });

  group('chat button', () {
    test('needs an assigned rider', () {
      expect(chatButtonEnabled(riderAssigned: false, status: 'preparing'),
          isFalse);
    });

    test('is active while the delivery is in progress', () {
      for (final status in [
        'rider_assigned',
        'picked_up',
        'out_for_delivery',
        'on_the_way',
        'preparing',
      ]) {
        expect(chatButtonEnabled(riderAssigned: true, status: status), isTrue,
            reason: status);
      }
    });

    test('closes once the order has ended', () {
      for (final status in ['delivered', 'completed', 'cancelled', 'rejected']) {
        expect(chatButtonEnabled(riderAssigned: true, status: status), isFalse,
            reason: status);
      }
    });
  });
}
