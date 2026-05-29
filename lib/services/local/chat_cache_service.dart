import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_item.dart';
import '../../models/message_item.dart';

class ChatCacheStats {
  const ChatCacheStats({
    required this.chatListBytes,
    required this.messageBytes,
    required this.totalBytes,
    required this.conversationCacheCount,
  });

  final int chatListBytes;
  final int messageBytes;
  final int totalBytes;
  final int conversationCacheCount;
}

class ChatCacheService {
  ChatCacheService({DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  static const _chatListKey = 'cache_chat_list_v1';
  static const _messageKeyPrefix = 'cache_conversation_';
  static const _messageKeySuffix = '_messages_v1';
  static const _itemsKey = 'items';
  static const _savedAtKey = 'savedAt';
  static const _lastAccessedAtKey = 'lastAccessedAt';
  static const _estimatedBytesKey = 'estimatedBytes';
  static const _conversationIdKey = 'conversationId';
  static const Duration _ttl = Duration(days: 7);
  static const int _maxConversationBytes = 256 * 1024;
  static const int _maxTotalMessageBytes = 2 * 1024 * 1024;

  final DateTime Function() _nowProvider;

  static String _messageKey(String conversationId) =>
      '$_messageKeyPrefix${conversationId}$_messageKeySuffix';

  Future<List<ChatItem>> readChats() async {
    final prefs = await SharedPreferences.getInstance();
    final result = _readChatCache(prefs.getString(_chatListKey));

    if (result.removeKey) {
      await prefs.remove(_chatListKey);
      return const [];
    }

    if (result.shouldPersist && result.items.isNotEmpty) {
      await _writeChatEnvelope(
        prefs,
        result.items,
        savedAt: result.savedAt ?? _now(),
      );
    }

    return result.items;
  }

  Future<void> saveChats(List<ChatItem> chats) async {
    final prefs = await SharedPreferences.getInstance();
    if (chats.isEmpty) {
      await prefs.remove(_chatListKey);
      return;
    }

    await _writeChatEnvelope(prefs, chats, savedAt: _now());
  }

  Future<List<MessageItem>> readMessages(String conversationId) async {
    if (conversationId.isEmpty) {
      return const [];
    }

    final prefs = await SharedPreferences.getInstance();
    final result = _readMessageCache(
      raw: prefs.getString(_messageKey(conversationId)),
      fallbackConversationId: conversationId,
    );

    if (result.removeKey) {
      await prefs.remove(_messageKey(conversationId));
      return const [];
    }

    if (result.items.isEmpty) {
      return const [];
    }

    await _writeMessageEnvelope(
      prefs,
      conversationId: conversationId,
      messages: result.items,
      savedAt: result.savedAt ?? _now(),
      lastAccessedAt: _now(),
    );
    await _pruneMessageCaches(prefs);

    return result.items;
  }

  Future<void> saveMessages(
    String conversationId,
    List<MessageItem> messages,
  ) async {
    if (conversationId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final trimmedMessages = _trimMessagesToConversationLimit(messages);
    if (trimmedMessages.isEmpty) {
      await prefs.remove(_messageKey(conversationId));
      await _pruneMessageCaches(prefs);
      return;
    }

    await _writeMessageEnvelope(
      prefs,
      conversationId: conversationId,
      messages: trimmedMessages,
      savedAt: _now(),
      lastAccessedAt: _now(),
    );
    await _pruneMessageCaches(prefs);
  }

  Future<void> clearChatList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatListKey);
  }

  Future<void> clearAllMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(_isMessageCacheKey).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<ChatCacheStats> getStorageStats() async {
    final prefs = await SharedPreferences.getInstance();
    await _pruneChatListCache(prefs);
    await _pruneMessageCaches(prefs);

    final chatListRaw = prefs.getString(_chatListKey);
    final chatListBytes = _byteLength(chatListRaw);

    var messageBytes = 0;
    var conversationCacheCount = 0;
    for (final key in prefs.getKeys().where(_isMessageCacheKey)) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }
      messageBytes += _byteLength(raw);
      conversationCacheCount++;
    }

    return ChatCacheStats(
      chatListBytes: chatListBytes,
      messageBytes: messageBytes,
      totalBytes: chatListBytes + messageBytes,
      conversationCacheCount: conversationCacheCount,
    );
  }

  Future<void> pruneExpiredAndOversizedCaches() async {
    final prefs = await SharedPreferences.getInstance();
    await _pruneChatListCache(prefs);
    await _pruneMessageCaches(prefs);
  }

  Future<void> _pruneChatListCache(SharedPreferences prefs) async {
    final result = _readChatCache(prefs.getString(_chatListKey));
    if (result.removeKey) {
      await prefs.remove(_chatListKey);
      return;
    }

    if (result.shouldPersist && result.items.isNotEmpty) {
      await _writeChatEnvelope(
        prefs,
        result.items,
        savedAt: result.savedAt ?? _now(),
      );
    }
  }

  Future<void> _pruneMessageCaches(SharedPreferences prefs) async {
    final entries = <_StoredMessageCacheEntry>[];

    for (final key in prefs.getKeys().where(_isMessageCacheKey)) {
      final result = _readMessageCache(
        raw: prefs.getString(key),
        fallbackConversationId: _conversationIdFromKey(key),
      );

      if (result.removeKey || result.items.isEmpty) {
        await prefs.remove(key);
        continue;
      }

      final normalizedMessages = _trimMessagesToConversationLimit(result.items);
      if (normalizedMessages.isEmpty) {
        await prefs.remove(key);
        continue;
      }

      final savedAt = result.savedAt ?? _now();
      final lastAccessedAt = result.lastAccessedAt ?? savedAt;
      final raw = _buildMessageEnvelopeJson(
        conversationId: result.conversationId,
        messages: normalizedMessages,
        savedAt: savedAt,
        lastAccessedAt: lastAccessedAt,
      );

      if (result.shouldPersist ||
          normalizedMessages.length != result.items.length) {
        await prefs.setString(key, raw);
      }

      entries.add(
        _StoredMessageCacheEntry(
          key: key,
          bytes: _byteLength(raw),
          lastAccessedAt: lastAccessedAt,
        ),
      );
    }

    entries.sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
    var totalBytes = entries.fold<int>(0, (sum, entry) => sum + entry.bytes);

    for (final entry in entries) {
      if (totalBytes <= _maxTotalMessageBytes) {
        break;
      }
      await prefs.remove(entry.key);
      totalBytes -= entry.bytes;
    }
  }

  Future<void> _writeChatEnvelope(
    SharedPreferences prefs,
    List<ChatItem> chats, {
    required DateTime savedAt,
  }) async {
    final raw = _buildChatEnvelopeJson(chats, savedAt: savedAt);
    await prefs.setString(_chatListKey, raw);
  }

  Future<void> _writeMessageEnvelope(
    SharedPreferences prefs, {
    required String conversationId,
    required List<MessageItem> messages,
    required DateTime savedAt,
    required DateTime lastAccessedAt,
  }) async {
    final raw = _buildMessageEnvelopeJson(
      conversationId: conversationId,
      messages: messages,
      savedAt: savedAt,
      lastAccessedAt: lastAccessedAt,
    );
    await prefs.setString(_messageKey(conversationId), raw);
  }

  _ChatCacheReadResult _readChatCache(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const _ChatCacheReadResult(items: []);
    }

    final decoded = _tryDecode(raw);
    if (decoded == null) {
      return const _ChatCacheReadResult(items: [], removeKey: true);
    }

    if (decoded is List) {
      final items = _parseChats(decoded);
      return _ChatCacheReadResult(
        items: items,
        shouldPersist: items.isNotEmpty,
        savedAt: _now(),
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const _ChatCacheReadResult(items: [], removeKey: true);
    }

    final savedAt = _parseDateTime(decoded[_savedAtKey]);
    final items = _parseChats(decoded[_itemsKey]);
    if (savedAt == null || items.isEmpty) {
      return const _ChatCacheReadResult(items: [], removeKey: true);
    }

    if (_isExpired(savedAt)) {
      return const _ChatCacheReadResult(items: [], removeKey: true);
    }

    return _ChatCacheReadResult(items: items, savedAt: savedAt);
  }

  _MessageCacheReadResult _readMessageCache({
    required String? raw,
    required String fallbackConversationId,
  }) {
    if (raw == null || raw.isEmpty) {
      return _MessageCacheReadResult(
        conversationId: fallbackConversationId,
        items: const [],
      );
    }

    final decoded = _tryDecode(raw);
    if (decoded == null) {
      return _MessageCacheReadResult(
        conversationId: fallbackConversationId,
        items: const [],
        removeKey: true,
      );
    }

    if (decoded is List) {
      final items = _trimMessagesToConversationLimit(_parseMessages(decoded));
      return _MessageCacheReadResult(
        conversationId: fallbackConversationId,
        items: items,
        shouldPersist: items.isNotEmpty,
        savedAt: _now(),
        lastAccessedAt: _now(),
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return _MessageCacheReadResult(
        conversationId: fallbackConversationId,
        items: const [],
        removeKey: true,
      );
    }

    final savedAt = _parseDateTime(decoded[_savedAtKey]);
    final lastAccessedAt =
        _parseDateTime(decoded[_lastAccessedAtKey]) ?? savedAt;
    final items = _trimMessagesToConversationLimit(
      _parseMessages(decoded[_itemsKey]),
    );
    final conversationId =
        (decoded[_conversationIdKey] ?? fallbackConversationId).toString();

    if (savedAt == null || conversationId.isEmpty || items.isEmpty) {
      return _MessageCacheReadResult(
        conversationId: fallbackConversationId,
        items: const [],
        removeKey: true,
      );
    }

    if (_isExpired(savedAt)) {
      return _MessageCacheReadResult(
        conversationId: fallbackConversationId,
        items: const [],
        removeKey: true,
      );
    }

    return _MessageCacheReadResult(
      conversationId: conversationId,
      items: items,
      savedAt: savedAt,
      lastAccessedAt: lastAccessedAt,
    );
  }

  List<ChatItem> _parseChats(dynamic decoded) {
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ChatItem.fromCacheJson)
        .toList(growable: false);
  }

  List<MessageItem> _parseMessages(dynamic decoded) {
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MessageItem.fromCacheJson)
        .toList(growable: false);
  }

  List<MessageItem> _trimMessagesToConversationLimit(
    List<MessageItem> messages,
  ) {
    final sortedMessages = _sortMessagesByTime(messages);
    if (sortedMessages.isEmpty) {
      return const [];
    }

    final trimmed = List<MessageItem>.from(sortedMessages);
    while (trimmed.length > 1 &&
        _messageEnvelopeBytes(
              conversationId: 'trim-check',
              messages: trimmed,
              savedAt: _now(),
              lastAccessedAt: _now(),
            ) >
            _maxConversationBytes) {
      trimmed.removeAt(0);
    }

    return List<MessageItem>.unmodifiable(trimmed);
  }

  List<MessageItem> _sortMessagesByTime(List<MessageItem> messages) {
    final sorted = List<MessageItem>.from(messages);
    sorted.sort((a, b) {
      final aTime = DateTime.tryParse(a.time);
      final bTime = DateTime.tryParse(b.time);

      if (aTime != null && bTime != null) {
        return aTime.compareTo(bTime);
      }
      if (aTime != null) {
        return -1;
      }
      if (bTime != null) {
        return 1;
      }
      return 0;
    });
    return sorted;
  }

  String _buildChatEnvelopeJson(
    List<ChatItem> chats, {
    required DateTime savedAt,
  }) {
    final payload = chats
        .map((item) => item.toCacheJson())
        .toList(growable: false);
    final envelope = <String, dynamic>{
      _savedAtKey: savedAt.toIso8601String(),
      _estimatedBytesKey: 0,
      _itemsKey: payload,
    };

    envelope[_estimatedBytesKey] = _byteLength(jsonEncode(envelope));
    return jsonEncode(envelope);
  }

  String _buildMessageEnvelopeJson({
    required String conversationId,
    required List<MessageItem> messages,
    required DateTime savedAt,
    required DateTime lastAccessedAt,
  }) {
    final payload = messages
        .map((message) => message.toCacheJson())
        .toList(growable: false);
    final envelope = <String, dynamic>{
      _conversationIdKey: conversationId,
      _savedAtKey: savedAt.toIso8601String(),
      _lastAccessedAtKey: lastAccessedAt.toIso8601String(),
      _estimatedBytesKey: 0,
      _itemsKey: payload,
    };

    envelope[_estimatedBytesKey] = _byteLength(jsonEncode(envelope));
    return jsonEncode(envelope);
  }

  int _messageEnvelopeBytes({
    required String conversationId,
    required List<MessageItem> messages,
    required DateTime savedAt,
    required DateTime lastAccessedAt,
  }) {
    return _byteLength(
      _buildMessageEnvelopeJson(
        conversationId: conversationId,
        messages: messages,
        savedAt: savedAt,
        lastAccessedAt: lastAccessedAt,
      ),
    );
  }

  bool _isExpired(DateTime savedAt) => _now().difference(savedAt) > _ttl;

  bool _isMessageCacheKey(String key) =>
      key.startsWith(_messageKeyPrefix) && key.endsWith(_messageKeySuffix);

  String _conversationIdFromKey(String key) {
    if (!_isMessageCacheKey(key)) {
      return '';
    }

    return key.substring(
      _messageKeyPrefix.length,
      key.length - _messageKeySuffix.length,
    );
  }

  dynamic _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  int _byteLength(String? value) {
    if (value == null || value.isEmpty) {
      return 0;
    }
    return utf8.encode(value).length;
  }

  DateTime _now() => _nowProvider().toUtc();
}

class _ChatCacheReadResult {
  const _ChatCacheReadResult({
    required this.items,
    this.savedAt,
    this.shouldPersist = false,
    this.removeKey = false,
  });

  final List<ChatItem> items;
  final DateTime? savedAt;
  final bool shouldPersist;
  final bool removeKey;
}

class _MessageCacheReadResult {
  const _MessageCacheReadResult({
    required this.conversationId,
    required this.items,
    this.savedAt,
    this.lastAccessedAt,
    this.shouldPersist = false,
    this.removeKey = false,
  });

  final String conversationId;
  final List<MessageItem> items;
  final DateTime? savedAt;
  final DateTime? lastAccessedAt;
  final bool shouldPersist;
  final bool removeKey;
}

class _StoredMessageCacheEntry {
  const _StoredMessageCacheEntry({
    required this.key,
    required this.bytes,
    required this.lastAccessedAt,
  });

  final String key;
  final int bytes;
  final DateTime lastAccessedAt;
}
