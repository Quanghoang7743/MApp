import 'package:flutter/material.dart';

import '../../../models/chat_item.dart';

class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.chat,
    required this.onTap,
    this.isSelected = false,
    this.compact = false,
  });

  final ChatItem chat;
  final VoidCallback onTap;
  final bool isSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 16,
            vertical: compact ? 14 : 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: isSelected
                ? const Color(0xFFF1EEFF)
                : Colors.white.withValues(alpha: 0.82),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x120E1242),
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _AvatarBubble(chat: chat, size: compact ? 56 : 60),
                  const Positioned(
                    right: 2,
                    bottom: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF5CDD73),
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(width: 12, height: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 16 : 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D2148),
                            ),
                          ),
                        ),
                        if (chat.isPinned) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.push_pin,
                            size: 18,
                            color: Color(0xFF6559FF),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.message.isEmpty
                          ? (chat.isTyping
                                ? 'đang nhập...'
                                : 'Chưa có tin nhắn')
                          : chat.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        color: const Color(0xFF7E849F),
                        fontWeight: chat.isTyping
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    chat.time,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      color: const Color(0xFF8488A0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (chat.unreadCount > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 28),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF5D5BFF), Color(0xFF7A66FF)],
                        ),
                      ),
                      child: Text(
                        '${chat.unreadCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 28),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.chat, required this.size});

  final ChatItem chat;
  final double size;

  Color _fallbackColor() {
    final palette = <Color>[
      const Color(0xFFE1EFFF),
      const Color(0xFFEADFFF),
      const Color(0xFFF6DCEF),
      const Color(0xFFDDF8F0),
    ];
    final hash = chat.name.isEmpty ? 0 : chat.name.codeUnitAt(0);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = chat.avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _fallbackColor(),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl.trim().isNotEmpty
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _AvatarText(chat: chat),
            )
          : _AvatarText(chat: chat),
    );
  }
}

class _AvatarText extends StatelessWidget {
  const _AvatarText({required this.chat});

  final ChatItem chat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        chat.initials,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: Color(0xFF5C55B8),
        ),
      ),
    );
  }
}
