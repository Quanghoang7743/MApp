import '../api_client.dart';

class ParticipantsApi {
  ParticipantsApi(this._client);

  final ApiClient _client;

  Future<dynamic> getParticipants(String conversationId) {
    return _client.get('/conversations/$conversationId/participants');
  }

  Future<dynamic> addParticipant(
    String conversationId,
    Map<String, dynamic> payload,
  ) {
    return _client.post(
      '/conversations/$conversationId/participants',
      body: payload,
    );
  }

  Future<dynamic> removeParticipant(String conversationId, String userId) {
    return _client.delete(
      '/conversations/$conversationId/participants/$userId',
    );
  }

  Future<dynamic> updateParticipantRole(
    String conversationId,
    String userId,
    Map<String, dynamic> payload,
  ) {
    return _client.patch(
      '/conversations/$conversationId/participants/$userId/role',
      body: payload,
    );
  }

  Future<dynamic> markAsRead(
    String conversationId,
    String userId,
    Map<String, dynamic> payload,
  ) {
    return _client.patch(
      '/conversations/$conversationId/participants/$userId/read',
      body: payload,
    );
  }

  Future<dynamic> markAsDelivered(
    String conversationId,
    String userId,
    Map<String, dynamic> payload,
  ) {
    return _client.patch(
      '/conversations/$conversationId/participants/$userId/delivered',
      body: payload,
    );
  }
}
