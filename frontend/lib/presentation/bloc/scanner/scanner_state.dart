part of 'scanner_bloc.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();

  @override
  List<Object?> get props => [];
}

class ScannerIdle extends ScannerState {
  const ScannerIdle();
}

class ScannerProcessing extends ScannerState {
  const ScannerProcessing();
}

class ScannerSuccess extends ScannerState {
  final CheckInResultModel result;

  const ScannerSuccess(this.result);

  @override
  List<Object?> get props => [result];
}

class ScannerFailed extends ScannerState {
  final String message;
  final String? errorCode;

  const ScannerFailed(this.message, {this.errorCode});

  @override
  List<Object?> get props => [message, errorCode];
}
