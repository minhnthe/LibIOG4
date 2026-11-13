import 'package:equatable/equatable.dart';

class CheckinLogAdminModel extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final int? durationMinutes;
  final String actionType;
  final String status;
  final String gateName;

  const CheckinLogAdminModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.checkInTime,
    this.checkOutTime,
    this.durationMinutes,
    required this.actionType,
    required this.status,
    required this.gateName,
  });

  factory CheckinLogAdminModel.fromJson(Map<String, dynamic> json) {
    return CheckinLogAdminModel(
      id: (json['id'] ?? json['logId'] ?? json['_id'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      studentName: (json['studentName'] ?? '').toString(),
      checkInTime: DateTime.parse(json['checkInTime'].toString()).toLocal(),
      checkOutTime: json['checkOutTime'] == null
          ? null
          : DateTime.parse(json['checkOutTime'].toString()).toLocal(),
      durationMinutes: json['durationMinutes'] == null
          ? null
          : int.tryParse(json['durationMinutes'].toString()),
      actionType: (json['actionType'] ?? 'CHECK_IN').toString(),
      status: (json['status'] ?? 'INSIDE').toString(),
      gateName: (json['gateName'] ?? 'Cổng chính').toString(),
    );
  }

  bool get isInside => status == 'INSIDE';

  @override
  List<Object?> get props => [
    id,
    studentId,
    studentName,
    checkInTime,
    checkOutTime,
    durationMinutes,
    actionType,
    status,
    gateName,
  ];
}
