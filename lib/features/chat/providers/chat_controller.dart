import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/di_providers.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/api_exception.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

final chatGatewayProvider = Provider<ChatGateway>(
  (ref) => RiderServiceChatGateway(ref.watch(apiClientProvider)),
);

/// Separate from the gateway so tests can supply a token without storage.
final chatTokenReaderProvider = Provider<TokenReader>(
  (ref) => ref.read(authStorageProvider).readToken,
);

/// Unread count for the Chat button on the tracking screen. Refreshed by
/// invalidating it (the tracking screen already does so on every refresh), so
/// it adds no timer of its own. Any failure reads as "nothing unread": the
/// badge is a hint, never a reason to show an error on the tracking screen.
final chatSummaryProvider = FutureProvider.autoDispose
    .family<ChatAvailability, String>((ref, orderId) async {
      try {
        return await ref.watch(chatGatewayProvider).summary(orderId);
      } on ApiException {
        return ChatAvailability.unknown;
      }
    });

enum ChatConnection { connecting, live, reconnecting, closed }

class ChatSession {
  const ChatSession({
    this.messages = const [],
    this.availability = ChatAvailability.unknown,
    this.loading = true,
    this.loadError,
    this.connection = ChatConnection.connecting,
    this.notice,
  });

  final List<ChatMessage> messages;
  final ChatAvailability availability;

  /// First load in progress and nothing to show yet.
  final bool loading;

  /// First load failed; the screen offers Retry.
  final String? loadError;
  final ChatConnection connection;

  /// Transient, user-facing explanation for the last failed action.
  final String? notice;

  ChatSession copyWith({
    List<ChatMessage>? messages,
    ChatAvailability? availability,
    bool? loading,
    String? loadError,
    bool clearLoadError = false,
    ChatConnection? connection,
    String? notice,
    bool clearNotice = false,
  }) => ChatSession(
    messages: messages ?? this.messages,
    availability: availability ?? this.availability,
    loading: loading ?? this.loading,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
    connection: connection ?? this.connection,
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

const chatMaxBodyLength = 500;

final chatControllerProvider = NotifierProvider.autoDispose
    .family<ChatController, ChatSession, String>(ChatController.new);

class ChatController extends Notifier<ChatSession> {
  ChatController(this.orderId);
  final String orderId;

  StreamSubscription<ChatMessage>? _events;
  Timer? _reconnectTimer;
  int _attempt = 0;
  DateTime? _liveSince;
  int _counter = 0;
  bool _disposed = false;
  bool _fetching = false;
  int _lastMarkedRead = 0;

  ChatGateway get _gateway => ref.read(chatGatewayProvider);

  @override
  ChatSession build() {
    ref.onDispose(() {
      _disposed = true;
      _reconnectTimer?.cancel();
      _events?.cancel();
    });
    // Defer so build() returns its initial state before any state change.
    Future.microtask(_initialLoad);
    return const ChatSession();
  }

  Future<void> _initialLoad() async {
    if (_disposed) return;
    state = state.copyWith(loading: true, clearLoadError: true);
    try {
      final snapshot = await _gateway.fetch(orderId);
      if (_disposed) return;
      state = state.copyWith(
        messages: mergeChatMessages(state.messages, snapshot.messages),
        availability: snapshot.availability,
        loading: false,
      );
      _markReadIfNeeded();
      _connect();
    } on ApiException catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        loadError: _describe(error),
        connection: ChatConnection.closed,
      );
    }
  }

  /// User-driven retry of the first load.
  Future<void> reload() => _initialLoad();

  Future<void> _connect() async {
    if (_disposed) return;
    // A finished delivery has nothing more to say; no socket to keep open.
    if (state.availability.readOnly || !state.availability.riderAssigned) {
      state = state.copyWith(connection: ChatConnection.closed);
      return;
    }
    await _events?.cancel();
    final token = await ref.read(chatTokenReaderProvider)();
    if (_disposed) return;
    state = state.copyWith(
      connection: _attempt == 0
          ? ChatConnection.connecting
          : ChatConnection.reconnecting,
    );
    _events = _gateway
        .events(orderId, token)
        .listen(
          _onIncoming,
          onError: (_) => _onDropped(),
          onDone: _onDropped,
          cancelOnError: true,
        );
    // A socket that has been accepted is as good as live; the first frame is
    // not guaranteed to arrive, so do not wait for one. The backoff is NOT
    // reset here: a server that accepts and immediately drops (or refuses)
    // would otherwise be retried every second forever. It resets once the
    // socket has stayed up (see _onDropped) or a message arrives.
    _liveSince = DateTime.now();
    state = state.copyWith(connection: ChatConnection.live);
  }

  void _onIncoming(ChatMessage message) {
    if (_disposed) return;
    _attempt = 0;
    state = state.copyWith(
      messages: mergeChatMessages(state.messages, [message]),
    );
    if (!message.fromMe) _markReadIfNeeded();
  }

  void _onDropped() {
    if (_disposed) return;
    state = state.copyWith(connection: ChatConnection.reconnecting);
    final liveSince = _liveSince;
    if (liveSince != null &&
        DateTime.now().difference(liveSince) > const Duration(seconds: 20)) {
      _attempt = 0; // it was healthy for a while; start the backoff over
    }
    _liveSince = null;
    _reconnectTimer?.cancel();
    // 1s, 2s, 4s ... capped at 15s.
    final seconds = (1 << _attempt.clamp(0, 4)).clamp(1, 15);
    _attempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      if (_disposed) return;
      // Catch up on whatever arrived while disconnected, then go live again.
      await refresh();
      await _connect();
    });
  }

  /// Fetches anything newer than what is already shown. Called on reconnect
  /// and when the app returns to the foreground. Never throws.
  Future<void> refresh() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    try {
      final snapshot = await _gateway.fetch(
        orderId,
        afterId: lastServerMessageId(state.messages),
      );
      if (_disposed) return;
      state = state.copyWith(
        messages: mergeChatMessages(state.messages, snapshot.messages),
        availability: snapshot.availability,
        loading: false,
        clearLoadError: true,
      );
      _markReadIfNeeded();
    } on ApiException {
      // Still offline; the reconnect timer or the next resume tries again.
    } finally {
      _fetching = false;
    }
  }

  void _markReadIfNeeded() {
    final last = lastServerMessageId(state.messages.where((m) => !m.fromMe));
    // Nothing new from the rider since the last time this was reported.
    if (last == 0 || last <= _lastMarkedRead) return;
    _lastMarkedRead = last;
    unawaited(
      _gateway.markRead(orderId, last).then<void>((_) {}).catchError((_) {}),
    );
    final a = state.availability;
    if (a.unreadCount != 0) {
      state = state.copyWith(
        availability: ChatAvailability(
          canSend: a.canSend,
          readOnly: a.readOnly,
          reason: a.reason,
          riderAssigned: a.riderAssigned,
        ),
      );
    }
    // The tracking screen's badge clears as soon as this is read.
    ref.invalidate(chatSummaryProvider(orderId));
  }

  String _newClientId() {
    _counter++;
    return 'c${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }

  /// Sends [text]. The message appears immediately as "sending" and becomes
  /// "sent" or "failed"; a failed one is resent with [retry].
  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || body.length > chatMaxBodyLength) return;
    if (!state.availability.canSend) return;
    final pending = ChatMessage(
      clientMessageId: _newClientId(),
      body: body,
      fromMe: true,
      createdAt: DateTime.now(),
      delivery: ChatDelivery.sending,
    );
    state = state.copyWith(
      messages: [...state.messages, pending],
      clearNotice: true,
    );
    await _deliver(pending);
  }

  /// Resends a failed message with the same client id, so a message that did
  /// reach the server before the response was lost is not duplicated.
  Future<void> retry(String clientMessageId) async {
    final index = state.messages.indexWhere(
      (m) => m.clientMessageId == clientMessageId,
    );
    if (index < 0) return;
    final message = state.messages[index];
    if (message.delivery != ChatDelivery.failed) return;
    _replace(message.copyWith(delivery: ChatDelivery.sending));
    state = state.copyWith(clearNotice: true);
    await _deliver(message);
  }

  Future<void> _deliver(ChatMessage pending) async {
    try {
      final snapshot = await _gateway.send(
        orderId,
        body: pending.body,
        clientMessageId: pending.clientMessageId,
      );
      if (_disposed) return;
      final stored = snapshot.messages.isEmpty ? null : snapshot.messages.first;
      state = state.copyWith(
        messages: mergeChatMessages(
          state.messages,
          stored == null
              ? [pending.copyWith(delivery: ChatDelivery.sent)]
              : [stored],
        ),
        availability: snapshot.availability,
      );
    } on ApiException catch (error) {
      if (_disposed) return;
      _replace(pending.copyWith(delivery: ChatDelivery.failed));
      state = state.copyWith(notice: _describe(error));
      // The server saying chat is closed or has no rider changes what the
      // composer should offer; refresh so it does.
      if (error.statusCode == 409 || error.statusCode == 403) {
        unawaited(refresh());
      }
    }
  }

  void _replace(ChatMessage message) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          m.clientMessageId == message.clientMessageId ? message : m,
      ],
    );
  }

  String _describe(ApiException error) {
    if (error.isNetworkError) {
      return 'No connection. Check your internet and try again.';
    }
    switch (error.code) {
      case 'CHAT_NO_RIDER':
        return 'No delivery partner is assigned yet.';
      case 'CHAT_CLOSED':
        return 'This delivery has ended, so chat is closed.';
      case 'CHAT_RATE_LIMITED':
        return 'You are sending messages too quickly. Wait a moment.';
      case 'CHAT_FORBIDDEN':
      case 'CHAT_NOT_FOUND':
        return 'Chat is not available for this order.';
    }
    if (error.statusCode == 429) {
      return 'You are sending messages too quickly. Wait a moment.';
    }
    return 'Could not reach chat. Please try again.';
  }
}
