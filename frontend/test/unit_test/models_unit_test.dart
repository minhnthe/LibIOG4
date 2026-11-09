import 'package:flutter_test/flutter_test.dart';
import 'package:assignment/data/models/user_model.dart';
import 'package:assignment/data/models/system_config_model.dart';
import 'package:assignment/data/models/checkin_result_model.dart';
import 'package:assignment/data/models/occupancy_stats_model.dart';

void main() {
  group('Unit Tests: Data Models Serialization & Logic', () {
    // ---------------------------------------------------------
    // 1. UserModel Tests
    // ---------------------------------------------------------
    group('1. UserModel Tests', () {
      test('UT-MODEL-01: UserModel parses valid Student JSON correctly', () {
        final json = {
          '_id': 'user_001',
          'student_id': 'HE190001',
          'full_name': 'Nguyen Van A',
          'email': 'anv@fpt.edu.vn',
          'role': 'STUDENT',
          'status': 'ACTIVE',
          'is_inside': true,
        };

        final user = UserModel.fromJson(json);

        expect(user.id, equals('user_001'));
        expect(user.studentId, equals('HE190001'));
        expect(user.name, equals('Nguyen Van A'));
        expect(user.email, equals('anv@fpt.edu.vn'));
        expect(user.role, equals('STUDENT'));
        expect(user.status, equals('ACTIVE'));
        expect(user.isInside, isTrue);
        expect(user.isStudent, isTrue);
        expect(user.isAdmin, isFalse);
        expect(user.isStaff, isFalse);
      });

      test('UT-MODEL-02: UserModel identifies Admin and Librarian role flags', () {
        final adminJson = {
          'id': 'admin_001',
          'name': 'Library Admin',
          'email': 'admin@fpt.edu.vn',
          'role': 'ADMIN',
        };
        final admin = UserModel.fromJson(adminJson);
        expect(admin.isAdmin, isTrue);
        expect(admin.isStaff, isTrue);
        expect(admin.isStudent, isFalse);

        final libJson = {
          'id': 'lib_001',
          'name': 'Librarian',
          'email': 'lib@fpt.edu.vn',
          'role': 'LIBRARIAN',
        };
        final librarian = UserModel.fromJson(libJson);
        expect(librarian.isLibrarian, isTrue);
        expect(librarian.isStaff, isTrue);
        expect(librarian.isAdmin, isFalse);
      });

      test('UT-MODEL-03: UserModel toJson outputs expected map', () {
        const user = UserModel(
          id: 'u123',
          studentId: 'HE194951',
          name: 'Minh NT',
          email: 'minhnt@fpt.edu.vn',
          role: 'ADMIN',
          status: 'ACTIVE',
          isInside: false,
        );

        final json = user.toJson();
        expect(json['id'], equals('u123'));
        expect(json['studentId'], equals('HE194951'));
        expect(json['role'], equals('ADMIN'));
        expect(json['isInside'], isFalse);
      });
    });

    // ---------------------------------------------------------
    // 2. SystemConfigModel Tests
    // ---------------------------------------------------------
    group('2. SystemConfigModel Tests', () {
      test('UT-MODEL-04: SystemConfigModel.empty() provides safe default values', () {
        final config = SystemConfigModel.empty();

        expect(config.maxCapacity, equals(100));
        expect(config.openTime, equals('07:00'));
        expect(config.closeTime, equals('21:00'));
        expect(config.maintenanceMode, isFalse);
      });

      test('UT-MODEL-05: SystemConfigModel fromJson handles numeric & string types safely', () {
        final json = {
          'maxCapacity': '250',
          'openTime': '07:30',
          'closeTime': '22:00',
          'maintenanceMode': true,
          'maintenanceMessage': 'He thong dang bao tri nang cap',
          'warningMinutesBeforeClose': '45',
          'maxSessionHours': '10',
          'allowedDays': 'Mon,Tue,Wed,Thu,Fri',
        };

        final config = SystemConfigModel.fromJson(json);

        expect(config.maxCapacity, equals(250));
        expect(config.openTime, equals('07:30'));
        expect(config.closeTime, equals('22:00'));
        expect(config.maintenanceMode, isTrue);
        expect(config.maintenanceMessage, equals('He thong dang bao tri nang cap'));
        expect(config.warningMinutesBeforeClose, equals(45));
        expect(config.maxSessionHours, equals(10));
      });

      test('UT-MODEL-06: SystemConfigModel copyWith updates specific fields only', () {
        final original = SystemConfigModel.empty();
        final updated = original.copyWith(
          maxCapacity: 50,
          maintenanceMode: true,
        );

        expect(updated.maxCapacity, equals(50));
        expect(updated.maintenanceMode, isTrue);
        expect(updated.openTime, equals(original.openTime));
        expect(updated.closeTime, equals(original.closeTime));
      });
    });

    // ---------------------------------------------------------
    // 3. CheckInResultModel Tests
    // ---------------------------------------------------------
    group('3. CheckInResultModel Tests', () {
      test('UT-MODEL-07: CheckInResultModel distinguishes CHECK_IN vs CHECK_OUT', () {
        final inJson = {
          'logId': 'log_in_01',
          'userId': 'user_01',
          'studentId': 'HE190001',
          'studentName': 'Nguyen Van A',
          'type': 'check_in',
          'checkInTime': '2026-10-09T08:00:00.000Z',
          'currentOccupancy': 15,
          'maxCapacity': 200,
        };

        final inResult = CheckInResultModel.fromJson(inJson);
        expect(inResult.isCheckIn, isTrue);
        expect(inResult.isCheckOut, isFalse);
        expect(inResult.currentOccupancy, equals(15));
        expect(inResult.checkInTime, isNotNull);

        final outJson = {
          'logId': 'log_out_01',
          'userId': 'user_01',
          'studentId': 'HE190001',
          'studentName': 'Nguyen Van A',
          'type': 'check_out',
          'durationMinutes': 120,
          'currentOccupancy': 14,
          'maxCapacity': 200,
        };

        final outResult = CheckInResultModel.fromJson(outJson);
        expect(outResult.isCheckIn, isFalse);
        expect(outResult.isCheckOut, isTrue);
        expect(outResult.durationMinutes, equals(120));
      });
    });

    // ---------------------------------------------------------
    // 4. OccupancyStatsModel & PresentStudentModel Tests
    // ---------------------------------------------------------
    group('4. OccupancyStatsModel Tests', () {
      test('UT-MODEL-08: OccupancyStatsModel calculates percentage and parses students list', () {
        final json = {
          'currentOccupancy': 75,
          'maxCapacity': 100,
          'totalVisitsToday': 320,
          'peakOccupancy': 95,
          'peakTime': '14:00',
          'presentList': [
            {
              'userId': 'u1',
              'studentId': 'HE190001',
              'name': 'Tran Van B',
              'checkInTime': '2026-10-09T09:00:00.000Z',
              'durationMinutes': 45,
            },
            {
              'userId': 'u2',
              'studentId': 'HE190002',
              'name': 'Le Thi C',
              'durationMinutes': 20,
            }
          ]
        };

        final stats = OccupancyStatsModel.fromJson(json);

        expect(stats.currentOccupancy, equals(75));
        expect(stats.maxCapacity, equals(100));
        expect(stats.occupancyPercent, equals(75)); // 75/100 = 75%
        expect(stats.presentList.length, equals(2));
        expect(stats.presentList[0].studentId, equals('HE190001'));
        expect(stats.presentList[0].durationMinutes, equals(45));
        expect(stats.presentList[1].name, equals('Le Thi C'));
      });
    });
  });
}
