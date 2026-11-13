import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../data/models/user_admin_model.dart';
import '../../../../data/repositories/admin_repository_impl.dart';
import '../../../../domain/repositories/admin_repository.dart';

part 'user_management_event.dart';
part 'user_management_state.dart';

class UserManagementBloc
    extends Bloc<UserManagementEvent, UserManagementState> {
  final AdminRepository adminRepository;

  UserManagementBloc({AdminRepository? adminRepository})
    : adminRepository = adminRepository ?? AdminRepositoryImpl(),
      super(const UserManagementInitial()) {
    on<FetchUsersEvent>(_onFetchUsers);
    on<ToggleUserStatusEvent>(_onToggleUserStatus);
    on<CreateUserEvent>(_onCreateUser);
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

  int get _currentTotal {
    if (state is UserManagementLoaded) {
      return (state as UserManagementLoaded).total;
    } else if (state is UserManagementStatusUpdated) {
      return (state as UserManagementStatusUpdated).total;
    } else if (state is UserManagementUserCreated) {
      return (state as UserManagementUserCreated).total;
    }
    return _currentUsers?.length ?? 0;
  }

  Future<void> _onCreateUser(
    CreateUserEvent event,
    Emitter<UserManagementState> emit,
  ) async {
    final currentList = _currentUsers ?? [];
    try {
      final createdUser = await adminRepository.createUser(
        studentId: event.studentId,
        name: event.name,
        email: event.email,
        phone: event.phone,
        role: event.role,
      );
      final optimisticUsers = [createdUser, ...currentList];
      final optimisticTotal = _currentTotal + 1;

      try {
        // Đọc lại từ server để danh sách trên màn hình phản ánh đúng dữ liệu MongoDB.
        final page = await adminRepository.getUsers();
        emit(
          UserManagementUserCreated(createdUser, page.users, total: page.total),
        );
        emit(UserManagementLoaded(page.users, total: page.total));
      } catch (refreshError) {
        // Không ẩn tài khoản vừa tạo nếu bước tải lại danh sách gặp lỗi.
        emit(
          UserManagementUserCreated(
            createdUser,
            optimisticUsers,
            total: optimisticTotal,
          ),
        );
        emit(
          UserManagementError(
            'Tạo tài khoản thành công nhưng không thể tải lại danh sách: $refreshError',
            fallbackUsers: optimisticUsers,
          ),
        );
      }
    } catch (e) {
      emit(
        UserManagementError(
          'Không thể tạo tài khoản: $e',
          fallbackUsers: currentList,
        ),
      );
    }
  }

  Future<void> _onFetchUsers(
    FetchUsersEvent event,
    Emitter<UserManagementState> emit,
  ) async {
    if (state is! UserManagementLoaded) {
      emit(const UserManagementLoading());
    }

    try {
      final page = await adminRepository.getUsers(
        search: event.query,
        status: event.status,
      );
      emit(
        UserManagementLoaded(
          page.users,
          total: page.total,
          query: event.query ?? '',
          statusFilter: event.status,
        ),
      );
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

      final actionText = updatedUser.isLocked
          ? 'Đã khóa thẻ'
          : 'Đã mở khóa thẻ';
      final msg = '$actionText của sinh viên ${event.studentName}';

      emit(UserManagementStatusUpdated(msg, nextList, total: _currentTotal));
      emit(UserManagementLoaded(nextList, total: _currentTotal));
    } catch (e) {
      emit(
        UserManagementError(
          'Không thể cập nhật trạng thái thẻ: $e',
          fallbackUsers: currentList,
        ),
      );
    }
  }
}
