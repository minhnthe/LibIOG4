part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Kiểm tra trạng thái đăng nhập từ session/cache khi khởi động app
class AuthCheckStatus extends AuthEvent {
  const AuthCheckStatus();
}

/// Gửi yêu cầu đăng nhập bằng mã sinh viên / email và mật khẩu
class AuthLoginSubmitted extends AuthEvent {
  final String studentId;
  final String password;

  const AuthLoginSubmitted({
    required this.studentId,
    required this.password,
  });

  @override
  List<Object?> get props => [studentId, password];
}

/// Đăng xuất khỏi hệ thống và xóa token lưu trữ
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
