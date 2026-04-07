import '../api_client.dart';

class FriendsApi {
  FriendsApi(this._client);

  final ApiClient _client;

  Future<dynamic> resolveByPhone({required String phoneNumber}) {
    return _client.post(
      '/friends/resolve-by-phone',
      body: {'phone_number': phoneNumber},
    );
  }

  Future<dynamic> sendFriendRequest(Map<String, dynamic> payload) {
    return _client.post('/friend-requests', body: payload);
  }

  Future<dynamic> getIncomingFriendRequests() {
    return _client.get('/friend-requests/incoming');
  }

  Future<dynamic> getOutgoingFriendRequests() {
    return _client.get('/friend-requests/outgoing');
  }

  Future<dynamic> acceptFriendRequest(String requestId) {
    return _client.patch('/friend-requests/$requestId/accept');
  }

  Future<dynamic> rejectFriendRequest(String requestId) {
    return _client.patch('/friend-requests/$requestId/reject');
  }

  Future<dynamic> cancelFriendRequest(String requestId) {
    return _client.delete('/friend-requests/$requestId');
  }

  Future<dynamic> getFriends() {
    return _client.get('/friends');
  }

  Future<dynamic> unfriend(String userId) {
    return _client.delete('/friends/$userId');
  }
}
