import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/environment.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userStr = prefs.getString('auth_user');
    if (userStr != null) {
      _user = jsonDecode(userStr);
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Returns null if login is successful, or an error message if failed.
  Future<String?> login(
    String phone,
    String password,
    bool stayLoggedIn,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${Environment.baseUrl}/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'phone_number': phone, 'password': password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        // Cố gắng tự động lấy token từ root hoặc `data` nếu có
        _token =
            body['token'] ??
            body['access_token'] ??
            (body['data'] != null
                ? (body['data']['token'] ?? body['data']['access_token'])
                : null);
        _user =
            body['user'] ??
            (body['data'] != null ? body['data']['user'] : null);

        if (_token == null) {
          print(
            'Warning: Không tìm thấy trường token hoặc access_token trong phản hồi đăng nhập!',
          );
        }

        if (stayLoggedIn && _token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', _token!);
          if (_user != null) {
            await prefs.setString('auth_user', jsonEncode(_user));
          }
        }
        notifyListeners();
        return null; // Thành công
      } else {
        try {
          final body = jsonDecode(response.body);
          return body['message'] ??
              'Đăng nhập thất bại (Mã: ${response.statusCode})';
        } catch (_) {
          return 'Đăng nhập thất bại (Mã: ${response.statusCode})';
        }
      }
    } catch (e) {
      return 'Lỗi kết nối: $e';
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    notifyListeners();
  }
}
