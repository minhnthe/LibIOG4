import 'package:equatable/equatable.dart';

class PresentStudentModel extends Equatable {
  final String userId;
  final String studentId;
  final String name;
  final String? avatarUrl;
  final DateTime? checkInTime;
  final int durationMinutes;

  const PresentStudentModel({
    required this.userId,
    required this.studentId,
    required this.name,
    this.avatarUrl,
    this.checkInTime,
    this.durationMinutes = 0,
  });

  factory PresentStudentModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCheckIn;
    if (json['checkInTime'] != null) {
      parsedCheckIn = DateTime.tryParse(json['checkInTime'].toString());
    }

    return PresentStudentModel(
      userId: json['userId']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      checkInTime: parsedCheckIn,
      durationMinutes: int.tryParse(json['durationMinutes']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'studentId': studentId,
      'name': name,
      'avatarUrl': avatarUrl,
      'checkInTime': checkInTime?.toIso8601String(),
      'durationMinutes': durationMinutes,
    };
  }

  @override
  List<Object?> get props => [
        userId,
        studentId,
        name,
        avatarUrl,
        checkInTime,
        durationMinutes,
      ];
}
