import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/models/message_item.dart';

void main() {
  group('MessageItem', () {
    test('parses image attachment and reaction summary from api payload', () {
      final message = MessageItem.fromJson(
        {
          'id': 'm-1',
          'content': '',
          'created_at': '2026-05-29T10:30:00Z',
          'sender_id': 'u-1',
          'attachments': [
            {
              'id': 'a-1',
              'url': 'https://cdn.example.com/photo.jpg',
              'mime_type': 'image/jpeg',
            },
          ],
          'reaction_summary': {
            'like': {'count': 2, 'reacted_by_me': true},
            'love': 1,
          },
        },
        currentUserId: 'u-1',
      );

      expect(message.isMe, isTrue);
      expect(message.attachments, hasLength(1));
      expect(message.attachments.first.url, contains('photo.jpg'));
      expect(message.attachments.first.isImage, isTrue);
      expect(message.reactionSummary, hasLength(2));
      expect(message.myReactionCode, 'like');
    });

    test('reads media send state and local attachment from cache json', () {
      final message = MessageItem.fromCacheJson({
        'id': 'local-1',
        'text': '',
        'isMe': true,
        'time': '2026-05-29T10:30:00Z',
        'mediaSendState': 'failed',
        'attachments': [
          {
            'id': 'local-attachment',
            'url': '',
            'mimeType': 'image/jpeg',
            'localPath': '/tmp/local-photo.jpg',
          },
        ],
        'reactionSummary': [
          {
            'reactionCode': 'wow',
            'count': 1,
            'reactedByMe': false,
          },
        ],
      });

      expect(message.mediaSendState, MediaSendState.failed);
      expect(message.localMediaPath, '/tmp/local-photo.jpg');
      expect(message.reactionSummary.single.reactionCode, 'wow');
    });
  });
}
