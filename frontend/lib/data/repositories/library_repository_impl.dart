import '../../domain/repositories/library_repository.dart';
import '../datasources/local_db_helper.dart';
import '../datasources/remote_api_service.dart';
import '../models/user_model.dart';
import '../models/check_in_log_model.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  final LocalDbHelper localDbHelper;
  final RemoteApiService remoteApiService;

  LibraryRepositoryImpl({
    required this.localDbHelper,
    required this.remoteApiService,
  });

  @override
  Future<UserModel?> getUser(String id) async {
    return null;
  }

  @override
  Future<void> logCheckIn(CheckInLogModel log) async {
    final db = await localDbHelper.database;
    if (db != null) {
      await db.insert('check_in_logs', log.toJson());
    }
  }

  @override
  Future<List<CheckInLogModel>> getLogs() async {
    final db = await localDbHelper.database;
    if (db == null) return [];
    final maps = await db.query('check_in_logs');
    return maps.map((map) => CheckInLogModel.fromJson(map)).toList();
  }
}
