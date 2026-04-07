import 'api_client.dart';
import 'apis/attachments_api.dart';
import 'apis/broadcasting_api.dart';
import 'apis/conversations_api.dart';
import 'apis/devices_api.dart';
import 'apis/friends_api.dart';
import 'apis/messages_api.dart';
import 'apis/participants_api.dart';
import 'apis/reactions_api.dart';

class ApiServices {
  ApiServices({Future<String?> Function()? tokenProvider})
    : client = ApiClient(tokenProvider: tokenProvider) {
    friends = FriendsApi(client);
    devices = DevicesApi(client);
    conversations = ConversationsApi(client);
    participants = ParticipantsApi(client);
    messages = MessagesApi(client);
    attachments = AttachmentsApi(client);
    reactions = ReactionsApi(client);
    broadcasting = BroadcastingApi(client);
  }

  final ApiClient client;
  late final FriendsApi friends;
  late final DevicesApi devices;
  late final ConversationsApi conversations;
  late final ParticipantsApi participants;
  late final MessagesApi messages;
  late final AttachmentsApi attachments;
  late final ReactionsApi reactions;
  late final BroadcastingApi broadcasting;
}
