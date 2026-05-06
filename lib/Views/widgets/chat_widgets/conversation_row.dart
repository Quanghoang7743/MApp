import 'package:flutter/material.dart';

import '../../../models/chat_item.dart';

class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.chat,
    required this.onTap,
    this.isSelected = false,
  });

  final ChatItem chat;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: isDark
              ? const Color(
                  0xFF1B1F27,
                ).withValues(alpha: isSelected ? 0.9 : 0.66)
              : (isSelected ? const Color(0xFFEFF4FF) : Colors.white),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.04),
              blurRadius: 22,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: isDark
                  ? const Color(0xFF2A303A)
                  : const Color(0xFFE8ECF4),
              child: Text(
                chat.initials,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chat.name, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 3),
                  Text(
                    chat.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              chat.time,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
