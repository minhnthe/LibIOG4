import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:assignment/data/models/checkin_result_model.dart';
import 'package:assignment/data/models/occupancy_stats_model.dart';
import 'package:assignment/data/models/report_data_model.dart';
import 'package:assignment/data/models/system_config_model.dart';
import 'package:assignment/data/models/user_admin_model.dart';
import 'package:assignment/data/models/gate_model.dart';
import 'package:assignment/data/models/user_admin_page_model.dart';
import 'package:assignment/data/models/user_model.dart';
import 'package:assignment/domain/repositories/admin_repository.dart';
import 'package:assignment/presentation/bloc/auth/auth_bloc.dart';
import 'package:assignment/presentation/screens/auth/login_screen.dart';
import 'package:assignment/presentation/screens/student/student_home_screen.dart';
import 'package:assignment/presentation/screens/admin/admin_dashboard_screen.dart';

/// Fake Implementation of AdminRepository for UI testing
class FakeAdminRepository implements AdminRepository {
  @override
  Future<Map<String, dynamic>> login(String studentId, String password) async =>
      {};

  @override
  Future<SystemConfigModel> getConfig() async => SystemConfigModel.empty();

  @override
  Future<void> saveConfig(Map<String, dynamic> config) async {}

  @override
  Future<OccupancyStatsModel> getRealtimeOccupancy() async =>
      OccupancyStatsModel.empty();

  @override
  Future<bool> forceCheckOut(String userId) async => true;

  @override
  Future<CheckInResultModel> processScan(
    String qrPayload, {
    String? deviceId,
  }) async {
    return CheckInResultModel(
      logId: 'log_mock',
      userId: 'user_mock',
      studentId: 'HE190001',
      studentName: 'Nguyen Van An',
      type: 'check_in',
      checkInTime: DateTime.now(),
      currentOccupancy: 10,
      maxCapacity: 100,
    );
  }

  @override
  Future<UserAdminPageModel> getUsers({String? search, String? status}) async =>
      const UserAdminPageModel(users: [], total: 0);

  @override
  Future<UserAdminModel> createUser({
    required String studentId,
    required String name,
    required String email,
    String phone = '',
    required String role,
  }) async {
    return UserAdminModel(
      id: 'created',
      studentId: studentId,
      name: name,
      email: email,
      phone: phone,
      role: role,
      tempPassword: '${studentId}@Lib',
    );
  }

  @override
  Future<UserAdminModel> toggleUserStatus(
    String userId,
    String currentStatus,
  ) async {
    return UserAdminModel(
      id: userId,
      studentId: 'HE190001',
      name: 'Nguyen Van An',
      email: 'an.nv@fpt.edu.vn',
      role: 'STUDENT',
      status: currentStatus == 'ACTIVE' ? 'BLOCKED' : 'ACTIVE',
    );
  }

  @override
  Future<List<GateModel>> getGates() async => [];

  @override
  Future<GateModel> createGate({
    required String gateName,
    String location = '',
  }) async {
    return GateModel(id: 'gate_1', gateName: gateName, location: location);
  }

  @override
  Future<GateModel> updateGate(
    String gateId, {
    String? gateName,
    String? location,
    String? status,
  }) async {
    return GateModel(
      id: gateId,
      gateName: gateName ?? 'Cổng',
      status: status ?? 'ACTIVE',
    );
  }

  @override
  Future<ReportDataModel> getReport({
    String groupBy = 'hour',
    String? from,
    String? to,
  }) async => ReportDataModel.empty();

  @override
  Future<String> exportCsv({String? from, String? to}) async => '';
}

/// Fake AuthBloc dùng độc lập cho kiểm thử UI/Flow không phụ thuộc Network/SharedPreferences
class FakeAuthBloc extends Cubit<AuthState> implements AuthBloc {
  FakeAuthBloc([AuthState? initialState])
    : super(initialState ?? AuthInitial());

  @override
  final AdminRepository adminRepository = FakeAdminRepository();

  @override
  void on<E extends AuthEvent>(
    EventHandler<E, AuthState> handler, {
    EventTransformer<E>? transformer,
  }) {}

  @override
  void add(AuthEvent event) {
    if (event is AuthLoginSubmitted) {
      if (event.password == 'WrongPass') {
        emit(const AuthFailure('Mã sinh viên hoặc mật khẩu không chính xác'));
      } else if (event.studentId == 'HE190001') {
        emit(
          Authenticated(
            user: UserModel(
              id: 'u1',
              studentId: 'HE190001',
              name: 'Nguyễn Văn An',
              email: 'an.nv@fpt.edu.vn',
              role: 'student',
              status: 'ACTIVE',
              isInside: false,
            ),
            token: 'mock_student_jwt_token',
          ),
        );
      } else if (event.studentId == 'ADMIN01') {
        emit(
          Authenticated(
            user: UserModel(
              id: 'adm1',
              studentId: 'ADMIN01',
              name: 'Quản Trị Viên',
              email: 'admin@library.edu.vn',
              role: 'admin',
              status: 'ACTIVE',
              isInside: false,
            ),
            token: 'mock_admin_jwt_token',
          ),
        );
      }
    } else if (event is AuthLogoutRequested) {
      emit(Unauthenticated());
    }
  }

  @override
  void onTransition(Transition<AuthEvent, AuthState> transition) {}
  @override
  void onEvent(AuthEvent event) {}
}

Widget createTestApp({required Widget child, required AuthBloc authBloc}) {
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp(
      routes: {
        '/login': (context) => const LoginScreen(),
        '/student': (context) => const StudentHomeScreen(),
        '/admin': (context) => const AdminDashboardScreen(),
      },
      home: child,
    ),
  );
}

void main() {
  group('UI / End-to-End Flow Testing (Flutter Presentation Layer)', () {
    late FakeAuthBloc fakeAuthBloc;

    setUp(() {
      fakeAuthBloc = FakeAuthBloc();
    });

    tearDown(() {
      fakeAuthBloc.close();
    });

    // -------------------------------------------------------------
    // 1. Form Validation & UI Error States
    // -------------------------------------------------------------
    testWidgets(
      'TC-UI-01: LoginScreen validates empty inputs and shows warning hints',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(child: const LoginScreen(), authBloc: fakeAuthBloc),
        );

        // 1. Kiểm tra các thành phần giao diện ban đầu
        expect(find.text('Hệ Thống Thư Viện'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('Đăng nhập'), findsOneWidget);

        // 2. Nhấn nút Đăng nhập khi chưa điền dữ liệu
        await tester.tap(find.text('Đăng nhập'));
        await tester.pump();

        // 3. Kỳ vọng xuất hiện thông báo lỗi validation
        expect(
          find.text('Vui lòng nhập mã sinh viên hoặc tài khoản'),
          findsOneWidget,
        );
        expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      },
    );

    testWidgets('TC-UI-02: LoginScreen displays error banner on AuthFailure', (
      WidgetTester tester,
    ) async {
      fakeAuthBloc.emit(
        const AuthFailure('Mã sinh viên hoặc mật khẩu không chính xác'),
      );

      await tester.pumpWidget(
        createTestApp(child: const LoginScreen(), authBloc: fakeAuthBloc),
      );
      await tester.pump();

      // Kỳ vọng hiển thị banner cảnh báo đỏ
      expect(
        find.text('Mã sinh viên hoặc mật khẩu không chính xác'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 2. Navigation & Role-Based UI Presentation
    // -------------------------------------------------------------
    testWidgets(
      'TC-UI-03: StudentHomeScreen displays student digital badge and inside/outside chip',
      (WidgetTester tester) async {
        final student = UserModel(
          id: 'u_sv_01',
          studentId: 'HE190001',
          name: 'Nguyễn Văn An',
          email: 'an.nv@fpt.edu.vn',
          role: 'student',
          status: 'ACTIVE',
          isInside: false,
        );

        fakeAuthBloc.emit(
          Authenticated(user: student, token: 'token_mock_123'),
        );

        await tester.pumpWidget(
          createTestApp(
            child: const StudentHomeScreen(),
            authBloc: fakeAuthBloc,
          ),
        );
        await tester.pump();

        // Xác nhận các thành phần thông tin sinh viên hiển thị chính xác
        expect(find.text('Trang Sinh Viên'), findsOneWidget);
        expect(find.text('Nguyễn Văn An'), findsAtLeastNWidgets(1));
        expect(find.text('MSSV: HE190001'), findsOneWidget);
        expect(find.text('Đang ở bên ngoài'), findsOneWidget);
        expect(find.text('Thẻ Thư Viện Điện Tử'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-UI-04: AdminDashboardScreen renders 4 primary management tabs and allows switching',
      (WidgetTester tester) async {
        final admin = UserModel(
          id: 'u_adm_01',
          studentId: 'ADMIN01',
          name: 'Quản Trị Viên',
          email: 'admin@library.edu.vn',
          role: 'admin',
          status: 'ACTIVE',
        );

        fakeAuthBloc.emit(
          Authenticated(user: admin, token: 'token_admin_mock_123'),
        );

        await tester.pumpWidget(
          createTestApp(
            child: const AdminDashboardScreen(),
            authBloc: fakeAuthBloc,
          ),
        );
        await tester.pump();

        // Xác nhận thanh tiêu đề và 4 Tab điều hướng
        expect(find.text('Quản trị hệ thống'), findsOneWidget);
        expect(find.text('Live Occupancy'), findsOneWidget);
        expect(find.text('Trạm quét QR'), findsOneWidget);
        expect(find.text('Thành viên'), findsOneWidget);
        expect(find.text('Cấu hình'), findsOneWidget);

        // Chuyển sang Tab "Trạm quét QR"
        await tester.tap(find.text('Trạm quét QR'));
        await tester.pump();

        // Chuyển sang Tab "Cấu hình"
        await tester.tap(find.text('Cấu hình'));
        await tester.pump();
      },
    );

    // -------------------------------------------------------------
    // 3. Logout Confirmation Dialog Flow
    // -------------------------------------------------------------
    testWidgets(
      'TC-UI-05: StudentHomeScreen shows logout dialog and navigates to /login on confirmation',
      (WidgetTester tester) async {
        final student = UserModel(
          id: 'u1',
          studentId: 'HE190001',
          name: 'Nguyễn Văn An',
          email: 'an.nv@fpt.edu.vn',
          role: 'student',
          status: 'ACTIVE',
        );
        fakeAuthBloc.emit(
          Authenticated(user: student, token: 'token_mock_logout'),
        );

        await tester.pumpWidget(
          createTestApp(
            child: const StudentHomeScreen(),
            authBloc: fakeAuthBloc,
          ),
        );
        await tester.pump();

        // 1. Nhấn nút Đăng xuất trên AppBar
        await tester.tap(find.byTooltip('Đăng xuất'));
        await tester.pumpAndSettle();

        // 2. Xác nhận AlertDialog xuất hiện
        expect(find.text('Xác nhận đăng xuất'), findsOneWidget);
        expect(
          find.text('Bạn có chắc chắn muốn đăng xuất khỏi hệ thống?'),
          findsOneWidget,
        );
        expect(find.text('Hủy'), findsOneWidget);
        expect(find.text('Đăng xuất'), findsOneWidget);

        // 3. Nhấn nút Đăng xuất trên dialog
        await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
        await tester.pumpAndSettle();

        // 4. Kỳ vọng đã chuyển hướng về màn hình Login
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });
}
