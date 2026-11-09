part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Trạng thái khởi tạo ban đầu
class AuthInitial extends AuthState {}

/// Trạng thái đang kiểm tra phiên làm việc hoặc đang gửi API đăng nhập
class AuthLoading extends AuthState {}

/// Đăng nhập thành công, lưu giữ thông tin user và accessToken
class Authenticated extends AuthState {
  final UserModel user;
  final String token;

  const Authenticated({
    required this.user,
    required this.token,
  });

  bool get isAdmin => user.isAdmin;
  bool get isStaff => user.isStaff;
  bool get isStudent => user.isStudent;

  @override
  List<Object?> get props => [user, token];
}

/// Chưa đăng nhập hoặc đã đăng xuất
class Unauthenticated extends AuthState {}

/// Đăng nhập thất bại với thông báo lỗi cụ thể từ server
class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
