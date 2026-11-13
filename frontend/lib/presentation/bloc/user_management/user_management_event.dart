part of 'user_management_bloc.dart';

abstract class UserManagementEvent extends Equatable {
  const UserManagementEvent();

  @override
  List<Object?> get props => [];
}

class FetchUsersEvent extends UserManagementEvent {
  final String? query;
  final String? status;

  const FetchUsersEvent({this.query, this.status});

  @override
  List<Object?> get props => [query, status];
}

class ToggleUserStatusEvent extends UserManagementEvent {
  final String userId;
  final String currentStatus;
  final String studentName;

  const ToggleUserStatusEvent({
    required this.userId,
    required this.currentStatus,
    required this.studentName,
  });

  @override
  List<Object?> get props => [userId, currentStatus, studentName];
}

class CreateUserEvent extends UserManagementEvent {
  final String studentId;
  final String name;
  final String email;
  final String phone;
  final String role;

  const CreateUserEvent({
    required this.studentId,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
  });

  @override
  List<Object?> get props => [studentId, name, email, phone, role];
}
