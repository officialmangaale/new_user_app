import 'dart:async';

import 'package:turquoise_delivery/core/services/api_exception.dart';
import 'package:turquoise_delivery/features/chat/data/chat_repository.dart';
import 'package:turquoise_delivery/features/chat/domain/chat_models.dart';

ChatMessage serverMsg(
  int id,
  String body, {
  bool mine = false,
  String? clientId,
}) => ChatMessage(
  clientMessageId: clientId ?? 'server-$id',
  body: body,
  fromMe: mine,
  createdAt: DateTime(2026, 10, 15, 12, id),
  messageId: id,
);

const live = ChatAvailability(canSend: true, riderAssigned: true);
const ended = ChatAvailability(
  readOnly: true,
  reason: 'closed',
  riderAssigned: true,
);

/// In-memory stand-in for rider-service. Like the real one, it stores a send
/// once per client id and replays the stored message on a repeat.
class FakeGateway implements ChatGateway {
  FakeGateway({this.availability = live, List<ChatMessage>? initial})
    : stored = [...?initial];

  ChatAvailability availability;
  final List<ChatMessage> stored;
  final events$ = <StreamController<ChatMessage>>[];

  int fetchCalls = 0;
  final fetchAfter = <int>[];
  int sendCalls = 0;
  final sentClientIds = <String>[];
  final readUpTo = <int>[];

  /// Next [failures] sends throw this.
  ApiException? failSendWith;
  int failures = 0;

  /// The next send is stored by the server but its response is lost.
  bool storeThenLoseResponse = false;

  /// Next fetches throw this.
  ApiException? failFetchWith;

  @override
  Future<ChatSnapshot> fetch(String orderId, {int afterId = 0}) async {
    fetchCalls++;
    fetchAfter.add(afterId);
    if (failFetchWith != null) throw failFetchWith!;
    return ChatSnapshot(
      messages: stored.where((m) => m.messageId! > afterId).toList(),
      availability: availability,
    );
  }

  @override
  Future<ChatAvailability> summary(String orderId) async => availability;

  @override
  Future<ChatSnapshot> send(
    String orderId, {
    required String body,
    required String clientMessageId,
  }) async {
    sendCalls++;
    sentClientIds.add(clientMessageId);
    if (failures > 0) {
      failures--;
      throw failSendWith!;
    }
    final existing = stored.where((m) => m.clientMessageId == clientMessageId);
    final message = existing.isNotEmpty
        ? existing.first
        : serverMsg(
            stored.length + 100,
            body,
            mine: true,
            clientId: clientMessageId,
          );
    if (existing.isEmpty) stored.add(message);
    if (storeThenLoseResponse) {
      storeThenLoseResponse = false;
      throw const ApiException(statusCode: 0, message: 'response lost');
    }
    return ChatSnapshot(messages: [message], availability: availability);
  }

  @override
  Future<void> markRead(String orderId, int upToId) async =>
      readUpTo.add(upToId);

  @override
  Stream<ChatMessage> events(String orderId, String? token) {
    final controller = StreamController<ChatMessage>();
    events$.add(controller);
    return controller.stream;
  }

  /// A message the rider sent.
  void riderSays(int id, String body) {
    final message = serverMsg(id, body);
    stored.add(message);
    if (events$.isNotEmpty && !events$.last.isClosed) {
      events$.last.add(message);
    }
  }

  void dropSocket() => events$.last.close();
}

