part of 'checkin_logs_bloc.dart';

abstract class CheckinLogsEvent extends Equatable {
  const CheckinLogsEvent();

  @override
  List<Object?> get props => [];
}

class LoadCheckinLogsEvent extends CheckinLogsEvent {
  final String? search;
  final String? status;

  const LoadCheckinLogsEvent({this.search, this.status});

  @override
  List<Object?> get props => [search, status];
}
