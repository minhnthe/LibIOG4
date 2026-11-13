import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../data/models/gate_model.dart';
import '../../../../data/repositories/admin_repository_impl.dart';
import '../../../../domain/repositories/admin_repository.dart';

part 'gate_management_event.dart';
part 'gate_management_state.dart';

class GateManagementBloc
    extends Bloc<GateManagementEvent, GateManagementState> {
  final AdminRepository adminRepository;

  GateManagementBloc({AdminRepository? adminRepository})
    : adminRepository = adminRepository ?? AdminRepositoryImpl(),
      super(const GateManagementInitial()) {
    on<LoadGatesEvent>(_onLoad);
    on<CreateGateEvent>(_onCreate);
    on<UpdateGateStatusEvent>(_onUpdateStatus);
  }

  Future<void> _onLoad(
    LoadGatesEvent event,
    Emitter<GateManagementState> emit,
  ) async {
    emit(const GateManagementLoading());
    try {
      emit(GateManagementLoaded(await adminRepository.getGates()));
    } catch (e) {
      emit(GateManagementError(e.toString()));
    }
  }

  Future<void> _onCreate(
    CreateGateEvent event,
    Emitter<GateManagementState> emit,
  ) async {
    final current = state is GateManagementLoaded
        ? (state as GateManagementLoaded).gates
        : <GateModel>[];
    try {
      final gate = await adminRepository.createGate(
        gateName: event.gateName,
        location: event.location,
      );
      // Đọc lại từ server để danh sách phản ánh đúng dữ liệu đã lưu.
      final gates = await adminRepository.getGates();
      emit(GateManagementCreated(gate, gates));
      emit(GateManagementLoaded(gates));
    } catch (e) {
      emit(GateManagementError(e.toString(), fallbackGates: current));
    }
  }

  Future<void> _onUpdateStatus(
    UpdateGateStatusEvent event,
    Emitter<GateManagementState> emit,
  ) async {
    final current = state is GateManagementLoaded
        ? (state as GateManagementLoaded).gates
        : <GateModel>[];
    try {
      final updated = await adminRepository.updateGate(
        event.gateId,
        status: event.status,
      );
      final next = await adminRepository.getGates();
      emit(GateManagementUpdated(updated, next));
      emit(GateManagementLoaded(next));
    } catch (e) {
      emit(GateManagementError(e.toString(), fallbackGates: current));
    }
  }
}
