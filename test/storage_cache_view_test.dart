import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mess_app/Views/widgets/setting_widgets/storege_cache.dart';
import 'package:mess_app/models/chat_item.dart';
import 'package:mess_app/models/message_item.dart';
import 'package:mess_app/services/local/chat_cache_service.dart';

void main() {
  testWidgets('renders stats and clears chat list from settings view', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = ChatCacheService(
      nowProvider: () => DateTime.utc(2026, 5, 29, 10),
    );

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
      const MessageItem(
        id: 'm-1',
        text: 'Hello',
        isMe: true,
        time: '2026-05-29T08:00:00Z',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: StorageCacheView(cacheService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dữ liệu trên máy'), findsOneWidget);
    expect(find.textContaining('Đang dùng:'), findsNWidgets(2));

    await tester.tap(find.text('Xóa bộ nhớ đệm'));
    await tester.pumpAndSettle();

    expect(find.text('Xóa bộ nhớ đệm'), findsWidgets);
    expect(
      find.textContaining('danh sách trò chuyện đã lưu cục bộ'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Xóa').last);
    await tester.pumpAndSettle();

    expect(find.text('Đã xóa bộ nhớ đệm danh sách trò chuyện'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cache_chat_list_v1'), isNull);
    expect(prefs.getString('cache_conversation_chat-1_messages_v1'), isNotNull);
  });
}
