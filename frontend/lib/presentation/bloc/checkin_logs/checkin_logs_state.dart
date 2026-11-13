part of 'checkin_logs_bloc.dart';

abstract class CheckinLogsState extends Equatable {
  const CheckinLogsState();

  @override
  List<Object?> get props => [];
}

class CheckinLogsInitial extends CheckinLogsState {
  const CheckinLogsInitial();
}

class CheckinLogsLoading extends CheckinLogsState {
  final List<CheckinLogAdminModel> logs;

  const CheckinLogsLoading({this.logs = const []});

  @override
  List<Object?> get props => [logs];
}

class CheckinLogsLoaded extends CheckinLogsState {
  final List<CheckinLogAdminModel> logs;
  final String? search;
  final String? status;

  const CheckinLogsLoaded(this.logs, {this.search, this.status});

  @override
  List<Object?> get props => [logs, search, status];
}

class CheckinLogsError extends CheckinLogsState {
  final String message;
  final List<CheckinLogAdminModel> fallbackLogs;

  const CheckinLogsError(this.message, {this.fallbackLogs = const []});

  @override
  List<Object?> get props => [message, fallbackLogs];
}
