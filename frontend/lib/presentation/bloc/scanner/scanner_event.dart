part of 'scanner_bloc.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();

  @override
  List<Object?> get props => [];
}

class ProcessQrCodeEvent extends ScannerEvent {
  final String rawCode;
  final String? deviceId;

  const ProcessQrCodeEvent(this.rawCode, {this.deviceId});

  @override
  List<Object?> get props => [rawCode, deviceId];
}

class ResetScannerEvent extends ScannerEvent {
  const ResetScannerEvent();
}
