import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/models/checkin_log_admin_model.dart';
import '../../../../data/repositories/admin_repository_impl.dart';
import '../../../../domain/repositories/admin_repository.dart';

part 'checkin_logs_event.dart';
part 'checkin_logs_state.dart';

class CheckinLogsBloc extends Bloc<CheckinLogsEvent, CheckinLogsState> {
  final AdminRepository adminRepository;

  CheckinLogsBloc({AdminRepository? adminRepository})
    : adminRepository = adminRepository ?? AdminRepositoryImpl(),
      super(const CheckinLogsInitial()) {
    on<LoadCheckinLogsEvent>(_onLoad);
  }

  Future<void> _onLoad(
    LoadCheckinLogsEvent event,
    Emitter<CheckinLogsState> emit,
  ) async {
    final previousLogs = state is CheckinLogsLoaded
        ? (state as CheckinLogsLoaded).logs
        : state is CheckinLogsError
        ? (state as CheckinLogsError).fallbackLogs
        : <CheckinLogAdminModel>[];
    emit(CheckinLogsLoading(logs: previousLogs));

    try {
      final logs = await adminRepository.getCheckinLogs(
        search: event.search,
        status: event.status,
      );
      emit(CheckinLogsLoaded(logs, search: event.search, status: event.status));
    } catch (e) {
      emit(
        CheckinLogsError(
          e.toString().replaceFirst('Exception: ', ''),
          fallbackLogs: previousLogs,
        ),
      );
    }
  }
}
