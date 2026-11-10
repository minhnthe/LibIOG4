import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../bloc/scanner/scanner_bloc.dart';
import '../../../../data/models/checkin_result_model.dart';

class QrScannerTab extends StatefulWidget {
  const QrScannerTab({super.key});

  @override
  State<QrScannerTab> createState() => _QrScannerTabState();
}

class _QrScannerTabState extends State<QrScannerTab> {
  final TextEditingController _inputController = TextEditingController();
  MobileScannerController? _cameraController;
  bool _isCameraActive = false;
  bool _isDialogOpen = false;
  bool _isScanningLocked = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    // Default camera active on mobile platforms
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _stopCamera();
    super.dispose();
  }

  void _startCamera() {
    try {
      _cameraController?.dispose();
    } catch (_) {}

    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 1000,
      formats: const [BarcodeFormat.qrCode],
      cameraResolution: const Size(1280, 720),
      facing: CameraFacing.back,
      torchEnabled: _isTorchOn,
    );

    if (mounted) {
      setState(() {
        _isCameraActive = true;
        _isScanningLocked = false;
      });
    }
  }

  void _stopCamera() {
    try {
      _cameraController?.dispose();
    } catch (_) {}
    _cameraController = null;

    if (mounted) {
      setState(() {
        _isCameraActive = false;
        _isScanningLocked = false;
      });
    }
  }

  void _toggleCamera() {
    if (_isCameraActive) {
      _stopCamera();
    } else {
      _startCamera();
    }
  }

  void _toggleTorch() {
    if (_cameraController != null && _isCameraActive) {
      _cameraController!.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    }
  }

  void _submitCode([String? text]) {
    final code = (text ?? _inputController.text).trim();
    if (code.isNotEmpty) {
      context.read<ScannerBloc>().add(ProcessQrCodeEvent(code));
    } else {
      _isScanningLocked = false;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isDialogOpen || _isScanningLocked) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final val = barcode.rawValue;
      if (val != null && val.isNotEmpty) {
        _isScanningLocked = true;
        _submitCode(val);
        break;
      }
    }
  }

  void _showResultDialog({
    required BuildContext context,
    required bool isSuccess,
    CheckInResultModel? result,
    String? errorMessage,
  }) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;

    final isCheckIn = result?.isCheckIn ?? true;
    final primaryColor = isSuccess
        ? (isCheckIn ? Colors.green.shade600 : Colors.blue.shade600)
        : Colors.red.shade600;

    final title = isSuccess
        ? (isCheckIn ? 'CHECK-IN THÀNH CÔNG' : 'CHECK-OUT THÀNH CÔNG')
        : 'TỪ CHỐI CHECK-IN';

    final checkInTimeStr = result?.checkInTime != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format(result!.checkInTime!)
        : '--:--';

    final checkOutTimeStr = result?.checkOutTime != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format(result!.checkOutTime!)
        : '--:--';

    final scannerBloc = context.read<ScannerBloc>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess
                    ? (isCheckIn ? Icons.login_rounded : Icons.logout_rounded)
                    : Icons.cancel_rounded,
                color: primaryColor,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            if (isSuccess && result != null) ...[
              _buildInfoRow('Sinh viên:', '${result.studentName} (${result.studentId})'),
              const SizedBox(height: 8),
              if (isCheckIn) ...[
                _buildInfoRow('Giờ vào:', checkInTimeStr),
                const SizedBox(height: 8),
                _buildInfoRow('Sức chứa hiện tại:', '${result.currentOccupancy} / ${result.maxCapacity} chỗ'),
              ] else ...[
                _buildInfoRow('Giờ ra:', checkOutTimeStr),
                const SizedBox(height: 8),
                _buildInfoRow('Thời gian ngồi:', '${result.durationMinutes ?? 0} phút'),
                const SizedBox(height: 8),
                _buildInfoRow('Chỗ còn trống:', '${result.maxCapacity - result.currentOccupancy} chỗ'),
              ],
            ] else ...[
              Text(
                errorMessage ?? 'Thẻ không hợp lệ hoặc hệ thống từ chối.',
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  _isDialogOpen = false;
                  _isScanningLocked = false;
                  _inputController.clear();
                  scannerBloc.add(const ResetScannerEvent());
                },
                child: const Text('TIẾP TỤC QUÉT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _isDialogOpen = false;
      _isScanningLocked = false;
      scannerBloc.add(const ResetScannerEvent());
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<ScannerBloc, ScannerState>(
      listener: (context, state) {
        if (state is ScannerSuccess) {
          _showResultDialog(context: context, isSuccess: true, result: state.result);
        } else if (state is ScannerFailed) {
          _showResultDialog(context: context, isSuccess: false, errorMessage: state.message);
        }
      },
      builder: (context, state) {
        final isProcessing = state is ScannerProcessing;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Station Banner
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                          theme.colorScheme.primary.withValues(alpha: 0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trạm quét thẻ ra / vào',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tự động phân loại: Ở ngoài vào -> Check-in; Ở trong ra -> Check-out.',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Camera Preview Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.camera_alt_rounded, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Camera quét mã QR',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              if (_isCameraActive)
                                IconButton(
                                  onPressed: _toggleTorch,
                                  icon: Icon(
                                    _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                    color: _isTorchOn ? Colors.amber.shade700 : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                              TextButton.icon(
                                onPressed: _toggleCamera,
                                icon: Icon(_isCameraActive ? Icons.videocam_off_rounded : Icons.videocam_rounded, size: 18),
                                label: Text(_isCameraActive ? 'Tắt Camera' : 'Bật Camera'),
                              ),
                            ],
                          ),
                        ),
                        if (_isCameraActive)
                          Container(
                            height: 280,
                            color: Colors.black,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                MobileScanner(
                                  controller: _cameraController,
                                  onDetect: _onDetect,
                                  errorBuilder: (context, error, child) {
                                    String errorMsg = 'Không thể khởi động camera';
                                    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
                                      errorMsg = 'Ứng dụng chưa được cấp quyền Camera.\nVui lòng cấp quyền trong Cài đặt hoặc nhấn Thử lại.';
                                    } else if (error.errorCode == MobileScannerErrorCode.unsupported) {
                                      errorMsg = 'Thiết bị không hỗ trợ tính năng quét camera.';
                                    } else {
                                      errorMsg = 'Lỗi camera: ${error.errorDetails?.message ?? error.errorCode.name}';
                                    }

                                    return Container(
                                      color: Colors.black87,
                                      padding: const EdgeInsets.all(20),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.videocam_off_rounded, color: Colors.amberAccent, size: 44),
                                          const SizedBox(height: 10),
                                          Text(
                                            errorMsg,
                                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            onPressed: _startCamera,
                                            icon: const Icon(Icons.refresh_rounded, size: 18),
                                            label: const Text('Thử lại / Cấp quyền', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: theme.colorScheme.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                // Scanning Overlay Box
                                Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.greenAccent, width: 2.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                if (isProcessing)
                                  Container(
                                    color: Colors.black54,
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        else
                          Container(
                            height: 120,
                            alignment: Alignment.center,
                            color: Colors.grey.shade50,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.no_photography_outlined, size: 36, color: Colors.grey.shade400),
                                const SizedBox(height: 6),
                                Text(
                                  'Camera đang tắt. Bạn có thể bật Camera hoặc dùng ô nhập tay bên dưới.',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Manual Keyboard Input Card (Desktop / Web Fallback)
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.keyboard_alt_rounded, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Nhập mã thẻ / MSSV thủ công (Fallback)',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Phù hợp khi dùng máy tính để bàn (Desktop/Web) hoặc máy quét mã vạch USB.',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _inputController,
                                  enabled: !isProcessing,
                                  decoration: InputDecoration(
                                    hintText: 'Nhập MSSV (VD: HE190001) hoặc dán mã QR...',
                                    prefixIcon: const Icon(Icons.badge_outlined),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onSubmitted: (_) => _submitCode(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: isProcessing ? null : () => _submitCode(),
                                  icon: isProcessing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.check_rounded),
                                  label: const Text('GHI NHẬN', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Quick Sample Buttons for easy testing
                          Text(
                            'Mã sinh viên mẫu thử nhanh:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildQuickChip('HE190001 (SV A - Active)'),
                              _buildQuickChip('HE190002 (SV B - Sức chứa)'),
                              _buildQuickChip('HE190003 (SV C - Khóa thẻ)'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickChip(String label) {
    final mssv = label.split(' ').first;
    return ActionChip(
      avatar: const Icon(Icons.person_pin_rounded, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        _inputController.text = mssv;
        _submitCode(mssv);
      },
    );
  }
}
