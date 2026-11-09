import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../models/checkin_result_model.dart';
import '../models/occupancy_stats_model.dart';
import '../models/report_data_model.dart';
import '../models/system_config_model.dart';
import '../models/user_admin_model.dart';

class AdminRemoteDataSource {
  final http.Client client;
  static String? _cachedToken;

  AdminRemoteDataSource({http.Client? client}) : client = client ?? http.Client();

  static void setAuthToken(String? token) {
    _cachedToken = token;
  }

  Future<String?> _getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth) {
      final token = await _getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ── Auth ──
  Future<Map<String, dynamic>> login(String studentId, String password) async {
    final response = await client.post(
      Uri.parse(AppConstants.authLogin),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'studentId': studentId, 'password': password}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final token = data['accessToken']?.toString();
      if (token != null) {
        _cachedToken = token;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
        } catch (_) {}
      }
      return data;
    }
    throw Exception(body['message'] ?? 'Đăng nhập thất bại');
  }

  // ── Feature 1: Cấu hình hệ thống ──
  Future<SystemConfigModel> getConfigs() async {
    final response = await client.get(
      Uri.parse(AppConstants.configEndpoint),
      headers: await _headers(requiresAuth: false),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>? ?? {};
      return SystemConfigModel.fromJson(data);
    }
    throw Exception('Không thể tải cấu hình hệ thống: ${response.statusCode}');
  }

  Future<void> updateConfigs(Map<String, dynamic> data) async {
    final response = await client.put(
      Uri.parse(AppConstants.adminConfigEndpoint),
      headers: await _headers(requiresAuth: true),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(json?['message'] ?? 'Cập nhật cấu hình thất bại');
    }
  }

  // ── Feature 2: Giám sát thời gian thực ──
  Future<OccupancyStatsModel> getRealtimeOccupancy() async {
    // 1. Gọi /api/admin/realtime/present
    final presentRes = await client.get(
      Uri.parse(AppConstants.adminRealtimePresent),
      headers: await _headers(requiresAuth: true),
    );

    if (presentRes.statusCode != 200) {
      throw Exception('Không thể tải danh sách đang có mặt: ${presentRes.statusCode}');
    }

    final presentJson = jsonDecode(presentRes.body) as Map<String, dynamic>;
    final presentData = presentJson['data'] as Map<String, dynamic>? ?? {};

    // 2. Gọi /api/admin/realtime/stats
    int totalToday = 0;
    int peak = 0;
    String? peakTime;

    try {
      final statsRes = await client.get(
        Uri.parse(AppConstants.adminRealtimeStats),
        headers: await _headers(requiresAuth: true),
      );
      if (statsRes.statusCode == 200) {
        final statsJson = jsonDecode(statsRes.body) as Map<String, dynamic>;
        final statsData = statsJson['data'] as Map<String, dynamic>? ?? {};
        totalToday = int.tryParse(statsData['totalVisitsToday']?.toString() ?? '0') ?? 0;
        peak = int.tryParse(statsData['peakOccupancy']?.toString() ?? '0') ?? 0;
        peakTime = statsData['peakTime']?.toString();
      }
    } catch (_) {}

    final occupancy = OccupancyStatsModel.fromJson(presentData).copyWith(
      totalVisitsToday: totalToday,
      peakOccupancy: peak,
      peakTime: peakTime,
    );

    return occupancy;
  }

  Future<bool> forceCheckOut(String userId) async {
    final response = await client.post(
      Uri.parse(AppConstants.adminForceCheckout(userId)),
      headers: await _headers(requiresAuth: true),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['success'] == true;
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(body?['message'] ?? 'Cưỡng chế check-out thất bại');
  }

  // ── Feature 3: Trạm quét QR & Nhập tay ──
  Future<CheckInResultModel> submitScan(String qrPayload, {String? deviceId}) async {
    final response = await client.post(
      Uri.parse(AppConstants.checkinEndpoint),
      headers: await _headers(requiresAuth: true),
      body: jsonEncode({
        'qrPayload': qrPayload,
        'deviceId': deviceId ?? 'LIBRARIAN_STATION',
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      return CheckInResultModel.fromJson(data);
    }

    final message = body['message']?.toString() ?? 'Quét thẻ không thành công';
    final errorCode = body['errorCode']?.toString() ?? 'UNKNOWN_ERROR';
    throw Exception('[$errorCode] $message');
  }

  // ── Feature 4: Quản lý thành viên ──
  Future<List<UserAdminModel>> getUsers({
    String? search,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse(AppConstants.adminUsersEndpoint).replace(queryParameters: queryParams);
    final response = await client.get(uri, headers: await _headers(requiresAuth: true));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>? ?? [];
      return list.map((e) => UserAdminModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Không thể tải danh sách thành viên: ${response.statusCode}');
  }

  Future<UserAdminModel> updateUserStatus(String userId, String status) async {
    final uri = Uri.parse('${AppConstants.adminUsersEndpoint}/$userId/status');
    final response = await client.patch(
      uri,
      headers: await _headers(requiresAuth: true),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      return UserAdminModel.fromJson(data);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>?;
    throw Exception(body?['message'] ?? 'Cập nhật trạng thái thất bại');
  }

  // ── Feature 5: Thống kê & Báo cáo ──
  Future<ReportDataModel> getCheckinReport({
    String groupBy = 'hour',
    String? from,
    String? to,
  }) async {
    final queryParams = <String, String>{'groupBy': groupBy};
    if (from != null) queryParams['from'] = from;
    if (to != null) queryParams['to'] = to;

    final uri = Uri.parse(AppConstants.adminReportsCheckin).replace(queryParameters: queryParams);
    final response = await client.get(uri, headers: await _headers(requiresAuth: true));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      return ReportDataModel.fromJson(data);
    }
    throw Exception('Không thể tải báo cáo thống kê: ${response.statusCode}');
  }

  Future<String> exportReportCsv({String? from, String? to}) async {
    final queryParams = <String, String>{'format': 'csv'};
    if (from != null) queryParams['from'] = from;
    if (to != null) queryParams['to'] = to;

    final uri = Uri.parse(AppConstants.adminReportsExport).replace(queryParameters: queryParams);
    final response = await client.get(
      uri,
      headers: {
        'Accept': 'text/csv',
        ...await _headers(requiresAuth: true),
      },
    );

    if (response.statusCode == 200) {
      return response.body;
    }
    throw Exception('Không thể xuất báo cáo CSV: ${response.statusCode}');
  }
}
