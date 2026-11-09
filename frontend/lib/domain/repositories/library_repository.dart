import '../../data/models/user_model.dart';
import '../../data/models/check_in_log_model.dart';

abstract class LibraryRepository {
  Future<UserModel?> getUser(String id);
  Future<void> logCheckIn(CheckInLogModel log);
  Future<List<CheckInLogModel>> getLogs();
}
