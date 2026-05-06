import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_item.dart';
import '../../models/message_item.dart';

class ChatCacheService {
  static const _chatListKey = 'cache_chat_list_v1';
  static String _messageKey(String conversationId) =>
      'cache_conversation_${conversationId}_messages_v1';

  Future<List<ChatItem>> readChats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatListKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ChatItem.fromCacheJson)
        .toList(growable: false);
  }

  Future<void> saveChats(List<ChatItem> chats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chatListKey,
      jsonEncode(chats.map((e) => e.toCacheJson()).toList()),
    );
  }

  Future<List<MessageItem>> readMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_messageKey(conversationId));
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MessageItem.fromCacheJson)
        .toList(growable: false);
  }

  Future<void> saveMessages(
    String conversationId,
    List<MessageItem> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _messageKey(conversationId),
      jsonEncode(messages.map((e) => e.toCacheJson()).toList()),
    );
  }
}
