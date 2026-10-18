import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/chat_models.dart';
import '../providers/chat_controller.dart';

/// Where "back" goes from the chat when there is nothing to pop (the screen
/// was opened from a notification or a link): the tracking screen of the same
/// order, which is where chat is entered from.
String chatBackFallback(String orderId) => '/tracking/$orderId';

/// Customer <-> rider chat for one order.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.orderId, this.riderName = '', super.key});

  final String orderId;
  final String riderName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the background: anything sent meanwhile arrives by push,
    // but the socket may have been dropped by the OS, so catch up now.
    if (state == AppLifecycleState.resumed) {
      ref.read(chatControllerProvider(widget.orderId).notifier).refresh();
    }
  }

  void _leave() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(chatBackFallback(widget.orderId));
    }
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await ref
        .read(chatControllerProvider(widget.orderId).notifier)
        .send(text);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(chatControllerProvider(widget.orderId));
    final title = widget.riderName.trim().isEmpty
        ? 'Delivery partner'
        : widget.riderName.trim();
    final canPop = GoRouter.maybeOf(context)?.canPop() ?? true;

    return PopScope(
      // With history, the system back pops normally. Without it the platform
      // would close the app, so it is routed to the tracking screen instead —
      // the same rule the visible arrow uses.
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('chat-back'),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _leave,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                'Order #${widget.orderId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (!session.loading && session.loadError == null)
                _ConnectionBanner(connection: session.connection),
              Expanded(child: _body(context, session)),
              if (session.notice != null)
                _NoticeBar(
                  message: session.notice!,
                  key: const Key('chat-notice'),
                ),
              _composer(session),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ChatSession session) {
    if (session.loading && session.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(key: Key('chat-loading')),
      );
    }
    if (session.loadError != null && session.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(session.loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('chat-load-retry'),
                onPressed: () => ref
                    .read(chatControllerProvider(widget.orderId).notifier)
                    .reload(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (session.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            session.availability.canSend
                ? 'Say hello to your delivery partner.'
                : session.availability.closedMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final reversed = session.messages.reversed.toList(growable: false);
    return ListView.builder(
      key: const Key('chat-list'),
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final message = reversed[index];
        return _Bubble(
          message: message,
          onRetry: () => ref
              .read(chatControllerProvider(widget.orderId).notifier)
              .retry(message.clientMessageId),
        );
      },
    );
  }

  Widget _composer(ChatSession session) {
    if (session.loading || session.loadError != null) {
      return const SizedBox.shrink();
    }
    final availability = session.availability;
    if (!availability.canSend) {
      return Container(
        key: const Key('chat-closed'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.disabledBackground,
        child: Text(
          availability.closedMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return Material(
      color: AppColors.surface,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('chat-input'),
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: chatMaxBodyLength,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Message your delivery partner',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('chat-send'),
              tooltip: 'Send message',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(48, 48),
              ),
              onPressed: _send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.connection});
  final ChatConnection connection;

  @override
  Widget build(BuildContext context) {
    if (connection != ChatConnection.reconnecting) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('chat-reconnecting'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: AppColors.warningLight,
      child: const Text(
        'Reconnecting…',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _NoticeBar extends StatelessWidget {
  const _NoticeBar({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    color: AppColors.errorLight,
    child: Text(message, style: const TextStyle(color: AppColors.error)),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onRetry});
  final ChatMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromMe;
    final failed = message.delivery == ChatDelivery.failed;
    final sending = message.delivery == ChatDelivery.sending;
    final bubbleColor = mine ? AppColors.primary : AppColors.surface;
    final textColor = mine ? AppColors.onPrimary : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Semantics(
            label: mine
                ? 'You said: ${message.body}'
                : 'Delivery partner said: ${message.body}',
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(16),
                  border: mine ? null : Border.all(color: AppColors.border),
                ),
                child: Text(
                  message.body,
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
              ),
            ),
          ),
          if (sending)
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 4),
              child: Text(
                'Sending…',
                key: Key('chat-sending'),
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            )
          else if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: InkWell(
                key: const Key('chat-retry'),
                onTap: onRetry,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    'Failed to send · Retry',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
