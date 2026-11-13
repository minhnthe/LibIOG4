import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:assignment/domain/repositories/admin_repository.dart';
import 'package:assignment/data/models/checkin_result_model.dart';
import 'package:assignment/data/models/occupancy_stats_model.dart';
import 'package:assignment/data/models/report_data_model.dart';
import 'package:assignment/data/models/system_config_model.dart';
import 'package:assignment/data/models/user_admin_model.dart';
import 'package:assignment/data/models/gate_model.dart';

import 'package:assignment/presentation/bloc/scanner/scanner_bloc.dart';
import 'package:assignment/presentation/bloc/config/config_bloc.dart';
import 'package:assignment/presentation/bloc/realtime/realtime_bloc.dart';

/// Fake Implementation of AdminRepository for deterministic testing without external mock libraries
class FakeAdminRepository implements AdminRepository {
  CheckInResultModel? scanResult;
  Exception? scanError;

  SystemConfigModel? configResult;
  Exception? configError;

  OccupancyStatsModel? realtimeResult;
  Exception? realtimeError;

  bool forceCheckoutResult = true;

  @override
  Future<Map<String, dynamic>> login(String studentId, String password) async {
    return {'token': 'fake_token', 'user': {}};
  }

  @override
  Future<SystemConfigModel> getConfig() async {
    if (configError != null) throw configError!;
    return configResult ?? SystemConfigModel.empty();
  }

  @override
  Future<void> saveConfig(Map<String, dynamic> config) async {
    if (configError != null) throw configError!;
  }

  @override
  Future<OccupancyStatsModel> getRealtimeOccupancy() async {
    if (realtimeError != null) throw realtimeError!;
    return realtimeResult ?? OccupancyStatsModel.empty();
  }

  @override
  Future<bool> forceCheckOut(String userId) async {
    return forceCheckoutResult;
  }

  @override
  Future<CheckInResultModel> processScan(String qrPayload, {String? deviceId}) async {
    if (scanError != null) throw scanError!;
    return scanResult ??
        CheckInResultModel(
          logId: 'log_default',
          userId: 'u_default',
          studentId: 'HE190001',
          studentName: 'Nguyen Van A',
          type: 'check_in',
          checkInTime: DateTime.now(),
          currentOccupancy: 1,
          maxCapacity: 100,
        );
  }

  @override
  Future<List<UserAdminModel>> getUsers({String? search, String? status}) async {
    return [];
  }

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
  Future<UserAdminModel> toggleUserStatus(String userId, String currentStatus) async {
    return const UserAdminModel(
      id: 'u1',
      studentId: 'HE190001',
      name: 'Nguyen Van A',
      email: 'a@fpt.edu.vn',
      status: 'locked',
    );
  }

  @override
  Future<List<GateModel>> getGates() async => [];

  @override
  Future<GateModel> createGate({required String gateName, String location = ''}) async {
    return GateModel(id: 'gate_1', gateName: gateName, location: location);
  }

  @override
  Future<GateModel> updateGate(String gateId, {String? gateName, String? location, String? status}) async {
    return GateModel(id: gateId, gateName: gateName ?? 'Cổng', status: status ?? 'ACTIVE');
  }

  @override
  Future<ReportDataModel> getReport({String groupBy = 'hour'}) async {
    return ReportDataModel.empty();
  }

  @override
  Future<String> exportCsv() async {
    return 'STT,MSSV,Name\n1,HE190001,Nguyen Van A';
  }
}

void main() {
  group('Unit Tests: BLoC State Management', () {
    late FakeAdminRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeAdminRepository();
    });

    // -----------------------------------------------------------------
    // 1. ScannerBloc State Tests
    // -----------------------------------------------------------------
    group('1. ScannerBloc Tests', () {
      test('UT-BLOC-01: ScannerBloc initial state is ScannerIdle', () {
        final bloc = ScannerBloc(adminRepository: fakeRepo);
        expect(bloc.state, isA<ScannerIdle>());
      });

      blocTest<ScannerBloc, ScannerState>(
        'UT-BLOC-02: Emits [ScannerFailed] when input raw code is empty',
        build: () => ScannerBloc(adminRepository: fakeRepo),
        act: (bloc) => bloc.add(const ProcessQrCodeEvent('   ')),
        expect: () => [
          isA<ScannerFailed>().having(
            (s) => s.message,
            'message',
            contains('Vui lòng nhập mã sinh viên'),
          ),
        ],
      );

      blocTest<ScannerBloc, ScannerState>(
        'UT-BLOC-03: Emits [ScannerProcessing, ScannerSuccess] on valid scan',
        build: () {
          fakeRepo.scanResult = CheckInResultModel(
            logId: 'scan_log_01',
            userId: 'user_01',
            studentId: 'HE190001',
            studentName: 'Nguyen Van A',
            type: 'check_in',
            checkInTime: DateTime(2026, 10, 9, 8, 30),
            currentOccupancy: 25,
            maxCapacity: 200,
          );
          return ScannerBloc(adminRepository: fakeRepo);
        },
        act: (bloc) => bloc.add(const ProcessQrCodeEvent('LIB:HE190001:CARD01:999999')),
        expect: () => [
          isA<ScannerProcessing>(),
          isA<ScannerSuccess>().having(
            (s) => s.result.studentId,
            'studentId',
            equals('HE190001'),
          ),
        ],
      );

      blocTest<ScannerBloc, ScannerState>(
        'UT-BLOC-04: Emits [ScannerProcessing, ScannerFailed] when capacity is full',
        build: () {
          fakeRepo.scanError = Exception('[CAPACITY_FULL] Thư viện đã đạt sức chứa tối đa');
          return ScannerBloc(adminRepository: fakeRepo);
        },
        act: (bloc) => bloc.add(const ProcessQrCodeEvent('LIB:HE190002:CARD02:999999')),
        expect: () => [
          isA<ScannerProcessing>(),
          isA<ScannerFailed>()
              .having((s) => s.errorCode, 'errorCode', equals('CAPACITY_FULL'))
              .having((s) => s.message, 'message', contains('sức chứa tối đa')),
        ],
      );

      blocTest<ScannerBloc, ScannerState>(
        'UT-BLOC-05: Emits [ScannerIdle] when ResetScannerEvent is added',
        build: () => ScannerBloc(adminRepository: fakeRepo),
        act: (bloc) => bloc.add(const ResetScannerEvent()),
        expect: () => [isA<ScannerIdle>()],
      );
    });

    // -----------------------------------------------------------------
    // 2. ConfigBloc State Tests
    // -----------------------------------------------------------------
    group('2. ConfigBloc Tests', () {
      test('UT-BLOC-06: ConfigBloc initial state is ConfigInitial', () {
        final bloc = ConfigBloc(adminRepository: fakeRepo);
        expect(bloc.state, isA<ConfigInitial>());
      });

      blocTest<ConfigBloc, ConfigState>(
        'UT-BLOC-07: Emits [ConfigLoading, ConfigLoaded] on LoadConfigEvent success',
        build: () {
          fakeRepo.configResult = const SystemConfigModel(
            maxCapacity: 150,
            openTime: '08:00',
            closeTime: '22:00',
          );
          return ConfigBloc(adminRepository: fakeRepo);
        },
        act: (bloc) => bloc.add(const LoadConfigEvent()),
        expect: () => [
          isA<ConfigLoading>(),
          isA<ConfigLoaded>().having((s) => s.config.maxCapacity, 'maxCapacity', equals(150)),
        ],
      );

      blocTest<ConfigBloc, ConfigState>(
        'UT-BLOC-08: Emits [ConfigLoading, ConfigError] when loading config fails',
        build: () {
          fakeRepo.configError = Exception('Network connection failed');
          return ConfigBloc(adminRepository: fakeRepo);
        },
        act: (bloc) => bloc.add(const LoadConfigEvent()),
        expect: () => [
          isA<ConfigLoading>(),
          isA<ConfigError>().having((s) => s.message, 'message', contains('Network connection failed')),
        ],
      );

      blocTest<ConfigBloc, ConfigState>(
        'UT-BLOC-09: Emits [ConfigUpdating, ConfigUpdateSuccess] on UpdateConfigEvent',
        build: () {
          fakeRepo.configResult = const SystemConfigModel(
            maxCapacity: 10,
            openTime: '07:00',
            closeTime: '21:00',
          );
          return ConfigBloc(adminRepository: fakeRepo);
        },
        seed: () => const ConfigLoaded(
          SystemConfigModel(maxCapacity: 100, openTime: '07:00', closeTime: '21:00'),
        ),
        act: (bloc) => bloc.add(const UpdateConfigEvent({'maxCapacity': 10})),
        expect: () => [
          isA<ConfigUpdating>(),
          isA<ConfigUpdateSuccess>().having((s) => s.config.maxCapacity, 'maxCapacity', equals(10)),
        ],
      );
    });

    // -----------------------------------------------------------------
    // 3. RealtimeBloc State Tests
    // -----------------------------------------------------------------
    group('3. RealtimeBloc Tests', () {
      test('UT-BLOC-10: RealtimeBloc initial state is RealtimeInitial', () {
        final bloc = RealtimeBloc(adminRepository: fakeRepo);
        expect(bloc.state, isA<RealtimeInitial>());
      });

      blocTest<RealtimeBloc, RealtimeState>(
        'UT-BLOC-11: Emits [RealtimeLoading, RealtimeLoaded] on FetchRealtimeDataEvent',
        build: () {
          fakeRepo.realtimeResult = const OccupancyStatsModel(
            currentOccupancy: 12,
            maxCapacity: 100,
            occupancyPercent: 12,
            presentList: [],
          );
          return RealtimeBloc(adminRepository: fakeRepo);
        },
        act: (bloc) => bloc.add(const FetchRealtimeDataEvent()),
        expect: () => [
          isA<RealtimeLoading>(),
          isA<RealtimeLoaded>().having(
            (s) => s.data.currentOccupancy,
            'currentOccupancy',
            equals(12),
          ),
        ],
      );

      blocTest<RealtimeBloc, RealtimeState>(
        'UT-BLOC-12: Emits [RealtimeActionSuccess] on ForceCheckOutUserEvent',
        build: () {
          fakeRepo.realtimeResult = const OccupancyStatsModel(
            currentOccupancy: 5,
            maxCapacity: 50,
            occupancyPercent: 10,
          );
          return RealtimeBloc(adminRepository: fakeRepo);
        },
        seed: () => RealtimeLoaded(
          const OccupancyStatsModel(currentOccupancy: 6, maxCapacity: 50, occupancyPercent: 12),
        ),
        act: (bloc) => bloc.add(const ForceCheckOutUserEvent('user_123', 'Tran Thi B')),
        expect: () => [
          isA<RealtimeActionSuccess>().having(
            (s) => s.message,
            'message',
            contains('Tran Thi B'),
          ),
        ],
      );
    });
  });
}
