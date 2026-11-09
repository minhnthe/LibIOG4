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
  final String query;
  final String? statusFilter;

  const UserManagementLoaded(
    this.users, {
    this.query = '',
    this.statusFilter,
  });

  @override
  List<Object?> get props => [users, query, statusFilter];
}

class UserManagementStatusUpdated extends UserManagementState {
  final String message;
  final List<UserAdminModel> users;

  const UserManagementStatusUpdated(this.message, this.users);

  @override
  List<Object?> get props => [message, users];
}

class UserManagementError extends UserManagementState {
  final String message;
  final List<UserAdminModel>? fallbackUsers;

  const UserManagementError(this.message, {this.fallbackUsers});

  @override
  List<Object?> get props => [message, fallbackUsers];
}
