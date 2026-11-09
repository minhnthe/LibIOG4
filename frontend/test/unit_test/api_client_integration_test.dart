import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:assignment/data/datasources/remote_api_service.dart';
import 'package:assignment/data/datasources/admin_remote_datasource.dart';

void main() {
  group('Integration & API Testing: Frontend Client Layer', () {
    // -------------------------------------------------------------
    // 1. RemoteApiService Integration Tests
    // -------------------------------------------------------------
    group('1. RemoteApiService HTTP Integration', () {
      test('INT-CLIENT-01: login parses success response and returns user data map', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.path, contains('/api/auth/login'));

          final body = jsonDecode(request.body);
          if (body['studentId'] == 'HE190001' && body['password'] == 'Student@123') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'accessToken': 'mock_jwt_access_token_xyz',
                  'user': {'studentId': 'HE190001', 'role': 'STUDENT'}
                }
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(jsonEncode({'success': false, 'message': 'Unauthorized'}), 401);
        });

        final service = RemoteApiService(client: mockClient);
        final result = await service.login('HE190001', 'Student@123');

        expect(result, isNotNull);
        expect(result!['success'], isTrue);
        expect(result['data']['accessToken'], equals('mock_jwt_access_token_xyz'));
      });

      test('INT-CLIENT-02: syncCheckInLogs sends batch offline logs with status 200 OK', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.path, contains('/sync'));

          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['logs'], isA<List>());
          return http.Response(jsonEncode({'success': true, 'syncedCount': 2}), 200);
        });

        final service = RemoteApiService(client: mockClient);
        final isSynced = await service.syncCheckInLogs([
          {'local_id': 'log_1', 'student_id': 'HE190001'},
          {'local_id': 'log_2', 'student_id': 'HE190002'}
        ]);

        expect(isSynced, isTrue);
      });
    });

    // -------------------------------------------------------------
    // 2. AdminRemoteDataSource Integration Tests
    // -------------------------------------------------------------
    group('2. AdminRemoteDataSource Auth & Headers Integration', () {
      test('INT-CLIENT-03: submitScan attaches Bearer token and parses CheckInResultModel', () async {
        AdminRemoteDataSource.setAuthToken('test_admin_jwt_token_123');

        final mockClient = MockClient((request) async {
          expect(request.headers['Authorization'], equals('Bearer test_admin_jwt_token_123'));
          expect(request.method, equals('POST'));

          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'logId': 'log_live_99',
                'userId': 'usr_99',
                'studentId': 'HE190001',
                'studentName': 'Nguyen Van A',
                'type': 'check_in',
                'checkInTime': '2026-10-09T08:00:00.000Z',
                'currentOccupancy': 10,
                'maxCapacity': 100,
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final adminSource = AdminRemoteDataSource(client: mockClient);
        final result = await adminSource.submitScan('LIB:HE190001:CARD:99999');

        expect(result.studentId, equals('HE190001'));
        expect(result.isCheckIn, isTrue);
        expect(result.currentOccupancy, equals(10));
      });

      test('INT-CLIENT-04: getConfigs handles 200 response and maps to SystemConfigModel', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'maxCapacity': 180,
                'openTime': '07:30',
                'closeTime': '21:30',
                'maintenanceMode': false,
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final adminSource = AdminRemoteDataSource(client: mockClient);
        final config = await adminSource.getConfigs();

        expect(config.maxCapacity, equals(180));
        expect(config.openTime, equals('07:30'));
        expect(config.closeTime, equals('21:30'));
      });
    });
  });
}
