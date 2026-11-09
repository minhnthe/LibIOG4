import '../../data/models/checkin_result_model.dart';
import '../../data/models/occupancy_stats_model.dart';
import '../../data/models/report_data_model.dart';
import '../../data/models/system_config_model.dart';
import '../../data/models/user_admin_model.dart';

abstract class AdminRepository {
  // Auth
  Future<Map<String, dynamic>> login(String studentId, String password);

  // Feature 1: Cấu hình hệ thống
  Future<SystemConfigModel> getConfig();
  Future<void> saveConfig(Map<String, dynamic> config);

  // Feature 2: Giám sát thời gian thực & Check-out cưỡng chế
  Future<OccupancyStatsModel> getRealtimeOccupancy();
  Future<bool> forceCheckOut(String userId);

  // Feature 3: Trạm quét QR & Nhập tay
  Future<CheckInResultModel> processScan(String qrPayload, {String? deviceId});

  // Feature 4: Quản lý thành viên & Khóa thẻ
  Future<List<UserAdminModel>> getUsers({String? search, String? status});
  Future<UserAdminModel> toggleUserStatus(String userId, String currentStatus);

  // Feature 5: Biểu đồ thống kê & Xuất CSV
  Future<ReportDataModel> getReport({String groupBy = 'hour', String? from, String? to});
  Future<String> exportCsv({String? from, String? to});
}
