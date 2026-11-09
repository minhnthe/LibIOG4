import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/fcm_service.dart';
import '../../../data/datasources/admin_remote_datasource.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/repositories/admin_repository.dart';
import '../../../data/repositories/admin_repository_impl.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AdminRepository adminRepository;

  AuthBloc({AdminRepository? adminRepository})
      : adminRepository = adminRepository ?? AdminRepositoryImpl(),
        super(AuthInitial()) {
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckStatus(
    AuthCheckStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userDataStr = prefs.getString('user_data');

      if (token != null && token.isNotEmpty && userDataStr != null && userDataStr.isNotEmpty) {
        final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
        final user = UserModel.fromJson(userData);
        ApiClient.setToken(token);
        AdminRemoteDataSource.setAuthToken(token);
        emit(Authenticated(user: user, token: token));
        return;
      }
    } catch (_) {}

    emit(Unauthenticated());
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final cleanId = event.studentId.trim();
      final cleanPassword = event.password;

      if (cleanId.isEmpty || cleanPassword.isEmpty) {
        emit(const AuthFailure('Vui lòng nhập đầy đủ mã sinh viên và mật khẩu.'));
        return;
      }

      final data = await adminRepository.login(cleanId, cleanPassword);
      final token = data['accessToken']?.toString() ?? '';
      final userJson = data['user'] as Map<String, dynamic>? ?? {};
      final user = UserModel.fromJson(userJson);

      // Lưu trữ token và user data cho các request tiếp theo
      ApiClient.setToken(token);
      AdminRemoteDataSource.setAuthToken(token);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('user_data', jsonEncode(user.toJson()));
      } catch (_) {}

      // Đồng bộ FCM token còn trong cache lên backend
      FcmService.syncCachedTokenAfterLogin(token);

      emit(Authenticated(user: user, token: token));
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      emit(AuthFailure(message));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await ApiClient.clearToken();
      AdminRemoteDataSource.setAuthToken(null);
      await FcmService.clearCachedToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
    } catch (_) {}
    emit(Unauthenticated());
  }
}
