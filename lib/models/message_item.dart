class MessageItem {
  const MessageItem({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
  });

  final String id;
  final String text;
  final bool isMe;
  final String time;

  factory MessageItem.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final senderId = _resolveSenderId(json);
    final content = _resolveTextContent(json);
    final normalizedCurrentUserId = (currentUserId ?? '').trim();
    final normalizedSenderId = senderId.trim();

    return MessageItem(
      id: (json['id'] ?? '').toString(),
      text: content,
      isMe:
          normalizedCurrentUserId.isNotEmpty &&
          normalizedSenderId.isNotEmpty &&
          normalizedSenderId == normalizedCurrentUserId,
      time: (json['created_at'] ?? json['createdAt'] ?? json['time'] ?? '')
          .toString(),
    );
  }

  factory MessageItem.fromCacheJson(Map<String, dynamic> json) {
    return MessageItem(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      isMe: json['isMe'] == true,
      time: (json['time'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {'id': id, 'text': text, 'isMe': isMe, 'time': time};
  }

  static String _resolveTextContent(Map<String, dynamic> json) {
    final direct = json['text'] ?? json['message'] ?? json['body'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct;
    }

    final content = json['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content;
    }

    if (content is Map<String, dynamic>) {
      final nested =
          content['text'] ??
          content['message'] ??
          content['body'] ??
          content['value'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested;
      }

      if (nested is Map<String, dynamic>) {
        final deepText = nested['text'] ?? nested['value'];
        if (deepText is String && deepText.trim().isNotEmpty) {
          return deepText;
        }
      }

      final ops = content['ops'];
      if (ops is List) {
        for (final op in ops) {
          if (op is Map<String, dynamic>) {
            final insert = op['insert'];
            if (insert is String && insert.trim().isNotEmpty) {
              return insert.trim();
            }
          }
        }
      }
    }

    if (content is List) {
      for (final item in content) {
        if (item is Map<String, dynamic>) {
          final insert = item['insert'];
          if (insert is String && insert.trim().isNotEmpty) {
            return insert.trim();
          }
        }
      }
    }

    return '';
  }

  static String _resolveSenderId(Map<String, dynamic> json) {
    final sender = json['sender'];
    if (sender is Map<String, dynamic>) {
      final id = sender['id'] ?? sender['user_id'];
      if (id != null) {
        return id.toString();
      }
    }

    final user = json['user'];
    if (user is Map<String, dynamic>) {
      final id = user['id'] ?? user['user_id'];
      if (id != null) {
        return id.toString();
      }
    }

    final direct = json['sender_id'] ?? json['user_id'] ?? json['from_user_id'];
    return direct?.toString() ?? '';
  }
}
