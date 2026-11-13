part of 'gate_management_bloc.dart';

abstract class GateManagementState extends Equatable {
  const GateManagementState();

  @override
  List<Object?> get props => [];
}

class GateManagementInitial extends GateManagementState {
  const GateManagementInitial();
}

class GateManagementLoading extends GateManagementState {
  const GateManagementLoading();
}

class GateManagementLoaded extends GateManagementState {
  final List<GateModel> gates;

  const GateManagementLoaded(this.gates);

  @override
  List<Object?> get props => [gates];
}

class GateManagementCreated extends GateManagementState {
  final GateModel gate;
  final List<GateModel> gates;

  const GateManagementCreated(this.gate, this.gates);

  @override
  List<Object?> get props => [gate, gates];
}

class GateManagementUpdated extends GateManagementState {
  final GateModel gate;
  final List<GateModel> gates;

  const GateManagementUpdated(this.gate, this.gates);

  @override
  List<Object?> get props => [gate, gates];
}

class GateManagementError extends GateManagementState {
  final String message;
  final List<GateModel>? fallbackGates;

  const GateManagementError(this.message, {this.fallbackGates});

  @override
  List<Object?> get props => [message, fallbackGates];
}
