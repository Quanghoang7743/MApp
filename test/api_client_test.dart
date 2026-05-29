import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mess_app/services/api_client.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_URL=https://moxchat-production.up.railway.app');
  });

  group('ApiClient Tests', () {
    test('GET request success', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/test');
        return http.Response(jsonEncode({'success': true, 'data': 'hello'}), 200);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final response = await apiClient.get('/test');

      expect(response, isMap);
      expect(response['success'], true);
      expect(response['data'], 'hello');
    });

    test('POST request success', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/test-post');
        final body = jsonDecode(request.body);
        expect(body['name'], 'quang');
        return http.Response(jsonEncode({'created': true}), 201);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final response = await apiClient.post('/test-post', body: {'name': 'quang'});

      expect(response['created'], true);
    });

    test('PUT request success', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/test-put');
        final body = jsonDecode(request.body);
        expect(body['id'], '123');
        return http.Response(jsonEncode({'updated': true}), 200);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final response = await apiClient.put('/test-put', body: {'id': '123'});

      expect(response['updated'], true);
    });

    test('DELETE request success', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/test-delete');
        return http.Response(jsonEncode({'deleted': true}), 200);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final response = await apiClient.delete('/test-delete');

      expect(response['deleted'], true);
    });

    test('Request headers injection with Auth Token', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer my_secret_token');
        expect(request.headers['Accept'], 'application/json');
        return http.Response(jsonEncode({'auth': true}), 200);
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenProvider: () async => 'my_secret_token',
      );

      final response = await apiClient.get('/test-auth');
      expect(response['auth'], true);
    });

    test('Throws ApiException on error response status code', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Unauthorized request'}), 401);
      });

      final apiClient = ApiClient(httpClient: mockClient);

      expect(
        () async => await apiClient.get('/secure-data'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Unauthorized request'),
        ),
      );
    });
  });
}
