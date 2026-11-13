import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'Hệ Thống Ra Vào Thư Viện';
  static const String dbName = 'library_offline.db';
  static const int dbVersion = 1;

  // Hỗ trợ override Base URL khi test trên thiết bị thật qua mạng LAN
  static String? _customBaseUrl;
  static void setCustomBaseUrl(String? url) {
    _customBaseUrl = url;
  }

  /// Tự động nhận diện Base URL theo từng môi trường thực thi:
  /// - Web / Windows Desktop / iOS Simulator: http://localhost:5000/api
  /// - Android Emulator: Tự động chuyển localhost/127.0.0.1 sang 10.0.2.2:5000/api
  /// - Thiết bị thật: IP mạng LAN do cấu hình trong .env hoặc _customBaseUrl
  static String get baseUrl {
    String url = 'https://libiog4.onrender.com/api';

    if (_customBaseUrl != null && _customBaseUrl!.trim().isNotEmpty) {
      url = _customBaseUrl!.trim();
    } else {
      try {
        if (dotenv.isInitialized) {
          final envUrl = dotenv.env['API_BASE_URL'];
          if (envUrl != null && envUrl.trim().isNotEmpty) {
            url = envUrl.trim();
          }
        }
      } catch (_) {}
    }

    // Tự động chuyển đổi localhost sang 10.0.2.2 khi chạy trên máy ảo Android (Android Emulator)
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid &&
            (url.contains('localhost') || url.contains('127.0.0.1'))) {
          url = url
              .replaceAll('localhost', '10.0.2.2')
              .replaceAll('127.0.0.1', '10.0.2.2');
        }
      } catch (_) {}
    }

    return url;
  }

  // Auth endpoints
  static String get authEndpoint => '$baseUrl/auth';
  static String get authLogin => '$baseUrl/auth/login';
  static String get authChangePassword => '$baseUrl/auth/change-password';
  static String get authRegister => '$baseUrl/auth/register';

  // Config endpoints
  static String get configEndpoint => '$baseUrl/config';
  static String get adminConfigEndpoint => '$baseUrl/admin/config';

  // Checkin & Scanner endpoints
  static String get logsEndpoint =>
      '$baseUrl/checkin'; // Alias cho RemoteApiService
  static String get checkinEndpoint => '$baseUrl/checkin';
  static String get checkinSyncEndpoint => '$baseUrl/checkin/sync';
  static String get checkinStatusEndpoint => '$baseUrl/checkin/current-status';

  // User endpoints
  static String get userMeEndpoint => '$baseUrl/users/me';
  static String get userMeQrEndpoint => '$baseUrl/users/me/qr';
  static String get userRegisterDeviceEndpoint =>
      '$baseUrl/users/register-device';

  // Admin management & reports endpoints
  static String get adminUsersEndpoint => '$baseUrl/admin/users';
  static String get adminGatesEndpoint => '$baseUrl/admin/gates';
  static String get adminRealtimePresent => '$baseUrl/admin/realtime/present';
  static String get adminRealtimeStats => '$baseUrl/admin/realtime/stats';
  static String get adminReportsCheckin => '$baseUrl/admin/reports/checkin';
  static String get adminReportsLogs => '$baseUrl/admin/reports/logs';
  static String get adminReportsExport => '$baseUrl/admin/reports/export';
  static String adminForceCheckout(String userId) =>
      '$baseUrl/admin/realtime/checkout/$userId';
}
