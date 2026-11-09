import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  ApiException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client client;
  static String? _token;

  ApiClient({http.Client? client}) : client = client ?? http.Client();

  static void setToken(String? token) {
    _token = token;
  }

  static String? get token => _token;

  static Future<String?> getToken() async {
    if (_token != null && _token!.isNotEmpty) {
      return _token;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      return _token;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
    } catch (_) {}
  }

  Future<Map<String, String>> _buildHeaders({
    bool requiresAuth = true,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth) {
      final t = await getToken();
      if (t != null && t.isNotEmpty) {
        headers['Authorization'] = 'Bearer $t';
      }
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<http.Response> get(
    Uri uri, {
    bool requiresAuth = true,
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = await _buildHeaders(requiresAuth: requiresAuth, extraHeaders: headers);
    return await client.get(uri, headers: mergedHeaders);
  }

  Future<http.Response> post(
    Uri uri, {
    Object? body,
    bool requiresAuth = true,
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = await _buildHeaders(requiresAuth: requiresAuth, extraHeaders: headers);
    final encodedBody = body is String || body == null ? body : jsonEncode(body);
    return await client.post(uri, headers: mergedHeaders, body: encodedBody);
  }

  Future<http.Response> put(
    Uri uri, {
    Object? body,
    bool requiresAuth = true,
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = await _buildHeaders(requiresAuth: requiresAuth, extraHeaders: headers);
    final encodedBody = body is String || body == null ? body : jsonEncode(body);
    return await client.put(uri, headers: mergedHeaders, body: encodedBody);
  }

  Future<http.Response> patch(
    Uri uri, {
    Object? body,
    bool requiresAuth = true,
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = await _buildHeaders(requiresAuth: requiresAuth, extraHeaders: headers);
    final encodedBody = body is String || body == null ? body : jsonEncode(body);
    return await client.patch(uri, headers: mergedHeaders, body: encodedBody);
  }

  Future<http.Response> delete(
    Uri uri, {
    Object? body,
    bool requiresAuth = true,
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = await _buildHeaders(requiresAuth: requiresAuth, extraHeaders: headers);
    final encodedBody = body is String || body == null ? body : jsonEncode(body);
    return await client.delete(uri, headers: mergedHeaders, body: encodedBody);
  }
}
