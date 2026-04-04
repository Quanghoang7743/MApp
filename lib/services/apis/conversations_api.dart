import '../api_client.dart';

class ConversationsApi {
  ConversationsApi(this._client);

  final ApiClient _client;

  Future<dynamic> getConversations({Map<String, dynamic>? query}) {
    return _client.get('/conversations', query: query);
  }

  Future<dynamic> createDirectConversation(Map<String, dynamic> payload) {
    return _client.post('/conversations/direct', body: payload);
  }

  Future<dynamic> createGroupConversation(Map<String, dynamic> payload) {
    return _client.post('/conversations/group', body: payload);
  }

  Future<dynamic> getConversationById(String id) {
    return _client.get('/conversations/$id');
  }

  Future<dynamic> updateConversation(String id, Map<String, dynamic> payload) {
    return _client.put('/conversations/$id', body: payload);
  }

  Future<dynamic> deleteConversation(String id) {
    return _client.delete('/conversations/$id');
  }

  Future<dynamic> archiveConversation(String id) {
    return _client.patch('/conversations/$id/archive');
  }

  Future<dynamic> unarchiveConversation(String id) {
    return _client.patch('/conversations/$id/unarchive');
  }

  Future<dynamic> sendTypingStatus(String id, Map<String, dynamic> payload) {
    return _client.post('/conversations/$id/typing', body: payload);
  }

  Future<dynamic> pinConversation(String id, String userId) {
    return _client.patch('/conversations/$id/participants/$userId/pin');
  }

  Future<dynamic> unpinConversation(String id, String userId) {
    return _client.patch('/conversations/$id/participants/$userId/unpin');
  }

  Future<dynamic> muteConversation(String id, String userId) {
    return _client.patch('/conversations/$id/participants/$userId/mute');
  }

  Future<dynamic> unmuteConversation(String id, String userId) {
    return _client.patch('/conversations/$id/participants/$userId/unmute');
  }

  Future<dynamic> hideConversation(String id, String userId) {
    return _client.patch('/conversations/$id/participants/$userId/hide');
  }

  Future<dynamic> unhideConversation(String id, String userId) {
    return _client.patch('/conversations/$id/participants/$userId/unhide');
  }
}
