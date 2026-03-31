import 'package:flutter/material.dart';

import '../models/chat_item.dart';
import 'widgets/conversation_row.dart';
import 'widgets/glass_container.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({
    super.key,
    required this.chats,
    required this.onChatTap,
    required this.onToggleTheme,
    required this.darkModeEnabled,
  });

  final List<ChatItem> chats;
  final VoidCallback onChatTap;
  final VoidCallback onToggleTheme;
  final bool darkModeEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF111318), const Color(0xFF171B21)]
                : [const Color(0xFFF9FAFC), const Color(0xFFF2F4F8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isDark
                          ? const Color(0xFF2A2F38)
                          : const Color(0xFFE9ECF3),
                      child: Text(
                        'QH',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('Messages', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onToggleTheme,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF20242B).withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Icon(
                          darkModeEnabled
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          size: 17,
                          color: isDark
                              ? const Color(0xFFE8EBF1)
                              : const Color(0xFF485064),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const GlassContainer(
                  borderRadius: 16,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Search'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: chats.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return ConversationRow(
                        chat: chats[index],
                        onTap: onChatTap,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
