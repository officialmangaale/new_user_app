/// Customer <-> rider chat for one delivery.
///
/// The backend (rider-service) is the authority on who may talk and when; this
/// file only models what it says and what the screen has done locally.
library;

/// Where a message is in its trip to the server.
enum ChatDelivery { sending, sent, failed }

class ChatMessage {
  const ChatMessage({
    required this.clientMessageId,
    required this.body,
    required this.fromMe,
    required this.createdAt,
    this.messageId,
    this.delivery = ChatDelivery.sent,
    this.read = false,
  });

  /// The stable key. It exists before the server has seen the message, which
  /// is what lets a retry be recognised as the same message.
  final String clientMessageId;
  final String body;
  final bool fromMe;
  final DateTime createdAt;

  /// Server id, null until the server has stored it.
  final int? messageId;
  final ChatDelivery delivery;

  /// The other party has read this message.
  final bool read;

  bool get isPending => delivery != ChatDelivery.sent;

  ChatMessage copyWith({
    int? messageId,
    ChatDelivery? delivery,
    DateTime? createdAt,
    bool? read,
  }) => ChatMessage(
    clientMessageId: clientMessageId,
    body: body,
    fromMe: fromMe,
    createdAt: createdAt ?? this.createdAt,
    messageId: messageId ?? this.messageId,
    delivery: delivery ?? this.delivery,
    read: read ?? this.read,
  );

  /// Parses a server message. [fromMe] is decided by the sender's role, which
  /// the server derived from the order — the customer app only ever speaks as
  /// the customer.
  static ChatMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final body = raw['body'];
    if (id is! num || body is! String) return null;
    final created = DateTime.tryParse('${raw['created_at'] ?? ''}');
    final clientId = '${raw['client_message_id'] ?? ''}'.trim();
    return ChatMessage(
      clientMessageId: clientId.isEmpty ? 'server-${id.toInt()}' : clientId,
      body: body,
      fromMe: raw['sender_role'] == 'customer',
      createdAt: (created ?? DateTime.now()).toLocal(),
      messageId: id.toInt(),
      read: raw['read'] == true,
    );
  }
}

/// What the server says about the conversation right now.
class ChatAvailability {
  const ChatAvailability({
    this.canSend = false,
    this.readOnly = false,
    this.reason = '',
    this.riderAssigned = false,
    this.unreadCount = 0,
  });

  /// The server will accept a message from this customer right now.
  final bool canSend;

  /// History is visible but nothing more can be sent (delivery finished).
  final bool readOnly;

  /// Server reason code when [canSend] is false: `no_rider`, `closed`, ...
  final String reason;
  final bool riderAssigned;
  final int unreadCount;

  static const unknown = ChatAvailability();

  factory ChatAvailability.fromJson(Object? raw) {
    if (raw is! Map) return unknown;
    final unread = raw['unread_count'];
    return ChatAvailability(
      canSend: raw['can_send'] == true,
      readOnly: raw['read_only'] == true,
      reason: '${raw['reason'] ?? ''}',
      riderAssigned: raw['rider_assigned'] == true,
      unreadCount: unread is num ? unread.toInt() : 0,
    );
  }

  /// Message shown instead of the composer.
  String get closedMessage {
    if (readOnly || reason == 'closed') {
      return 'This delivery has ended, so chat is closed.';
    }
    if (reason == 'no_rider' || !riderAssigned) {
      return 'Chat opens once a delivery partner is assigned.';
    }
    return 'Chat is unavailable right now.';
  }
}

/// Merges server messages into the local list.
///
/// * A server message replaces the local pending one with the same
///   `clientMessageId` (the optimistic message becoming real), so nothing is
///   shown twice.
/// * Result is ordered by server id where known, and local pending messages
///   stay at the end in the order they were typed.
List<ChatMessage> mergeChatMessages(
  List<ChatMessage> current,
  Iterable<ChatMessage> incoming,
) {
  final byClient = <String, ChatMessage>{
    for (final m in current) m.clientMessageId: m,
  };
  for (final m in incoming) {
    final existing = byClient[m.clientMessageId];
    byClient[m.clientMessageId] = existing == null
        ? m
        : m.copyWith(read: m.read || existing.read);
  }
  final confirmed = <ChatMessage>[];
  final pending = <ChatMessage>[];
  for (final m in byClient.values) {
    (m.messageId == null ? pending : confirmed).add(m);
  }
  confirmed.sort((a, b) => a.messageId!.compareTo(b.messageId!));
  return [...confirmed, ...pending];
}

/// Highest server id in [messages], or 0. Used as the `after` cursor so a
/// reconnect asks only for what it missed.
int lastServerMessageId(Iterable<ChatMessage> messages) {
  var last = 0;
  for (final m in messages) {
    final id = m.messageId;
    if (id != null && id > last) last = id;
  }
  return last;
}

/// Whether the tracking screen's Chat button is active: a rider is assigned
/// and the order has not reached a terminal status. The backend re-checks
/// every send, so this is presentation only.
bool chatButtonEnabled({required bool riderAssigned, required String status}) {
  if (!riderAssigned) return false;
  const closed = {'delivered', 'completed', 'cancelled', 'canceled', 'rejected'};
  return !closed.contains(status.trim().toLowerCase());
}
