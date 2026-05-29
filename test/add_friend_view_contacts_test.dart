import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:mess_app/Views/widgets/contact_widgets/addfriend_view.dart';
import 'package:mess_app/models/device_contact_phone.dart';
import 'package:mess_app/models/resolved_contact_suggestion.dart';
import 'package:mess_app/providers/contact_sync_provider.dart';
import 'package:mess_app/providers/friend_provider.dart';
import 'package:mess_app/services/api_client.dart';
import 'package:mess_app/services/api_services.dart';
import 'package:mess_app/services/apis/friends_api.dart';
import 'package:mess_app/services/device_contacts_service.dart';

class MockApiServices implements ApiServices {
  MockApiServices({required this.client, required this.friends});

  @override
  final ApiClient client;

  @override
  final FriendsApi friends;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDeviceContactsService extends DeviceContactsService {
  FakeDeviceContactsService({required this.status, this.contacts = const []});

  ContactPermissionState status;
  List<DeviceContactPhone> contacts;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<ContactPermissionState> getPermissionStatus() async => status;

  @override
  Future<List<DeviceContactPhone>> getAllPhoneContacts() async => contacts;
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_URL=https://moxchat-production.up.railway.app',
    );
  });

  testWidgets('renders contacts suggestion section with synced result', (
    WidgetTester tester,
  ) async {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/friend-requests/incoming' ||
          request.url.path == '/api/friend-requests/outgoing') {
        return http.Response(jsonEncode({'data': []}), 200);
      }
      return http.Response(jsonEncode({'data': []}), 200);
    });

    final apiClient = ApiClient(httpClient: mockClient);
    final mockApi = MockApiServices(
      client: apiClient,
      friends: FriendsApi(apiClient),
    );

    final friendProvider = FriendProvider()..bindApi(mockApi);
    final contactSyncProvider = ContactSyncProvider(
      contactsService: FakeDeviceContactsService(
        status: ContactPermissionState.granted,
        contacts: const [
          DeviceContactPhone(
            displayName: 'Alice',
            rawPhone: '0912 345 678',
            normalizedPhone: '912345678',
          ),
        ],
      ),
      nowProvider: () => DateTime.utc(2026, 5, 29, 10),
    )..bindApi(mockApi);

    contactSyncProvider.permissionState = ContactPermissionState.granted;
    contactSyncProvider.contacts = const [
      DeviceContactPhone(
        displayName: 'Alice',
        rawPhone: '0912 345 678',
        normalizedPhone: '912345678',
      ),
    ];
    contactSyncProvider.suggestions = const [
      ResolvedContactSuggestion(
        contact: DeviceContactPhone(
          displayName: 'Alice',
          rawPhone: '0912 345 678',
          normalizedPhone: '912345678',
        ),
        status: ResolvedContactSuggestionStatus.canInvite,
        resolvedUser: {'id': '10', 'name': 'Alice User'},
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
          ChangeNotifierProvider<ContactSyncProvider>.value(
            value: contactSyncProvider,
          ),
        ],
        child: const MaterialApp(home: AddFriendView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gợi ý từ danh bạ'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Gửi lời mời'), findsWidgets);
  });
}
