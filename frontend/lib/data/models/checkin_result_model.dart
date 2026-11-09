import 'package:equatable/equatable.dart';

class CheckInResultModel extends Equatable {
  final String logId;
  final String userId;
  final String studentId;
  final String studentName;
  final String type; // 'check_in' | 'check_out'
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int? durationMinutes;
  final int currentOccupancy;
  final int maxCapacity;

  const CheckInResultModel({
    required this.logId,
    required this.userId,
    required this.studentId,
    required this.studentName,
    required this.type,
    this.checkInTime,
    this.checkOutTime,
    this.durationMinutes,
    this.currentOccupancy = 0,
    this.maxCapacity = 100,
  });

  bool get isCheckIn => type == 'check_in';
  bool get isCheckOut => type == 'check_out';

  factory CheckInResultModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCheckIn;
    if (json['checkInTime'] != null) {
      parsedCheckIn = DateTime.tryParse(json['checkInTime'].toString());
    }

    DateTime? parsedCheckOut;
    if (json['checkOutTime'] != null) {
      parsedCheckOut = DateTime.tryParse(json['checkOutTime'].toString());
    }

    return CheckInResultModel(
      logId: (json['logId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      studentName: (json['studentName'] ?? '').toString(),
      type: (json['type'] ?? 'check_in').toString(),
      checkInTime: parsedCheckIn,
      checkOutTime: parsedCheckOut,
      durationMinutes: json['durationMinutes'] != null
          ? int.tryParse(json['durationMinutes'].toString())
          : null,
      currentOccupancy: int.tryParse(json['currentOccupancy']?.toString() ?? '0') ?? 0,
      maxCapacity: int.tryParse(json['maxCapacity']?.toString() ?? '100') ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logId': logId,
      'userId': userId,
      'studentId': studentId,
      'studentName': studentName,
      'type': type,
      'checkInTime': checkInTime?.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'currentOccupancy': currentOccupancy,
      'maxCapacity': maxCapacity,
    };
  }

  @override
  List<Object?> get props => [
        logId,
        userId,
        studentId,
        studentName,
        type,
        checkInTime,
        checkOutTime,
        durationMinutes,
        currentOccupancy,
        maxCapacity,
      ];
}
