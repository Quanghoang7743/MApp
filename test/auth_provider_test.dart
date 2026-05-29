import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mess_app/providers/auth_provider.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_URL=https://moxchat-production.up.railway.app');
  });

  group('AuthProvider Tests', () {
    test('Load saved credentials from SharedPreferences on initialization', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'saved_token_123',
        'auth_user': jsonEncode({'id': 1, 'name': 'Quang'}),
      });

      final authProvider = AuthProvider();
      
      // Wait for async loadFromPrefs to complete
      await Future.delayed(Duration(milliseconds: 50));

      expect(authProvider.token, 'saved_token_123');
      expect(authProvider.user?['name'], 'Quang');
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.isLoading, false);
    });

    test('Login success with stayLoggedIn = true', () async {
      SharedPreferences.setMockInitialValues({});

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/login');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'token': 'new_login_token',
            'user': {'id': 2, 'name': 'Khoi'}
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        final authProvider = AuthProvider();
        final error = await authProvider.login('0123456789', 'password123', true);

        expect(error, isNull);
        expect(authProvider.token, 'new_login_token');
        expect(authProvider.user?['name'], 'Khoi');
        expect(authProvider.isAuthenticated, true);

        // Verify it was stored in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('auth_token'), 'new_login_token');
        expect(prefs.getString('auth_user'), isNotNull);
      }, () => mockClient);
    });

    test('Login failure returns error message', () async {
      SharedPreferences.setMockInitialValues({});

      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'message': 'Sai số điện thoại hoặc mật khẩu'})),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        final authProvider = AuthProvider();
        final error = await authProvider.login('0123456789', 'wrong_pass', false);

        expect(error, 'Sai số điện thoại hoặc mật khẩu');
        expect(authProvider.token, isNull);
        expect(authProvider.user, isNull);
        expect(authProvider.isAuthenticated, false);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('auth_token'), isNull);
      }, () => mockClient);
    });

    test('Register success returns null', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/register');
        return http.Response.bytes(
          utf8.encode(jsonEncode({'success': true})),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        final authProvider = AuthProvider();
        final error = await authProvider.register('0123456789', 'Nam', 'password123');

        expect(error, isNull);
      }, () => mockClient);
    });

    test('Register failure returns error message', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'message': 'Số điện thoại đã tồn tại'})),
          422,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        final authProvider = AuthProvider();
        final error = await authProvider.register('0123456789', 'Nam', 'password123');

        expect(error, 'Số điện thoại đã tồn tại');
      }, () => mockClient);
    });

    test('Logout clears credentials and preferences', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'saved_token_123',
        'auth_user': jsonEncode({'id': 1, 'name': 'Quang'}),
      });

      final authProvider = AuthProvider();
      await Future.delayed(Duration(milliseconds: 50));

      expect(authProvider.isAuthenticated, true);

      await authProvider.logout();

      expect(authProvider.token, isNull);
      expect(authProvider.user, isNull);
      expect(authProvider.isAuthenticated, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('auth_user'), isNull);
    });
  });
}
