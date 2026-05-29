import 'package:flutter/material.dart';

import 'conversation_avatar.dart';

class ConversationHeader extends StatelessWidget {
  const ConversationHeader({
    super.key,
    required this.contactName,
    required this.avatarUrl,
    required this.initials,
    required this.embedded,
    required this.onBack,
    required this.onAction,
  });

  final String contactName;
  final String? avatarUrl;
  final String initials;
  final bool embedded;
  final VoidCallback onBack;

  /// Called when an action button is tapped. Receives a label string
  /// (e.g. 'Tìm kiếm', 'Gọi thoại', 'Gọi video', 'Tuỳ chọn').
  final void Function(String label) onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 22,
                color: Color(0xFF1C2146),
              ),
            ),
            ConversationAvatar(
              avatarUrl: avatarUrl,
              initials: initials,
              size: embedded ? 52 : 54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contactName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D45),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Đang hoạt động',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8187A4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                if (embedded)
                  IconButton(
                    onPressed: () => onAction('Tìm kiếm'),
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF171C44),
                      size: 28,
                    ),
                  ),
                IconButton(
                  onPressed: () => onAction('Gọi thoại'),
                  icon: const Icon(
                    Icons.call_outlined,
                    color: Color(0xFF171C44),
                    size: 28,
                  ),
                ),
                IconButton(
                  onPressed: () => onAction('Gọi video'),
                  icon: const Icon(
                    Icons.videocam_outlined,
                    color: Color(0xFF171C44),
                    size: 30,
                  ),
                ),
                IconButton(
                  onPressed: () => onAction('Tuỳ chọn'),
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF171C44),
                    size: 28,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
