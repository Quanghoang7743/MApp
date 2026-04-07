import '../api_client.dart';

class ReactionsApi {
  ReactionsApi(this._client);

  final ApiClient _client;

  Future<dynamic> addReaction(String messageId, Map<String, dynamic> payload) {
    return _client.post('/messages/$messageId/reactions', body: payload);
  }

  Future<dynamic> deleteReaction(
    String messageId, {
    Map<String, dynamic>? payload,
  }) {
    return _client.delete('/messages/$messageId/reactions', body: payload);
  }

  Future<dynamic> getReactions(String messageId) {
    return _client.get('/messages/$messageId/reactions');
  }
}
