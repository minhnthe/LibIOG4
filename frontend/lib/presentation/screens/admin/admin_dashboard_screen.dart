import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/config/config_bloc.dart';
import '../../bloc/gate_management/gate_management_bloc.dart';
import '../../bloc/checkin_logs/checkin_logs_bloc.dart';
import '../../bloc/realtime/realtime_bloc.dart';
import '../../bloc/report/report_bloc.dart';
import '../../bloc/scanner/scanner_bloc.dart';
import '../../bloc/user_management/user_management_bloc.dart';
import 'tabs/live_occupancy_tab.dart';
import 'tabs/qr_scanner_tab.dart';
import 'tabs/report_analytics_tab.dart';
import 'tabs/system_config_tab.dart';
import 'tabs/user_management_tab.dart';
import 'tabs/gate_management_tab.dart';
import 'tabs/checkin_logs_tab.dart';
import '../../widgets/change_password_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  late final ConfigBloc _configBloc;
  late final RealtimeBloc _realtimeBloc;
  late final ScannerBloc _scannerBloc;
  late final UserManagementBloc _userManagementBloc;
  late final ReportBloc _reportBloc;
  late final GateManagementBloc _gateManagementBloc;
  late final CheckinLogsBloc _checkinLogsBloc;

  @override
  void initState() {
    super.initState();
    _configBloc = ConfigBloc();
    _realtimeBloc = RealtimeBloc();
    _scannerBloc = ScannerBloc();
    _userManagementBloc = UserManagementBloc();
    _reportBloc = ReportBloc();
    _gateManagementBloc = GateManagementBloc();
    _checkinLogsBloc = CheckinLogsBloc();
  }

  @override
  void dispose() {
    _configBloc.close();
    _realtimeBloc.close();
    _scannerBloc.close();
    _userManagementBloc.close();
    _reportBloc.close();
    _gateManagementBloc.close();
    _checkinLogsBloc.close();
    super.dispose();
  }

  final List<Widget> _tabs = const [
    LiveOccupancyTab(),
    QrScannerTab(),
    UserManagementTab(),
    SystemConfigTab(),
    ReportAnalyticsTab(),
    GateManagementTab(),
    CheckinLogsTab(),
  ];

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi trang quản trị?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _configBloc),
        BlocProvider.value(value: _realtimeBloc),
        BlocProvider.value(value: _scannerBloc),
        BlocProvider.value(value: _userManagementBloc),
        BlocProvider.value(value: _reportBloc),
        BlocProvider.value(value: _gateManagementBloc),
        BlocProvider.value(value: _checkinLogsBloc),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final user = state is Authenticated ? state.user : null;
              if (user?.isLibrarian == true) {
                return const Text('Trạm trực Thủ thư');
              }
              return const Text('Quản trị hệ thống');
            },
          ),
          centerTitle: true,
          elevation: 1,
          actions: [
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final user = state is Authenticated ? state.user : null;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          user.role,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Đổi mật khẩu',
                      icon: const Icon(Icons.lock_reset_rounded),
                      onPressed: () async {
                        final changed = await showChangePasswordDialog(context);
                        if (changed == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đổi mật khẩu thành công'),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () => _confirmLogout(context),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: IndexedStack(index: _currentIndex, children: _tabs),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Live Occupancy',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Trạm quét QR',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded),
              label: 'Thành viên',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Cấu hình',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Thống kê',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.door_front_door_rounded),
              label: 'Cổng',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Nhật ký',
              tooltip: '',
            ),
          ],
        ),
      ),
    );
  }
}
