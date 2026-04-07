import '../api_client.dart';

class BroadcastingApi {
  BroadcastingApi(this._client);

  final ApiClient _client;

  Future<dynamic> authorizeChannel(Map<String, dynamic> payload) {
    return _client.post('/broadcasting/auth', body: payload);
  }
}
