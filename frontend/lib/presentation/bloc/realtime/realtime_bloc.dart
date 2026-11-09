import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/models/occupancy_stats_model.dart';
import '../../../../data/repositories/admin_repository_impl.dart';
import '../../../../domain/repositories/admin_repository.dart';

part 'realtime_event.dart';
part 'realtime_state.dart';

class RealtimeBloc extends Bloc<RealtimeEvent, RealtimeState> {
  final AdminRepository adminRepository;
  Timer? _pollingTimer;

  RealtimeBloc({AdminRepository? adminRepository})
      : adminRepository = adminRepository ?? AdminRepositoryImpl(),
        super(const RealtimeInitial()) {
    on<FetchRealtimeDataEvent>(_onFetchRealtimeData);
    on<StartAutoRefreshEvent>(_onStartAutoRefresh);
    on<StopAutoRefreshEvent>(_onStopAutoRefresh);
    on<ForceCheckOutUserEvent>(_onForceCheckOutUser);
  }

  OccupancyStatsModel? get _currentData {
    if (state is RealtimeLoaded) {
      return (state as RealtimeLoaded).data;
    } else if (state is RealtimeActionSuccess) {
      return (state as RealtimeActionSuccess).data;
    } else if (state is RealtimeError) {
      return (state as RealtimeError).fallbackData;
    }
    return null;
  }

  Future<void> _onFetchRealtimeData(
    FetchRealtimeDataEvent event,
    Emitter<RealtimeState> emit,
  ) async {
    if (!event.isBackground && state is! RealtimeLoaded) {
      emit(const RealtimeLoading());
    }

    try {
      final stats = await adminRepository.getRealtimeOccupancy();
      emit(RealtimeLoaded(stats));
    } catch (e) {
      emit(RealtimeError(e.toString(), fallbackData: _currentData));
    }
  }

  Future<void> _onStartAutoRefresh(
    StartAutoRefreshEvent event,
    Emitter<RealtimeState> emit,
  ) async {
    _pollingTimer?.cancel();
    add(const FetchRealtimeDataEvent(isBackground: false));

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!isClosed) {
        add(const FetchRealtimeDataEvent(isBackground: true));
      }
    });
  }

  void _onStopAutoRefresh(
    StopAutoRefreshEvent event,
    Emitter<RealtimeState> emit,
  ) {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _onForceCheckOutUser(
    ForceCheckOutUserEvent event,
    Emitter<RealtimeState> emit,
  ) async {
    try {
      await adminRepository.forceCheckOut(event.userId);
      final updatedData = await adminRepository.getRealtimeOccupancy();
      emit(RealtimeActionSuccess(
        'Đã check-out thành công cho ${event.studentName}',
        updatedData,
      ));
    } catch (e) {
      emit(RealtimeError(
        'Không thể check-out cho ${event.studentName}: $e',
        fallbackData: _currentData,
      ));
    }
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }
}
