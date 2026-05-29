enum MediaSendState { sending, sent, failed }

class MessageAttachmentItem {
  const MessageAttachmentItem({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    this.mimeType,
    this.width,
    this.height,
    this.localPath,
  });

  final String id;
  final String url;
  final String? thumbnailUrl;
  final String? mimeType;
  final int? width;
  final int? height;
  final String? localPath;

  String? get displayUrl {
    if (url.trim().isNotEmpty) {
      return url;
    }
    final local = localPath?.trim();
    if (local != null && local.isNotEmpty) {
      return local;
    }
    return null;
  }

  bool get isImage {
    final normalizedMime = (mimeType ?? '').toLowerCase();
    if (normalizedMime.startsWith('image/')) {
      return true;
    }

    final candidate = (displayUrl ?? '').toLowerCase();
    return candidate.endsWith('.png') ||
        candidate.endsWith('.jpg') ||
        candidate.endsWith('.jpeg') ||
        candidate.endsWith('.gif') ||
        candidate.endsWith('.webp') ||
        candidate.endsWith('.heic');
  }

  factory MessageAttachmentItem.fromJson(Map<String, dynamic> json) {
    return MessageAttachmentItem(
      id: (json['id'] ?? json['attachment_id'] ?? '').toString(),
      url: _firstString(json, const [
        'url',
        'file_url',
        'fileUrl',
        'path',
        'file_path',
        'filePath',
        'original_url',
        'originalUrl',
      ]),
      thumbnailUrl: _nullableString(
        _firstValue(json, const [
          'thumbnail_url',
          'thumbnailUrl',
          'preview_url',
          'previewUrl',
        ]),
      ),
      mimeType: _nullableString(
        _firstValue(json, const ['mime_type', 'mimeType', 'content_type']),
      ),
      width: _nullableInt(_firstValue(json, const ['width', 'image_width'])),
      height: _nullableInt(_firstValue(json, const ['height', 'image_height'])),
      localPath: _nullableString(
        _firstValue(json, const ['local_path', 'localPath']),
      ),
    );
  }

  factory MessageAttachmentItem.fromCacheJson(Map<String, dynamic> json) {
    return MessageAttachmentItem(
      id: (json['id'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      thumbnailUrl: _nullableString(json['thumbnailUrl']),
      mimeType: _nullableString(json['mimeType']),
      width: _nullableInt(json['width']),
      height: _nullableInt(json['height']),
      localPath: _nullableString(json['localPath']),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'mimeType': mimeType,
      'width': width,
      'height': height,
      'localPath': localPath,
    };
  }

  MessageAttachmentItem copyWith({
    String? id,
    String? url,
    Object? thumbnailUrl = _sentinel,
    Object? mimeType = _sentinel,
    Object? width = _sentinel,
    Object? height = _sentinel,
    Object? localPath = _sentinel,
  }) {
    return MessageAttachmentItem(
      id: id ?? this.id,
      url: url ?? this.url,
      thumbnailUrl: identical(thumbnailUrl, _sentinel)
          ? this.thumbnailUrl
          : thumbnailUrl as String?,
      mimeType: identical(mimeType, _sentinel)
          ? this.mimeType
          : mimeType as String?,
      width: identical(width, _sentinel) ? this.width : width as int?,
      height: identical(height, _sentinel) ? this.height : height as int?,
      localPath: identical(localPath, _sentinel)
          ? this.localPath
          : localPath as String?,
    );
  }
}

class MessageReactionSummary {
  const MessageReactionSummary({
    required this.reactionCode,
    required this.count,
    this.reactedByMe = false,
  });

  final String reactionCode;
  final int count;
  final bool reactedByMe;

  factory MessageReactionSummary.fromJson(Map<String, dynamic> json) {
    return MessageReactionSummary(
      reactionCode: _firstString(json, const [
        'reaction_code',
        'reactionCode',
        'code',
        'emoji',
        'reaction',
      ]),
      count: _nullableInt(_firstValue(json, const ['count', 'total'])) ?? 0,
      reactedByMe:
          json['reacted_by_me'] == true ||
          json['reactedByMe'] == true ||
          json['is_me'] == true ||
          json['mine'] == true,
    );
  }

  factory MessageReactionSummary.fromCacheJson(Map<String, dynamic> json) {
    return MessageReactionSummary(
      reactionCode: (json['reactionCode'] ?? '').toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      reactedByMe: json['reactedByMe'] == true,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'reactionCode': reactionCode,
      'count': count,
      'reactedByMe': reactedByMe,
    };
  }

  static List<MessageReactionSummary> parseList(
    dynamic raw, {
    String? currentUserId,
  }) {
    if (raw == null) {
      return const [];
    }

    final normalizedCurrentUserId = (currentUserId ?? '').trim();

    if (raw is Map<String, dynamic>) {
      final items = <MessageReactionSummary>[];
      for (final entry in raw.entries) {
        final key = entry.key.trim();
        if (key.isEmpty) {
          continue;
        }

        final value = entry.value;
        if (value is num) {
          items.add(
            MessageReactionSummary(
              reactionCode: key,
              count: value.toInt(),
            ),
          );
          continue;
        }

        if (value is Map<String, dynamic>) {
          items.add(
            MessageReactionSummary(
              reactionCode: key,
              count:
                  _nullableInt(
                    _firstValue(value, const ['count', 'total']),
                  ) ??
                  0,
              reactedByMe:
                  value['reacted_by_me'] == true ||
                  value['reactedByMe'] == true ||
                  value['is_me'] == true ||
                  value['mine'] == true ||
                  _listContainsCurrentUser(
                    value['users'] ?? value['participants'],
                    normalizedCurrentUserId,
                  ),
            ),
          );
        }
      }
      return _merge(items);
    }

    if (raw is! List) {
      return const [];
    }

    final items = <MessageReactionSummary>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final code = _firstString(entry, const [
        'reaction_code',
        'reactionCode',
        'code',
        'emoji',
        'reaction',
      ]);
      if (code.isEmpty) {
        continue;
      }

      final users = entry['users'] ?? entry['participants'];
      final reactedByMe =
          entry['reacted_by_me'] == true ||
          entry['reactedByMe'] == true ||
          entry['is_me'] == true ||
          entry['mine'] == true ||
          _listContainsCurrentUser(users, normalizedCurrentUserId) ||
          _firstString(entry, const ['user_id', 'sender_id']) ==
              normalizedCurrentUserId;

      items.add(
        MessageReactionSummary(
          reactionCode: code,
          count:
              _nullableInt(_firstValue(entry, const ['count', 'total'])) ?? 1,
          reactedByMe: reactedByMe,
        ),
      );
    }

    return _merge(items);
  }

  static String? resolveMyReactionCode(List<MessageReactionSummary> items) {
    for (final item in items) {
      if (item.reactedByMe && item.reactionCode.trim().isNotEmpty) {
        return item.reactionCode;
      }
    }
    return null;
  }

  static List<MessageReactionSummary> _merge(List<MessageReactionSummary> items) {
    final merged = <String, MessageReactionSummary>{};

    for (final item in items) {
      final code = item.reactionCode.trim();
      if (code.isEmpty) {
        continue;
      }

      final existing = merged[code];
      if (existing == null) {
        merged[code] = item;
        continue;
      }

      merged[code] = MessageReactionSummary(
        reactionCode: code,
        count: existing.count + item.count,
        reactedByMe: existing.reactedByMe || item.reactedByMe,
      );
    }

    final normalized = merged.values.where((item) => item.count > 0).toList();
    normalized.sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.reactionCode.compareTo(b.reactionCode);
    });
    return List<MessageReactionSummary>.unmodifiable(normalized);
  }
}

class MessageItem {
  const MessageItem({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    this.attachments = const [],
    this.reactionSummary = const [],
    this.myReactionCode,
    this.mediaSendState = MediaSendState.sent,
  });

  final String id;
  final String text;
  final bool isMe;
  final String time;
  final List<MessageAttachmentItem> attachments;
  final List<MessageReactionSummary> reactionSummary;
  final String? myReactionCode;
  final MediaSendState mediaSendState;

  bool get hasAttachments => attachments.isNotEmpty;

  bool get hasImageAttachments => attachments.any((item) => item.isImage);

  String? get localMediaPath {
    for (final attachment in attachments) {
      final localPath = attachment.localPath?.trim();
      if (localPath != null && localPath.isNotEmpty) {
        return localPath;
      }
    }
    return null;
  }

  factory MessageItem.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final senderId = _resolveSenderId(json);
    final content = _resolveTextContent(json);
    final attachments = _resolveAttachments(json);
    final reactionSummary = _resolveReactionSummary(
      json,
      currentUserId: currentUserId,
    );
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
      attachments: attachments,
      reactionSummary: reactionSummary,
      myReactionCode:
          _resolveMyReactionCode(json) ??
          MessageReactionSummary.resolveMyReactionCode(reactionSummary),
      mediaSendState: MediaSendState.sent,
    );
  }

  factory MessageItem.fromCacheJson(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'];
    final reactionRaw = json['reactionSummary'];

    return MessageItem(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      isMe: json['isMe'] == true,
      time: (json['time'] ?? '').toString(),
      attachments: attachmentsRaw is List
          ? attachmentsRaw
                .whereType<Map<String, dynamic>>()
                .map(MessageAttachmentItem.fromCacheJson)
                .toList(growable: false)
          : const [],
      reactionSummary: reactionRaw is List
          ? reactionRaw
                .whereType<Map<String, dynamic>>()
                .map(MessageReactionSummary.fromCacheJson)
                .toList(growable: false)
          : const [],
      myReactionCode: _nullableString(json['myReactionCode']),
      mediaSendState: _mediaSendStateFromJson(json['mediaSendState']),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'text': text,
      'isMe': isMe,
      'time': time,
      'attachments': attachments
          .map((attachment) => attachment.toCacheJson())
          .toList(growable: false),
      'reactionSummary': reactionSummary
          .map((summary) => summary.toCacheJson())
          .toList(growable: false),
      'myReactionCode': myReactionCode,
      'mediaSendState': mediaSendState.name,
    };
  }

  MessageItem copyWith({
    String? id,
    String? text,
    bool? isMe,
    String? time,
    List<MessageAttachmentItem>? attachments,
    List<MessageReactionSummary>? reactionSummary,
    Object? myReactionCode = _sentinel,
    MediaSendState? mediaSendState,
  }) {
    return MessageItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isMe: isMe ?? this.isMe,
      time: time ?? this.time,
      attachments: attachments ?? this.attachments,
      reactionSummary: reactionSummary ?? this.reactionSummary,
      myReactionCode: identical(myReactionCode, _sentinel)
          ? this.myReactionCode
          : myReactionCode as String?,
      mediaSendState: mediaSendState ?? this.mediaSendState,
    );
  }

  static List<MessageAttachmentItem> _resolveAttachments(
    Map<String, dynamic> json,
  ) {
    final attachments = <MessageAttachmentItem>[];

    for (final candidate in [
      json['attachments'],
      json['message_attachments'],
      json['messageAttachments'],
      json['files'],
      if (json['content'] is Map<String, dynamic>)
        (json['content'] as Map<String, dynamic>)['attachments'],
    ]) {
      if (candidate is! List) {
        continue;
      }

      for (final raw in candidate) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final attachment = MessageAttachmentItem.fromJson(raw);
        if ((attachment.displayUrl ?? '').trim().isEmpty &&
            attachment.id.isEmpty) {
          continue;
        }
        attachments.add(attachment);
      }

      if (attachments.isNotEmpty) {
        break;
      }
    }

    return List<MessageAttachmentItem>.unmodifiable(attachments);
  }

  static List<MessageReactionSummary> _resolveReactionSummary(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    for (final candidate in [
      json['reaction_summary'],
      json['reactionSummary'],
      json['reactions_summary'],
      json['reactionsSummary'],
      json['reactions'],
    ]) {
      final parsed = MessageReactionSummary.parseList(
        candidate,
        currentUserId: currentUserId,
      );
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    return const [];
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

  static String? _resolveMyReactionCode(Map<String, dynamic> json) {
    final value = _firstValue(json, const [
      'my_reaction_code',
      'myReactionCode',
      'current_user_reaction',
      'currentUserReaction',
    ]);
    return _nullableString(value);
  }
}

const Object _sentinel = Object();

String _firstString(Map<String, dynamic> json, List<String> keys) {
  final value = _firstValue(json, keys);
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return '';
}

dynamic _firstValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) {
      return json[key];
    }
  }
  return null;
}

String? _nullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

int? _nullableInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool _listContainsCurrentUser(dynamic raw, String currentUserId) {
  if (raw is! List || currentUserId.isEmpty) {
    return false;
  }

  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      final userId = _firstString(item, const ['id', 'user_id']);
      if (userId == currentUserId) {
        return true;
      }
    } else if (item != null && item.toString() == currentUserId) {
      return true;
    }
  }

  return false;
}

MediaSendState _mediaSendStateFromJson(dynamic value) {
  if (value is String) {
    for (final state in MediaSendState.values) {
      if (state.name == value) {
        return state;
      }
    }
  }
  return MediaSendState.sent;
}
