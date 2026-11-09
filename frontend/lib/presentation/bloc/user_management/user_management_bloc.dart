import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/models/user_admin_model.dart';
import '../../../../data/repositories/admin_repository_impl.dart';
import '../../../../domain/repositories/admin_repository.dart';

part 'user_management_event.dart';
part 'user_management_state.dart';

class UserManagementBloc extends Bloc<UserManagementEvent, UserManagementState> {
  final AdminRepository adminRepository;

  UserManagementBloc({AdminRepository? adminRepository})
      : adminRepository = adminRepository ?? AdminRepositoryImpl(),
        super(const UserManagementInitial()) {
    on<FetchUsersEvent>(_onFetchUsers);
    on<ToggleUserStatusEvent>(_onToggleUserStatus);
  }

  List<UserAdminModel>? get _currentUsers {
    if (state is UserManagementLoaded) {
      return (state as UserManagementLoaded).users;
    } else if (state is UserManagementStatusUpdated) {
      return (state as UserManagementStatusUpdated).users;
    } else if (state is UserManagementError) {
      return (state as UserManagementError).fallbackUsers;
    }
    return null;
  }

  Future<void> _onFetchUsers(
    FetchUsersEvent event,
    Emitter<UserManagementState> emit,
  ) async {
    if (state is! UserManagementLoaded) {
      emit(const UserManagementLoading());
    }

    try {
      final users = await adminRepository.getUsers(
        search: event.query,
        status: event.status,
      );
      emit(UserManagementLoaded(
        users,
        query: event.query ?? '',
        statusFilter: event.status,
      ));
    } catch (e) {
      emit(UserManagementError(e.toString(), fallbackUsers: _currentUsers));
    }
  }

  Future<void> _onToggleUserStatus(
    ToggleUserStatusEvent event,
    Emitter<UserManagementState> emit,
  ) async {
    final currentList = _currentUsers ?? [];

    try {
      final updatedUser = await adminRepository.toggleUserStatus(
        event.userId,
        event.currentStatus,
      );

      final nextList = currentList.map((u) {
        return u.id == event.userId ? updatedUser : u;
      }).toList();

      final actionText = updatedUser.isLocked ? 'Đã khóa thẻ' : 'Đã mở khóa thẻ';
      final msg = '$actionText của sinh viên ${event.studentName}';

      emit(UserManagementStatusUpdated(msg, nextList));
      emit(UserManagementLoaded(nextList));
    } catch (e) {
      emit(UserManagementError(
        'Không thể cập nhật trạng thái thẻ: $e',
        fallbackUsers: currentList,
      ));
    }
  }
}
