import 'package:flutter/material.dart';

import '../models/chat_item.dart';
import '../models/message_item.dart';
import 'widgets/input_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({
    super.key,
    required this.onBack,
    required this.contact,
    required this.messages,
  });

  final VoidCallback onBack;
  final ChatItem contact;
  final List<MessageItem> messages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF101216), const Color(0xFF161A21)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF5F7FB)],
        ),
      ),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isDark
                              ? const Color(0xFF2B313A)
                              : const Color(0xFFE7EBF2),
                          child: Text(
                            contact.initials,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(contact.name, style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              itemCount: messages.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: TypingIndicator(),
                  );
                }

                final message = messages[messages.length - index];
                return MessageBubble(message: message);
              },
            ),
          ),
          InputBar(isDark: isDark),
        ],
      ),
    );
  }
}
