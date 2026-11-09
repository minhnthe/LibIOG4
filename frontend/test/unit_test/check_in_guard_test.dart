import 'package:flutter_test/flutter_test.dart';

// Class giả lập logic nghiệp vụ Rào cản Check-in (Domain Layer)
class CheckInGuardEngine {
  final int maxCapacity;
  final String openTime;  // Ví dụ: "07:30"
  final String closeTime; // Ví dụ: "21:30"

  CheckInGuardEngine({
    required this.maxCapacity,
    required this.openTime,
    required this.closeTime,
  });

  bool canCheckIn({
    required bool isCardActive,
    required bool isAlreadyInside,
    required int currentInsideCount,
    required DateTime currentTime,
  }) {
    // 1. Kiểm tra trạng thái thẻ điện tử
    if (!isCardActive) return false;

    // 2. Sinh viên chưa check-out lần trước thì từ chối check-in tiếp
    if (isAlreadyInside) return false;

    // 3. Kiểm tra rào cản sức chứa tối đa
    if (currentInsideCount >= maxCapacity) return false;

    // 4. Kiểm tra khung giờ hoạt động (Cấm ở qua đêm)
    double currentHour = currentTime.hour + (currentTime.minute / 60.0);
    double startHour = _parseTime(openTime);
    double endHour = _parseTime(closeTime);

    if (currentHour < startHour || currentHour > endHour) {
      return false;
    }

    return true;
  }

  int calculateTotalMinutes(DateTime checkInTime, DateTime checkOutTime) {
    return checkOutTime.difference(checkInTime).inMinutes;
  }

  double _parseTime(String timeStr) {
    List<String> parts = timeStr.split(':');
    return double.parse(parts[0]) + (double.parse(parts[1]) / 60.0);
  }
}

void main() {
  group('FR-02: Unit Tests cho Business Guard Clauses Engine', () {
    late CheckInGuardEngine guardEngine;

    setUp(() {
      guardEngine = CheckInGuardEngine(
        maxCapacity: 200,
        openTime: '07:30',
        closeTime: '21:30',
      );
    });

    test('UT-01: Cho phép Check-in khi đầy đủ điều kiện hợp lệ', () {
      final result = guardEngine.canCheckIn(
        isCardActive: true,
        isAlreadyInside: false,
        currentInsideCount: 50,
        currentTime: DateTime(2026, 10, 9, 10, 0), // 10:00 AM
      );
      expect(result, isTrue);
    });

    test('UT-02: Từ chối Check-in khi thư viện đã đạt sức chứa tối đa (MAX_CAPACITY)', () {
      final result = guardEngine.canCheckIn(
        isCardActive: true,
        isAlreadyInside: false,
        currentInsideCount: 200, // Đã đầy chỗ
        currentTime: DateTime(2026, 10, 9, 10, 0),
      );
      expect(result, isFalse);
    });

    test('UT-03: Từ chối Check-in ngoài khung giờ hoạt động (Cấm ở qua đêm)', () {
      final result = guardEngine.canCheckIn(
        isCardActive: true,
        isAlreadyInside: false,
        currentInsideCount: 10,
        currentTime: DateTime(2026, 10, 9, 22, 30), // 22:30 PM (Sau 21:30)
      );
      expect(result, isFalse);
    });

    test('UT-04: Từ chối Check-in khi sinh viên chưa Check-out lần trước (is_inside == true)', () {
      final result = guardEngine.canCheckIn(
        isCardActive: true,
        isAlreadyInside: true, // Đang ở trong
        currentInsideCount: 10,
        currentTime: DateTime(2026, 10, 9, 10, 0),
      );
      expect(result, isFalse);
    });

    test('UT-05: Tự động tính toán tổng số phút lưu trú khi Check-out thành công', () {
      final checkIn = DateTime(2026, 10, 9, 8, 0);
      final checkOut = DateTime(2026, 10, 9, 11, 30);
      
      final totalMinutes = guardEngine.calculateTotalMinutes(checkIn, checkOut);
      expect(totalMinutes, equals(210)); // 3 tiếng 30 phút = 210 phút
    });
  });
}