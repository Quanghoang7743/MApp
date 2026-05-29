import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mess_app/models/chat_item.dart';
import 'package:mess_app/models/message_item.dart';
import 'package:mess_app/services/local/chat_cache_service.dart';

void main() {
  group('ChatCacheService Tests', () {
    late DateTime currentTime;
    late ChatCacheService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      currentTime = DateTime.utc(2026, 5, 29, 10);
      service = ChatCacheService(nowProvider: () => currentTime);
    });

    test('reads and migrates legacy chat list cache', () async {
      SharedPreferences.setMockInitialValues({
        'cache_chat_list_v1': jsonEncode([
          {
            'id': 'chat-1',
            'name': 'Alice',
            'message': 'Xin chao',
            'time': '2026-05-29T08:00:00Z',
            'initials': 'A',
            'isTyping': false,
            'unreadCount': 1,
            'isPinned': false,
            'isGroup': false,
            'isStarred': false,
          },
        ]),
      });

      final chats = await service.readChats();

      expect(chats, hasLength(1));
      expect(chats.first.name, 'Alice');

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('cache_chat_list_v1')!);
      expect(stored, isA<Map<String, dynamic>>());
      expect(stored['items'], isA<List<dynamic>>());
      expect(stored['savedAt'], currentTime.toIso8601String());
    });

    test('removes expired message cache on read', () async {
      SharedPreferences.setMockInitialValues({
        'cache_conversation_chat-1_messages_v1': jsonEncode({
          'conversationId': 'chat-1',
          'savedAt': currentTime
              .subtract(const Duration(days: 8))
              .toIso8601String(),
          'lastAccessedAt': currentTime
              .subtract(const Duration(days: 8))
              .toIso8601String(),
          'estimatedBytes': 120,
          'items': [
            {
              'id': 'm-1',
              'text': 'Cu',
              'isMe': true,
              'time': '2026-05-20T08:00:00Z',
            },
          ],
        }),
      });

      final messages = await service.readMessages('chat-1');

      expect(messages, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cache_conversation_chat-1_messages_v1'), isNull);
    });

    test(
      'saveMessages trims oldest items when a conversation exceeds the cap',
      () async {
        final messages = [
          _message('m-1', _largeText(90 * 1024), '2026-05-29T08:00:00Z'),
          _message('m-2', _largeText(90 * 1024), '2026-05-29T08:05:00Z'),
          _message('m-3', _largeText(90 * 1024), '2026-05-29T08:10:00Z'),
        ];

        await service.saveMessages('chat-1', messages);

        final cached = await service.readMessages('chat-1');
        expect(cached.map((item) => item.id).toList(), ['m-2', 'm-3']);
      },
    );

    test(
      'prunes least recently accessed conversations when global cache exceeds the cap',
      () async {
        for (var i = 0; i < 9; i++) {
          currentTime = DateTime.utc(2026, 5, 29, 10, i);
          await service.saveMessages('chat-$i', [
            _message('m-$i-a', _largeText(115 * 1024), '2026-05-29T08:00:00Z'),
            _message('m-$i-b', _largeText(115 * 1024), '2026-05-29T08:05:00Z'),
          ]);
        }

        final stats = await service.getStorageStats();

        expect(stats.conversationCacheCount, lessThan(9));
        expect(await service.readMessages('chat-0'), isEmpty);
        expect(await service.readMessages('chat-8'), isNotEmpty);
      },
    );

    test(
      'clear actions only remove their own cache group and keep auth data',
      () async {
        final chats = [
          const ChatItem(
            id: 'chat-1',
            name: 'Alice',
            message: 'Xin chao',
            time: '2026-05-29T08:00:00Z',
            initials: 'A',
          ),
        ];

        await service.saveChats(chats);
        await service.saveMessages('chat-1', [
          _message('m-1', 'Hello', '2026-05-29T08:00:00Z'),
        ]);

        SharedPreferences.setMockInitialValues({
          ...(await _currentPrefsMap()),
          'auth_token': 'token-123',
          'auth_user': jsonEncode({'id': 1}),
        });

        await service.clearChatList();

        var prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('cache_chat_list_v1'), isNull);
        expect(
          prefs.getString('cache_conversation_chat-1_messages_v1'),
          isNotNull,
        );
        expect(prefs.getString('auth_token'), 'token-123');

        await service.clearAllMessages();

        prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('cache_conversation_chat-1_messages_v1'),
          isNull,
        );
        expect(prefs.getString('auth_token'), 'token-123');
        expect(prefs.getString('auth_user'), isNotNull);
      },
    );

    test(
      'getStorageStats returns bytes for chat and message cache separately',
      () async {
        await service.saveChats([
          const ChatItem(
            id: 'chat-1',
            name: 'Alice',
            message: 'Xin chao',
            time: '2026-05-29T08:00:00Z',
            initials: 'A',
          ),
        ]);
        await service.saveMessages('chat-1', [
          _message('m-1', 'Hello', '2026-05-29T08:00:00Z'),
        ]);

        final stats = await service.getStorageStats();

        expect(stats.chatListBytes, greaterThan(0));
        expect(stats.messageBytes, greaterThan(0));
        expect(stats.totalBytes, stats.chatListBytes + stats.messageBytes);
        expect(stats.conversationCacheCount, 1);
      },
    );
  });
}

MessageItem _message(String id, String text, String time) {
  return MessageItem(id: id, text: text, isMe: true, time: time);
}

String _largeText(int size) => List.filled(size, 'a').join();

Future<Map<String, Object>> _currentPrefsMap() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
}
