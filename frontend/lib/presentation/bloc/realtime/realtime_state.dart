part of 'realtime_bloc.dart';

abstract class RealtimeState extends Equatable {
  const RealtimeState();

  @override
  List<Object?> get props => [];
}

class RealtimeInitial extends RealtimeState {
  const RealtimeInitial();
}

class RealtimeLoading extends RealtimeState {
  const RealtimeLoading();
}

class RealtimeLoaded extends RealtimeState {
  final OccupancyStatsModel data;
  final DateTime lastUpdated;

  RealtimeLoaded(this.data) : lastUpdated = DateTime.now();

  @override
  List<Object?> get props => [data, lastUpdated];
}

class RealtimeActionSuccess extends RealtimeState {
  final String message;
  final OccupancyStatsModel data;

  const RealtimeActionSuccess(this.message, this.data);

  @override
  List<Object?> get props => [message, data];
}

class RealtimeError extends RealtimeState {
  final String message;
  final OccupancyStatsModel? fallbackData;

  const RealtimeError(this.message, {this.fallbackData});

  @override
  List<Object?> get props => [message, fallbackData];
}
