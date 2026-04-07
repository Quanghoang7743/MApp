import '../api_client.dart';

class MessagesApi {
  MessagesApi(this._client);

  final ApiClient _client;

  Future<dynamic> getMessages(
    String conversationId, {
    Map<String, dynamic>? query,
  }) {
    return _client.get('/conversations/$conversationId/messages', query: query);
  }

  Future<dynamic> sendMessage(
    String conversationId,
    Map<String, dynamic> payload,
  ) {
    return _client.post(
      '/conversations/$conversationId/messages',
      body: payload,
    );
  }

  Future<dynamic> getMessageById(String messageId) {
    return _client.get('/messages/$messageId');
  }

  Future<dynamic> updateMessage(
    String messageId,
    Map<String, dynamic> payload,
  ) {
    return _client.put('/messages/$messageId', body: payload);
  }

  Future<dynamic> deleteMessage(String messageId) {
    return _client.delete('/messages/$messageId');
  }

  Future<dynamic> deleteForEveryone(
    String messageId,
    Map<String, dynamic> payload,
  ) {
    return _client.patch(
      '/messages/$messageId/delete-for-everyone',
      body: payload,
    );
  }

  Future<dynamic> forwardMessage(
    String messageId,
    Map<String, dynamic> payload,
  ) {
    return _client.post('/messages/$messageId/forward', body: payload);
  }
}
