import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/Views/widgets/chat_widgets/input_bar.dart';
import 'package:mess_app/Views/widgets/chat_widgets/message_bubble.dart';
import 'package:mess_app/models/message_item.dart';

void main() {
  testWidgets('message bubble supports long press and failed media actions', (
    tester,
  ) async {
    var longPressed = false;
    var retried = false;
    var removed = false;

    final message = MessageItem(
      id: 'm-1',
      text: 'Xin chao',
      isMe: true,
      time: '10:30',
      attachments: const [
        MessageAttachmentItem(
          id: 'a-1',
          url: '',
          mimeType: 'image/jpeg',
          localPath: '/tmp/photo.jpg',
        ),
      ],
      reactionSummary: const [
        MessageReactionSummary(
          reactionCode: 'like',
          count: 1,
          reactedByMe: true,
        ),
      ],
      myReactionCode: 'like',
      mediaSendState: MediaSendState.failed,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: message,
            isSending: false,
            peerInitials: 'AB',
            onLongPressStart: (_) {
              longPressed = true;
            },
            onRetryMedia: () {
              retried = true;
            },
            onRemoveMedia: () {
              removed = true;
            },
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Xin chao'));
    await tester.pump();
    expect(longPressed, isTrue);

    expect(find.text('👍'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Xóa'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.tap(find.text('Xóa'));
    await tester.pump();

    expect(retried, isTrue);
    expect(removed, isTrue);
  });

  testWidgets('input bar triggers photo and camera callbacks', (tester) async {
    var pickedPhoto = false;
    var openedCamera = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InputBar(
            isDark: false,
            conversationId: 'c-1',
            onSend: (_) {},
            onPickPhoto: () async {
              pickedPhoto = true;
            },
            onOpenCamera: () async {
              openedCamera = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.attach_file_rounded));
    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pump();

    expect(pickedPhoto, isTrue);
    expect(openedCamera, isTrue);
  });
}
