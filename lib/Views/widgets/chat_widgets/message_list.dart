import 'package:flutter/material.dart';

import '../../../models/message_item.dart';
import 'conversation_helpers.dart';
import 'message_bubble.dart';

class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.embedded,
    required this.sending,
    required this.lastOwnMessageId,
    required this.peerInitials,
    required this.peerAvatarUrl,
    required this.onLongPressMessage,
    required this.onRetryMedia,
    required this.onRemoveMedia,
  });

  final List<MessageItem> messages;
  final ScrollController scrollController;
  final bool embedded;
  final bool sending;
  final String lastOwnMessageId;
  final String peerInitials;
  final String? peerAvatarUrl;
  final void Function(MessageItem message, Offset position) onLongPressMessage;
  final void Function(MessageItem message) onRetryMedia;
  final void Function(MessageItem message) onRemoveMedia;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        embedded ? 24 : 16,
        16,
        embedded ? 24 : 16,
        16,
      ),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildDateBadge();
        }

        final message = messages[index - 1];
        final displayMessage = message.copyWith(
          time: formatTime(message.time),
        );
        final isSendingMessage =
            sending && message.id.startsWith('temp-');

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: MessageBubble(
            message: displayMessage,
            isSending: isSendingMessage,
            peerInitials: peerInitials,
            peerAvatarUrl: peerAvatarUrl,
            showSeen:
                lastOwnMessageId.isNotEmpty &&
                lastOwnMessageId == message.id,
            onLongPressStart: (position) {
              onLongPressMessage(message, position);
            },
            onRetryMedia: message.mediaSendState == MediaSendState.failed
                ? () => onRetryMedia(message)
                : null,
            onRemoveMedia: message.mediaSendState == MediaSendState.failed
                ? () => onRemoveMedia(message)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildDateBadge() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EEF9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Hôm nay',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E7291),
            ),
          ),
        ),
      ),
    );
  }
}
