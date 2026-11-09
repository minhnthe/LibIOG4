import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../bloc/auth/auth_bloc.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  String? _qrPayload;
  int _countdown = 60;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      final token = authState is Authenticated ? authState.token : null;
      _fetchQr(token: token);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchQr({String? token}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString('auth_token');
      }

      final res = await http.get(
        Uri.parse(AppConstants.userMeQrEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
        },
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _qrPayload = data['qrPayload']?.toString();
          _countdown = (data['expiresIn'] as num?)?.toInt() ?? 60;
          _isLoading = false;
        });
        _startTimer();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = body['message']?.toString() ?? 'Không thể tải mã QR';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Lỗi kết nối máy chủ: $e';
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        t.cancel();
        _fetchQr();
      }
    });
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi hệ thống?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is Authenticated ? state.user : null;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text('Trang Sinh Viên'),
            centerTitle: true,
            elevation: 1,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Đăng xuất',
                onPressed: () => _confirmLogout(context),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _fetchQr(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card thông tin sinh viên
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.person,
                                  size: 40,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                user?.name ?? 'Sinh viên',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'MSSV: ${user?.studentId.isNotEmpty == true ? user!.studentId : "---"}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Chip(
                                    backgroundColor: user?.isInside == true
                                        ? Colors.green.shade100
                                        : Colors.grey.shade200,
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          user?.isInside == true
                                              ? Icons.login_rounded
                                              : Icons.logout_rounded,
                                          size: 16,
                                          color: user?.isInside == true
                                              ? Colors.green.shade800
                                              : Colors.grey.shade800,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          user?.isInside == true
                                              ? 'Đang ở trong thư viện (Quẹt để ra)'
                                              : 'Đang ở bên ngoài (Quẹt để vào)',
                                          style: TextStyle(
                                            color: user?.isInside == true
                                              ? Colors.green.shade800
                                              : Colors.grey.shade800,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card Thẻ Thư Viện điện tử
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.badge_outlined,
                                      color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Thẻ Thư Viện Điện Tử',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _buildInfoRow('Họ và tên:', user?.name ?? '---'),
                              const SizedBox(height: 8),
                              _buildInfoRow('Email:', user?.email ?? '---'),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                  'Trạng thái thẻ:',
                                  user?.status == 'ACTIVE'
                                      ? 'Hoạt động'
                                      : 'Bị khóa',
                                  isPositive: user?.status == 'ACTIVE'),
                              const SizedBox(height: 20),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    children: [
                                      if (user?.status != 'ACTIVE') ...[
                                        const Icon(
                                          Icons.lock_rounded,
                                          size: 64,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Thẻ thư viện đang bị khóa',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Vui lòng liên hệ thủ thư tại quầy để mở khóa thẻ.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ] else if (_isLoading && _qrPayload == null) ...[
                                        const SizedBox(
                                          height: 160,
                                          child: Center(child: CircularProgressIndicator()),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text('Đang tạo mã QR động...'),
                                      ] else if (_errorMessage != null) ...[
                                        Icon(Icons.error_outline_rounded,
                                            size: 48, color: Colors.orange.shade700),
                                        const SizedBox(height: 8),
                                        Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: Colors.red.shade700, fontSize: 13),
                                        ),
                                        const SizedBox(height: 10),
                                        OutlinedButton.icon(
                                          onPressed: () => _fetchQr(),
                                          icon: const Icon(Icons.refresh_rounded, size: 18),
                                          label: const Text('Thử lại'),
                                        ),
                                      ] else if (_qrPayload != null) ...[
                                        QrImageView(
                                          data: _qrPayload!,
                                          version: QrVersions.auto,
                                          size: 160,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Mã định danh: ${user?.studentId ?? ""}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.timer_outlined,
                                                size: 14, color: Colors.orange.shade800),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Làm mới sau ${_countdown}s',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade800,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              iconSize: 18,
                                              tooltip: 'Làm mới ngay',
                                              icon: const Icon(Icons.refresh_rounded),
                                              onPressed: () => _fetchQr(),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Đưa mã này vào trạm quét để vào/ra cổng',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool? isPositive}) {
    Color? valueColor;
    if (isPositive != null) {
      valueColor = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
