part of 'user_management_bloc.dart';

abstract class UserManagementState extends Equatable {
  const UserManagementState();

  @override
  List<Object?> get props => [];
}

class UserManagementInitial extends UserManagementState {
  const UserManagementInitial();
}

class UserManagementLoading extends UserManagementState {
  const UserManagementLoading();
}

class UserManagementLoaded extends UserManagementState {
  final List<UserAdminModel> users;
  final int total;
  final String query;
  final String? statusFilter;

  const UserManagementLoaded(
    this.users, {
    this.total = 0,
    this.query = '',
    this.statusFilter,
  });

  @override
  List<Object?> get props => [users, total, query, statusFilter];
}

class UserManagementStatusUpdated extends UserManagementState {
  final String message;
  final List<UserAdminModel> users;
  final int total;

  const UserManagementStatusUpdated(this.message, this.users, {this.total = 0});

  @override
  List<Object?> get props => [message, users, total];
}

class UserManagementUserCreated extends UserManagementState {
  final UserAdminModel user;
  final List<UserAdminModel> users;
  final int total;

  const UserManagementUserCreated(this.user, this.users, {this.total = 0});

  @override
  List<Object?> get props => [user, users, total];
}

class UserManagementError extends UserManagementState {
  final String message;
  final List<UserAdminModel>? fallbackUsers;

  const UserManagementError(this.message, {this.fallbackUsers});

  @override
  List<Object?> get props => [message, fallbackUsers];
}
