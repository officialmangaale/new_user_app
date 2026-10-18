import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/api_exception.dart';
import '../domain/chat_models.dart';

/// One page of conversation plus the server's current verdict on it.
class ChatSnapshot {
  const ChatSnapshot({required this.messages, required this.availability});
  final List<ChatMessage> messages;
  final ChatAvailability availability;
}

/// The chat API as the controller sees it. An interface so the controller can
/// be exercised without a network.
abstract class ChatGateway {
  /// Messages after [afterId] (0 for all), oldest first.
  Future<ChatSnapshot> fetch(String orderId, {int afterId = 0});

  /// State and unread count only — cheap enough for the tracking screen to
  /// poll for the Chat badge.
  Future<ChatAvailability> summary(String orderId);

  /// Idempotent on [clientMessageId]: resending after a lost response returns
  /// the original message, it does not create a second one.
  Future<ChatSnapshot> send(
    String orderId, {
    required String body,
    required String clientMessageId,
  });

  Future<void> markRead(String orderId, int upToId);

  /// Live events for the conversation. The stream ends or errors when the
  /// connection drops; closing the subscription closes the socket.
  Stream<ChatMessage> events(String orderId, String? token);
}

class RiderServiceChatGateway implements ChatGateway {
  RiderServiceChatGateway(this._api);
  final ApiClient _api;

  Dio get _dio => _api.rider;

  String _base(String orderId) => '/api/v1/delivery/orders/$orderId/chat';

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  @override
  Future<ChatSnapshot> fetch(String orderId, {int afterId = 0}) => _guard(
    () async {
      final response = await _dio.get<Object?>(
        '${_base(orderId)}/messages',
        queryParameters: {if (afterId > 0) 'after': afterId},
      );
      return _snapshot(response.data);
    },
  );

  @override
  Future<ChatAvailability> summary(String orderId) => _guard(() async {
    final response = await _dio.get<Object?>(_base(orderId));
    return ChatAvailability.fromJson(unwrapApiObject(response.data)['state']);
  });

  @override
  Future<ChatSnapshot> send(
    String orderId, {
    required String body,
    required String clientMessageId,
  }) => _guard(() async {
    final response = await _dio.post<Object?>(
      '${_base(orderId)}/messages',
      data: {'body': body, 'client_message_id': clientMessageId},
    );
    final data = unwrapApiObject(response.data);
    final message = ChatMessage.fromJson(data['message']);
    return ChatSnapshot(
      messages: message == null ? const [] : [message],
      availability: ChatAvailability.fromJson(data['state']),
    );
  });

  @override
  Future<void> markRead(String orderId, int upToId) => _guard(() async {
    await _dio.post<Object?>(
      '${_base(orderId)}/read',
      data: {'up_to_id': upToId},
    );
  });

  ChatSnapshot _snapshot(Object? raw) {
    final data = unwrapApiObject(raw);
    final list = data['messages'];
    final messages = <ChatMessage>[
      if (list is List)
        for (final entry in list) ?ChatMessage.fromJson(entry),
    ];
    return ChatSnapshot(
      messages: messages,
      availability: ChatAvailability.fromJson(data['state']),
    );
  }

  @override
  Stream<ChatMessage> events(String orderId, String? token) {
    late StreamController<ChatMessage> controller;
    WebSocketChannel? channel;
    StreamSubscription<dynamic>? subscription;

    Future<void> close() async {
      await subscription?.cancel();
      subscription = null;
      await channel?.sink.close();
      channel = null;
    }

    controller = StreamController<ChatMessage>(
      onListen: () {
        if (token == null || token.isEmpty) {
          controller.addError(
            const ApiException(statusCode: 401, message: 'Not signed in.'),
          );
          controller.close();
          return;
        }
        final base = AppConfig.riderServiceWsBaseUrl.replaceFirst('http', 'ws');
        final uri = Uri.parse(
          '$base/ws/chat/orders/$orderId',
        ).replace(queryParameters: {'token': token});
        try {
          channel = WebSocketChannel.connect(uri);
        } catch (error) {
          controller.addError(error);
          controller.close();
          return;
        }
        subscription = channel!.stream.listen(
          (frame) {
            final message = _parseEvent(frame);
            if (message != null) controller.add(message);
          },
          onError: (Object error) {
            controller.addError(error);
            controller.close();
          },
          onDone: () => controller.close(),
        );
      },
      onCancel: close,
    );
    return controller.stream;
  }

  static ChatMessage? _parseEvent(dynamic frame) {
    try {
      final decoded = frame is String ? jsonDecode(frame) : frame;
      if (decoded is! Map) return null;
      if ('${decoded['type']}' != 'chat.message') return null;
      return ChatMessage.fromJson(decoded['data']);
    } catch (_) {
      return null;
    }
  }
}
