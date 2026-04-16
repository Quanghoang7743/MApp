import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/environment.dart';
import '../services/api_services.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  late final ApiServices api;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    api = ApiServices(tokenProvider: _resolveToken);
    _loadFromPrefs();
  }

  Future<String?> _resolveToken() async {
    if (_token != null && _token!.isNotEmpty) {
      return _token;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
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

  /// Returns null if register is successful, or an error message if failed.
  Future<String?> register(
    String phone,
    String gender,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${Environment.baseUrl}/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phone,
          'gender': gender,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; // Thành công
      } else {
        try {
          final body = jsonDecode(response.body);
          return body['message'] ??
              'Đăng ký thất bại (Mã: ${response.statusCode})';
        } catch (_) {
          return 'Đăng ký thất bại (Mã: ${response.statusCode})';
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
