import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Dịch vụ quản lý FCM Device Token và đồng bộ với Backend
class FcmService {
  static const String _kCachedTokenKey = 'fcm_device_token';

  /// Gửi FCM registration token lên Backend lưu vào MongoDB `users.device_token`
  static Future<bool> registerDeviceToken({
    required String deviceToken,
    String? authToken,
  }) async {
    if (deviceToken.trim().isEmpty) return false;

    try {
      String? token = authToken;
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('auth_token');
      }

      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Chưa có auth token, lưu tạm token vào local storage');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCachedTokenKey, deviceToken);
        return false;
      }

      final res = await http.post(
        Uri.parse(AppConstants.userRegisterDeviceEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'deviceToken': deviceToken.trim(),
        }),
      );

      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCachedTokenKey, deviceToken.trim());
        debugPrint('[FCM] Đã đồng bộ device_token với backend thành công');
        return true;
      } else {
        debugPrint('[FCM] Backend trả lỗi đăng ký token: ${res.statusCode} - ${res.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[FCM] Lỗi kết nối đăng ký device_token: $e');
      return false;
    }
  }

  /// Lấy token đã lưu trữ
  static Future<String?> getCachedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCachedTokenKey);
  }

  /// Xóa token khỏi bộ nhớ cục bộ khi đăng xuất
  static Future<void> clearCachedToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCachedTokenKey);
  }

  /// Tự động đồng bộ lại token còn trong cache sau khi đăng nhập thành công
  static Future<void> syncCachedTokenAfterLogin(String authToken) async {
    final cached = await getCachedToken();
    if (cached != null && cached.isNotEmpty) {
      await registerDeviceToken(deviceToken: cached, authToken: authToken);
    }
  }
}
