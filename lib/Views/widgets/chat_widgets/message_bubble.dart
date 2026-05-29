import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/message_item.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isSending,
    required this.peerInitials,
    this.peerAvatarUrl,
    this.showSeen = false,
    this.onLongPressStart,
    this.onRetryMedia,
    this.onRemoveMedia,
  });

  final MessageItem message;
  final bool isSending;
  final String peerInitials;
  final String? peerAvatarUrl;
  final bool showSeen;
  final ValueChanged<Offset>? onLongPressStart;
  final VoidCallback? onRetryMedia;
  final VoidCallback? onRemoveMedia;

  bool get _isFailedMedia => message.mediaSendState == MediaSendState.failed;

  bool get _isUploadingMedia =>
      message.mediaSendState == MediaSendState.sending || isSending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth >= 1100
        ? 460.0
        : screenWidth >= 800
        ? 390.0
        : 260.0;

    if (message.isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _BubbleBody(
              message: message,
              maxBubbleWidth: maxBubbleWidth,
              onLongPressStart: onLongPressStart,
              isMe: true,
            ),
            if (message.reactionSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ReactionSummaryWrap(
                items: message.reactionSummary,
                isMe: true,
              ),
            ],
            if (showSeen) ...[
              const SizedBox(height: 6),
              const Text(
                'Đã xem',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8B8FA5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_isUploadingMedia) ...[
              const SizedBox(height: 6),
              Text(
                'đang gửi...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: const Color(0xFF8B8FA5),
                ),
              ),
            ],
            if (_isFailedMedia) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Gửi ảnh thất bại',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: const Color(0xFFE25555),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: onRetryMedia,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Thử lại'),
                  ),
                  TextButton(
                    onPressed: onRemoveMedia,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Xóa'),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _IncomingAvatar(avatarUrl: peerAvatarUrl, initials: peerInitials),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BubbleBody(
                message: message,
                maxBubbleWidth: maxBubbleWidth,
                onLongPressStart: onLongPressStart,
                isMe: false,
              ),
              if (message.reactionSummary.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ReactionSummaryWrap(
                  items: message.reactionSummary,
                  isMe: false,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({
    required this.message,
    required this.maxBubbleWidth,
    required this.isMe,
    this.onLongPressStart,
  });

  final MessageItem message;
  final double maxBubbleWidth;
  final bool isMe;
  final ValueChanged<Offset>? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF5F62FF), Color(0xFF7A63FF)],
                )
              : null,
          color: isMe ? null : const Color(0xFFF2F3F8),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(26),
            topRight: const Radius.circular(26),
            bottomLeft: Radius.circular(isMe ? 26 : 8),
            bottomRight: Radius.circular(isMe ? 8 : 26),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.hasAttachments) ...[
              for (final attachment in message.attachments) ...[
                if (attachment.isImage)
                  _AttachmentPreview(
                    attachment: attachment,
                    isMe: isMe,
                  ),
                if (attachment != message.attachments.last)
                  const SizedBox(height: 10),
              ],
              if (message.text.trim().isNotEmpty) const SizedBox(height: 10),
            ],
            if (message.text.trim().isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF202343),
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.time,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.88)
                          : const Color(0xFF7F849C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.done_all_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onLongPressStart: onLongPressStart == null
          ? null
          : (details) => onLongPressStart!(details.globalPosition),
      child: bubble,
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachment,
    required this.isMe,
  });

  final MessageAttachmentItem attachment;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    if (image == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 160,
          maxWidth: 220,
          minHeight: 120,
          maxHeight: 240,
        ),
        color: isMe
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFE3E7F3),
        child: image,
      ),
    );
  }

  Widget? _buildImage() {
    final displayUrl = attachment.displayUrl;
    if (displayUrl == null || displayUrl.trim().isEmpty) {
      return null;
    }

    if (displayUrl.startsWith('http://') || displayUrl.startsWith('https://')) {
      return Image.network(
        displayUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _MediaPlaceholder(),
      );
    }

    return Image.file(
      File(displayUrl),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _MediaPlaceholder(),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 180,
      height: 140,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 34,
          color: Color(0xFF7F849C),
        ),
      ),
    );
  }
}

class _ReactionSummaryWrap extends StatelessWidget {
  const _ReactionSummaryWrap({
    required this.items,
    required this.isMe,
  });

  final List<MessageReactionSummary> items;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
      children: [
        for (final item in items)
          _ReactionChip(
            item: item,
            isMe: isMe,
          ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.item,
    required this.isMe,
  });

  final MessageReactionSummary item;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: item.reactedByMe
            ? const Color(0xFFECE8FF)
            : (isMe ? Colors.white : const Color(0xFFF3F4F9)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.reactedByMe
              ? const Color(0xFF705DFF)
              : const Color(0xFFD7DBE8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _emojiForReaction(item.reactionCode),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            '${item.count}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: item.reactedByMe
                  ? const Color(0xFF4F46D7)
                  : const Color(0xFF4A506D),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingAvatar extends StatelessWidget {
  const _IncomingAvatar({required this.avatarUrl, required this.initials});

  final String? avatarUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE8DEFF),
      ),
      child: avatarUrl != null && avatarUrl!.trim().isNotEmpty
          ? Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _FallbackAvatar(initials: initials),
            )
          : _FallbackAvatar(initials: initials),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6251CC),
        ),
      ),
    );
  }
}

String _emojiForReaction(String reactionCode) {
  switch (reactionCode) {
    case 'like':
      return '👍';
    case 'love':
      return '❤️';
    case 'laugh':
      return '😂';
    case 'wow':
      return '😮';
    case 'sad':
      return '😢';
    case 'angry':
      return '😡';
    default:
      return '🙂';
  }
}
