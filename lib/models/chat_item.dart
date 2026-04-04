class ChatItem {
  const ChatItem({
    required this.id,
    required this.name,
    required this.message,
    required this.time,
    required this.initials,
    this.isTyping = false,
  });

  final String id;
  final String name;
  final String message;
  final String time;
  final String initials;
  final bool isTyping;

  factory ChatItem.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final source = _normalizeSource(json);
    final displayName = _resolveDisplayName(source, currentUserId);
    final preview = _resolvePreviewMessage(source);
    return ChatItem(
      id:
          (source['id'] ??
                  source['conversation_id'] ??
                  source['conversationId'] ??
                  '')
              .toString(),
      name: displayName,
      message: preview,
      time: _resolveTime(source),
      initials: _resolveInitials(displayName),
      isTyping: source['is_typing'] == true || source['isTyping'] == true,
    );
  }

  static Map<String, dynamic> _normalizeSource(Map<String, dynamic> json) {
    final conversation = json['conversation'];
    if (conversation is Map<String, dynamic>) {
      return conversation;
    }
    return json;
  }

  static String _resolveDisplayName(
    Map<String, dynamic> json,
    String? currentUserId,
  ) {
    final directName =
        [
          json['name'],
          json['title'],
          json['display_name'],
          json['conversation_name'],
          json['group_name'],
          json['topic'],
        ].firstWhere(
          (value) => value is String && value.trim().isNotEmpty,
          orElse: () => '',
        );

    if (directName is String && directName.trim().isNotEmpty) {
      return directName;
    }

    final participants =
        json['participants'] ??
        json['members'] ??
        json['conversation_participants'];
    if (participants is List) {
      for (final participant in participants) {
        if (participant is! Map<String, dynamic>) {
          continue;
        }

        final user =
            participant['user'] ??
            participant['member'] ??
            participant['profile'] ??
            participant;
        if (user is! Map<String, dynamic>) {
          continue;
        }

        final userId = (user['id'] ?? user['user_id'] ?? '').toString();
        if (currentUserId != null &&
            currentUserId.isNotEmpty &&
            userId == currentUserId) {
          continue;
        }

        final candidate =
            [
              user['name'],
              user['fullName'],
              user['full_name'],
              user['username'],
              user['display_name'],
              user['phone_number'],
            ].firstWhere(
              (value) => value is String && value.trim().isNotEmpty,
              orElse: () => '',
            );

        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate;
        }
      }
    }

    return 'Unknown';
  }

  static String _resolvePreviewMessage(Map<String, dynamic> json) {
    final lastMessage = json['last_message'] ?? json['latest_message'];
    if (lastMessage is Map<String, dynamic>) {
      final text =
          lastMessage['content'] ??
          lastMessage['text'] ??
          lastMessage['message'] ??
          lastMessage['body'];
      if (text is String && text.trim().isNotEmpty) {
        return text;
      }
    }

    final topLevel =
        json['lastMessage'] ??
        json['message'] ??
        json['last_message_text'] ??
        json['lastMessageText'];
    if (topLevel is String && topLevel.trim().isNotEmpty) {
      return topLevel;
    }

    return '';
  }

  static String _resolveTime(Map<String, dynamic> json) {
    final createdAt =
        json['updated_at'] ??
        json['updatedAt'] ??
        json['last_message_at'] ??
        json['lastMessageAt'] ??
        json['created_at'] ??
        json['createdAt'] ??
        json['time'];
    if (createdAt is String && createdAt.trim().isNotEmpty) {
      return createdAt;
    }
    return 'Now';
  }

  static String _resolveInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == 'Unknown') {
      return '?';
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
