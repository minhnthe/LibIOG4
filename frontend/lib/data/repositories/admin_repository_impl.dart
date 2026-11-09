import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';
import '../models/checkin_result_model.dart';
import '../models/occupancy_stats_model.dart';
import '../models/report_data_model.dart';
import '../models/system_config_model.dart';
import '../models/user_admin_model.dart';

class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDataSource remoteDataSource;

  AdminRepositoryImpl({AdminRemoteDataSource? remoteDataSource})
      : remoteDataSource = remoteDataSource ?? AdminRemoteDataSource();

  @override
  Future<Map<String, dynamic>> login(String studentId, String password) {
    return remoteDataSource.login(studentId, password);
  }

  @override
  Future<SystemConfigModel> getConfig() {
    return remoteDataSource.getConfigs();
  }

  @override
  Future<void> saveConfig(Map<String, dynamic> config) {
    return remoteDataSource.updateConfigs(config);
  }

  @override
  Future<OccupancyStatsModel> getRealtimeOccupancy() {
    return remoteDataSource.getRealtimeOccupancy();
  }

  @override
  Future<bool> forceCheckOut(String userId) {
    return remoteDataSource.forceCheckOut(userId);
  }

  @override
  Future<CheckInResultModel> processScan(String qrPayload, {String? deviceId}) {
    return remoteDataSource.submitScan(qrPayload, deviceId: deviceId);
  }

  @override
  Future<List<UserAdminModel>> getUsers({String? search, String? status}) {
    return remoteDataSource.getUsers(search: search, status: status);
  }

  @override
  Future<UserAdminModel> toggleUserStatus(String userId, String currentStatus) {
    final isLocked = currentStatus.toLowerCase() == 'locked' || currentStatus.toUpperCase() == 'BLOCKED';
    final nextStatus = isLocked ? 'active' : 'locked';
    return remoteDataSource.updateUserStatus(userId, nextStatus);
  }

  @override
  Future<ReportDataModel> getReport({String groupBy = 'hour', String? from, String? to}) {
    return remoteDataSource.getCheckinReport(groupBy: groupBy, from: from, to: to);
  }

  @override
  Future<String> exportCsv({String? from, String? to}) {
    return remoteDataSource.exportReportCsv(from: from, to: to);
  }
}
