import 'dart:convert';

import 'package:http/http.dart' as http;

import 'environment.dart';

class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message, this.data});

  final int statusCode;
  final String message;
  final dynamic data;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({http.Client? httpClient, this.tokenProvider})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Future<String?> Function()? tokenProvider;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('${Environment.baseUrl}$path');
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  Future<Map<String, String>> _headers({bool includeJson = true}) async {
    final headers = <String, String>{'Accept': 'application/json'};

    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }

    final token = await tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  dynamic _handleResponse(http.Response response) {
    final decoded = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = 'Request failed with status ${response.statusCode}';
    if (decoded is Map<String, dynamic> && decoded['message'] != null) {
      message = decoded['message'].toString();
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      data: decoded,
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final response = await _httpClient.get(
      _uri(path, query),
      headers: await _headers(includeJson: false),
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final response = await _httpClient.put(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final response = await _httpClient.patch(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    final request = http.Request('DELETE', _uri(path));
    request.headers.addAll(await _headers());
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }
}
