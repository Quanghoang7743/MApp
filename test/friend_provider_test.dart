import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mess_app/providers/friend_provider.dart';
import 'package:mess_app/services/api_client.dart';
import 'package:mess_app/services/api_services.dart';
import 'package:mess_app/services/apis/friends_api.dart';

class MockApiServices implements ApiServices {
  MockApiServices({required this.client, required this.friends});

  @override
  final ApiClient client;
  
  @override
  final FriendsApi friends;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_URL=https://moxchat-production.up.railway.app');
  });

  group('FriendProvider Tests', () {
    test('bindApi binds the API service', () {
      final provider = FriendProvider();
      final client = ApiClient();
      final api = ApiServices();
      
      provider.bindApi(api);
      // If we bound it successfully, no errors are thrown
    });

    test('resolveByPhone success updates resolvedUser and clears error', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/friends/resolve-by-phone');
        final body = jsonDecode(request.body);
        expect(body['phone_number'], '0987654321');

        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'user': {'id': '10', 'phone_number': '0987654321', 'name': 'Test User'}
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(httpClient: mockHttpClient);
      final friendsApi = FriendsApi(apiClient);
      final mockApi = MockApiServices(client: apiClient, friends: friendsApi);

      final provider = FriendProvider()..bindApi(mockApi);
      await provider.resolveByPhone('0987654321');

      expect(provider.isResolving, false);
      expect(provider.errorMessage, isNull);
      expect(provider.resolvedUser, isNotNull);
      expect(provider.resolvedUser!['id'], '10');
      expect(provider.resolvedUser!['name'], 'Test User');
    });

    test('resolveByPhone failure sets error and clears user', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'message': 'Không tìm thấy người dùng'})),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(httpClient: mockHttpClient);
      final friendsApi = FriendsApi(apiClient);
      final mockApi = MockApiServices(client: apiClient, friends: friendsApi);

      final provider = FriendProvider()..bindApi(mockApi);
      provider.resolvedUser = {'id': 'existing'};

      await provider.resolveByPhone('0000000000');

      expect(provider.isResolving, false);
      expect(provider.errorMessage, 'Không tìm thấy người dùng');
      expect(provider.resolvedUser, isNull);
    });

    test('sendFriendRequest success triggers fetchOutgoingRequests', () async {
      int apiCallsCount = 0;
      final mockHttpClient = MockClient((request) async {
        apiCallsCount++;
        if (request.url.path == '/api/friend-requests' && request.method == 'POST') {
          final body = jsonDecode(request.body);
          expect(body['receiver_id'], 'user_id_123');
          return http.Response(jsonEncode({'success': true}), 200);
        } else if (request.url.path == '/api/friend-requests/outgoing' && request.method == 'GET') {
          return http.Response(jsonEncode({
            'data': [
              {'id': 'req_abc', 'receiver_id': 'user_id_123'}
            ]
          }), 200);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockHttpClient);
      final friendsApi = FriendsApi(apiClient);
      final mockApi = MockApiServices(client: apiClient, friends: friendsApi);

      final provider = FriendProvider()..bindApi(mockApi);
      final result = await provider.sendFriendRequest(receiverId: 'user_id_123');

      expect(result, true);
      expect(provider.isSendingRequest, false);
      expect(provider.errorMessage, isNull);
      expect(provider.outgoingRequests, hasLength(1));
      expect(provider.outgoingRequests.first['id'], 'req_abc');
      expect(apiCallsCount, 2); // 1 to send, 1 to fetch outgoing
    });

    test('fetchIncomingRequests success updates incomingRequests list', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, '/api/friend-requests/incoming');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'data': [
              {'id': 'req_1', 'sender': {'id': 'user_a', 'name': 'User A'}}
            ]
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(httpClient: mockHttpClient);
      final friendsApi = FriendsApi(apiClient);
      final mockApi = MockApiServices(client: apiClient, friends: friendsApi);

      final provider = FriendProvider()..bindApi(mockApi);
      await provider.fetchIncomingRequests();

      expect(provider.isLoadingIncoming, false);
      expect(provider.errorMessage, isNull);
      expect(provider.incomingRequests, hasLength(1));
      expect(provider.incomingRequests.first['id'], 'req_1');
    });

    test('acceptRequest success and fetches incoming requests', () async {
      int apiCallsCount = 0;
      final mockHttpClient = MockClient((request) async {
        apiCallsCount++;
        if (request.url.path == '/api/friend-requests/req_123/accept' && request.method == 'PATCH') {
          return http.Response(jsonEncode({'success': true}), 200);
        } else if (request.url.path == '/api/friend-requests/incoming' && request.method == 'GET') {
          return http.Response(jsonEncode({'data': []}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockHttpClient);
      final friendsApi = FriendsApi(apiClient);
      final mockApi = MockApiServices(client: apiClient, friends: friendsApi);

      final provider = FriendProvider()..bindApi(mockApi);
      final result = await provider.acceptRequest('req_123');

      expect(result, true);
      expect(provider.isProcessingRequest, false);
      expect(provider.incomingRequests, isEmpty);
      expect(apiCallsCount, 2);
    });

    test('rejectRequest success and fetches incoming requests', () async {
      int apiCallsCount = 0;
      final mockHttpClient = MockClient((request) async {
        apiCallsCount++;
        if (request.url.path == '/api/friend-requests/req_123/reject' && request.method == 'PATCH') {
          return http.Response(jsonEncode({'success': true}), 200);
        } else if (request.url.path == '/api/friend-requests/incoming' && request.method == 'GET') {
          return http.Response(jsonEncode({'data': []}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockHttpClient);
      final friendsApi = FriendsApi(apiClient);
      final mockApi = MockApiServices(client: apiClient, friends: friendsApi);

      final provider = FriendProvider()..bindApi(mockApi);
      final result = await provider.rejectRequest('req_123');

      expect(result, true);
      expect(provider.isProcessingRequest, false);
      expect(provider.incomingRequests, isEmpty);
      expect(apiCallsCount, 2);
    });

    test('cancelRequest success and fetches outgoing requests', () async {
      int apiCallsCount = 0;
      final mockHttpClient = MockClient((request) async {
        apiCallsCount++;
        if (request.url.path == '/api/friend-requests/req_123' && request.method == 'DELETE') {
          return http.Response(jsonEncode({'success': true}), 200);
        } else if (request.url.path == '/api/friend-requests/outgoing' && request.method == 'GET') {
          return http.Response(jsonEncode({'data': []}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockHttpClient);
      final friendsApi = FriendsApi(apiClient);
      final mockApi = MockApiServices(client: apiClient, friends: friendsApi);

      final provider = FriendProvider()..bindApi(mockApi);
      final result = await provider.cancelRequest('req_123');

      expect(result, true);
      expect(provider.isProcessingRequest, false);
      expect(provider.outgoingRequests, isEmpty);
      expect(apiCallsCount, 2);
    });

    test('unfriend success', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/friends/user_xyz');
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final apiClient = ApiClient(httpClient: mockHttpClient);
      final friendsApi = FriendsApi(apiClient);
      final mockApi = MockApiServices(client: apiClient, friends: friendsApi);

      final provider = FriendProvider()..bindApi(mockApi);
      final result = await provider.unfriend('user_xyz');

      expect(result, true);
      expect(provider.isProcessingRequest, false);
      expect(provider.errorMessage, isNull);
    });
  });
}
