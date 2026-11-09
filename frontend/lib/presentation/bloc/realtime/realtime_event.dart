part of 'realtime_bloc.dart';

abstract class RealtimeEvent extends Equatable {
  const RealtimeEvent();

  @override
  List<Object?> get props => [];
}

class FetchRealtimeDataEvent extends RealtimeEvent {
  final bool isBackground;

  const FetchRealtimeDataEvent({this.isBackground = false});

  @override
  List<Object?> get props => [isBackground];
}

class StartAutoRefreshEvent extends RealtimeEvent {
  const StartAutoRefreshEvent();
}

class StopAutoRefreshEvent extends RealtimeEvent {
  const StopAutoRefreshEvent();
}

class ForceCheckOutUserEvent extends RealtimeEvent {
  final String userId;
  final String studentName;

  const ForceCheckOutUserEvent(this.userId, this.studentName);

  @override
  List<Object?> get props => [userId, studentName];
}
