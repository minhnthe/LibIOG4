import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/models/checkin_result_model.dart';
import '../../../../data/repositories/admin_repository_impl.dart';
import '../../../../domain/repositories/admin_repository.dart';

part 'scanner_event.dart';
part 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final AdminRepository adminRepository;

  ScannerBloc({AdminRepository? adminRepository})
      : adminRepository = adminRepository ?? AdminRepositoryImpl(),
        super(const ScannerIdle()) {
    on<ProcessQrCodeEvent>(_onProcessQrCode);
    on<ResetScannerEvent>((event, emit) => emit(const ScannerIdle()));
  }

  Future<void> _onProcessQrCode(
    ProcessQrCodeEvent event,
    Emitter<ScannerState> emit,
  ) async {
    final raw = event.rawCode.trim();
    if (raw.isEmpty) {
      emit(const ScannerFailed('Vui lòng nhập mã sinh viên hoặc quét QR hợp lệ'));
      return;
    }

    emit(const ScannerProcessing());
    try {
      final result = await adminRepository.processScan(raw);
      emit(ScannerSuccess(result));
    } catch (e) {
      final errString = e.toString().replaceFirst('Exception: ', '');
      String? code;
      String msg = errString;

      final match = RegExp(r'^\[(.*?)\]\s*(.*)$').firstMatch(errString);
      if (match != null) {
        code = match.group(1);
        msg = match.group(2) ?? errString;
      }

      emit(ScannerFailed(msg, errorCode: code));
    }
  }
}
