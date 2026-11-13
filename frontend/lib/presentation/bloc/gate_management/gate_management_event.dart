part of 'gate_management_bloc.dart';

abstract class GateManagementEvent extends Equatable {
  const GateManagementEvent();

  @override
  List<Object?> get props => [];
}

class LoadGatesEvent extends GateManagementEvent {
  const LoadGatesEvent();
}

class CreateGateEvent extends GateManagementEvent {
  final String gateName;
  final String location;

  const CreateGateEvent({required this.gateName, this.location = ''});

  @override
  List<Object?> get props => [gateName, location];
}

class UpdateGateStatusEvent extends GateManagementEvent {
  final String gateId;
  final String status;

  const UpdateGateStatusEvent({required this.gateId, required this.status});

  @override
  List<Object?> get props => [gateId, status];
}
