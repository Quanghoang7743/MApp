import '../api_client.dart';

class DevicesApi {
  DevicesApi(this._client);

  final ApiClient _client;

  Future<dynamic> getDevices() {
    return _client.get('/devices');
  }

  Future<dynamic> createDevice(Map<String, dynamic> payload) {
    return _client.post('/devices', body: payload);
  }

  Future<dynamic> getDeviceById(String id) {
    return _client.get('/devices/$id');
  }

  Future<dynamic> updateDevice(String id, Map<String, dynamic> payload) {
    return _client.put('/devices/$id', body: payload);
  }

  Future<dynamic> deleteDevice(String id) {
    return _client.delete('/devices/$id');
  }

  Future<dynamic> deactivateDevice(String id) {
    return _client.patch('/devices/$id/deactivate');
  }

  Future<dynamic> activateDevice(String id) {
    return _client.patch('/devices/$id/activate');
  }

  Future<dynamic> updateLastActive(String id, Map<String, dynamic> payload) {
    return _client.patch('/devices/$id/last-active', body: payload);
  }
}
