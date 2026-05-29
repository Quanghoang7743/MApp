class ChatItem {
  const ChatItem({
    required this.id,
    required this.name,
    required this.message,
    required this.time,
    required this.initials,
    this.isTyping = false,
    this.avatarUrl,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isGroup = false,
    this.isStarred = false,
  });

  final String id;
  final String name;
  final String message;
  final String time;
  final String initials;
  final bool isTyping;
  final String? avatarUrl;
  final int unreadCount;
  final bool isPinned;
  final bool isGroup;
  final bool isStarred;

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
      avatarUrl: _resolveAvatarUrl(source),
      unreadCount: _resolveUnreadCount(source),
      isPinned: _resolveBoolean(source, const [
        'is_pinned',
        'isPinned',
        'pinned',
      ]),
      isGroup: _resolveBoolean(source, const ['is_group', 'isGroup', 'group']),
      isStarred: _resolveBoolean(source, const [
        'is_starred',
        'isStarred',
        'starred',
      ]),
    );
  }

  factory ChatItem.fromCacheJson(Map<String, dynamic> json) {
    return ChatItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      message: (json['message'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      initials: (json['initials'] ?? '?').toString(),
      isTyping: json['isTyping'] == true,
      avatarUrl: json['avatarUrl']?.toString(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      isPinned: json['isPinned'] == true,
      isGroup: json['isGroup'] == true,
      isStarred: json['isStarred'] == true,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'name': name,
      'message': message,
      'time': time,
      'initials': initials,
      'isTyping': isTyping,
      'avatarUrl': avatarUrl,
      'unreadCount': unreadCount,
      'isPinned': isPinned,
      'isGroup': isGroup,
      'isStarred': isStarred,
    };
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

  static String? _resolveAvatarUrl(Map<String, dynamic> json) {
    final direct = [json['avatar_url'], json['avatarUrl'], json['photo_url']]
        .firstWhere(
          (value) => value is String && value.trim().isNotEmpty,
          orElse: () => null,
        );
    if (direct is String) {
      return direct;
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
        for (final key in const ['avatar_url', 'avatarUrl', 'photo_url']) {
          final value = user[key];
          if (value is String && value.trim().isNotEmpty) {
            return value;
          }
        }
      }
    }

    return null;
  }

  static int _resolveUnreadCount(Map<String, dynamic> json) {
    for (final key in const [
      'unread_count',
      'unreadCount',
      'unread_messages_count',
    ]) {
      final value = json[key];
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  static bool _resolveBoolean(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
      }
    }
    return false;
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
