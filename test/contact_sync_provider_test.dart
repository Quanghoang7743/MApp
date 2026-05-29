import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mess_app/models/device_contact_phone.dart';
import 'package:mess_app/models/resolved_contact_suggestion.dart';
import 'package:mess_app/providers/contact_sync_provider.dart';
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
  FakeDeviceContactsService({
    required this.status,
    this.requestedStatus,
    this.supported = true,
    this.contacts = const [],
  });

  ContactPermissionState status;
  ContactPermissionState? requestedStatus;
  bool supported;
  List<DeviceContactPhone> contacts;
  int requestPermissionCalls = 0;
  int getAllContactsCalls = 0;

  @override
  bool get isSupportedPlatform => supported;

  @override
  Future<ContactPermissionState> getPermissionStatus() async => status;

  @override
  Future<ContactPermissionState> requestPermission() async {
    requestPermissionCalls++;
    status = requestedStatus ?? status;
    return status;
  }

  @override
  Future<List<DeviceContactPhone>> getAllPhoneContacts() async {
    getAllContactsCalls++;
    return contacts;
  }
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_URL=https://moxchat-production.up.railway.app',
    );
  });

  group('ContactSyncProvider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initialize enables pre-permission prompt on first launch', () async {
      final fakeService = FakeDeviceContactsService(
        status: ContactPermissionState.notDetermined,
      );
      final provider = ContactSyncProvider(
        contactsService: fakeService,
        nowProvider: () => DateTime.utc(2026, 5, 29, 10),
      );

      await provider.initialize();

      expect(provider.shouldShowPrePermissionPrompt, true);
      expect(provider.hasHandledPrePermissionPrompt, false);
    });

    test('markPrePermissionPromptHandled persists prompt decision', () async {
      final fakeService = FakeDeviceContactsService(
        status: ContactPermissionState.notDetermined,
      );
      final provider = ContactSyncProvider(
        contactsService: fakeService,
        nowProvider: () => DateTime.utc(2026, 5, 29, 10),
      );

      await provider.initialize();
      await provider.markPrePermissionPromptHandled();

      expect(provider.shouldShowPrePermissionPrompt, false);
      expect(provider.hasHandledPrePermissionPrompt, true);
    });

    test('requestContactsAccess updates permission state', () async {
      final fakeService = FakeDeviceContactsService(
        status: ContactPermissionState.denied,
        requestedStatus: ContactPermissionState.granted,
      );
      final provider = ContactSyncProvider(
        contactsService: fakeService,
        nowProvider: () => DateTime.utc(2026, 5, 29, 10),
      );

      final granted = await provider.requestContactsAccess();

      expect(granted, true);
      expect(provider.permissionState, ContactPermissionState.granted);
      expect(fakeService.requestPermissionCalls, 1);
    });

    test('loadAndResolveContacts reuses cached lookups within TTL', () async {
      var resolveCalls = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/friends/resolve-by-phone') {
          resolveCalls++;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'user': {
                  'id': '10',
                  'phone_number': '0912345678',
                  'name': 'Alice',
                },
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        if (request.url.path == '/api/friends') {
          return http.Response(jsonEncode({'data': []}), 200);
        }

        if (request.url.path == '/api/friend-requests/incoming' ||
            request.url.path == '/api/friend-requests/outgoing') {
          return http.Response(jsonEncode({'data': []}), 200);
        }

        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final mockApi = MockApiServices(
        client: apiClient,
        friends: FriendsApi(apiClient),
      );

      final fakeService = FakeDeviceContactsService(
        status: ContactPermissionState.granted,
        contacts: const [
          DeviceContactPhone(
            displayName: 'Alice',
            rawPhone: '0912 345 678',
            normalizedPhone: '912345678',
          ),
        ],
      );

      final provider = ContactSyncProvider(
        contactsService: fakeService,
        nowProvider: () => DateTime.utc(2026, 5, 29, 10),
      )..bindApi(mockApi);

      await provider.loadAndResolveContacts();
      await provider.loadAndResolveContacts();

      expect(resolveCalls, 1);
      expect(provider.suggestions, hasLength(1));
      expect(
        provider.suggestions.first.status,
        ResolvedContactSuggestionStatus.canInvite,
      );
    });
  });
}
