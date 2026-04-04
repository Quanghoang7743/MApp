import 'package:flutter/material.dart';

import '../../../models/message_item.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isSending,
  });

  final MessageItem message;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: message.isMe
                    ? const Color(0xFF2A89FF)
                    : (isDark
                          ? const Color(0xFF2A2E37)
                          : const Color(0xFFEDEFF4)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(message.isMe ? 22 : 8),
                  bottomRight: Radius.circular(message.isMe ? 8 : 22),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: message.isMe ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.time,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: message.isMe
                            ? Colors.white.withValues(alpha: 0.78)
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isSending && message.isMe) ...[
            const SizedBox(height: 4),
            Text(
              'đang gửi..',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: message.isMe
                    ? Colors.black.withValues(alpha: 0.78)
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
