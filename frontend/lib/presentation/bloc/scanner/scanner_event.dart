part of 'scanner_bloc.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();

  @override
  List<Object?> get props => [];
}

class ProcessQrCodeEvent extends ScannerEvent {
  final String rawCode;

  const ProcessQrCodeEvent(this.rawCode);

  @override
  List<Object?> get props => [rawCode];
}

class ResetScannerEvent extends ScannerEvent {
  const ResetScannerEvent();
}
