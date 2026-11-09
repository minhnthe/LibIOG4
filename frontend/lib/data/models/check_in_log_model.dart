import 'package:equatable/equatable.dart';

class CheckInLogModel extends Equatable {
  final String id;
  final String userId;
  final DateTime timestamp;
  final String type;

  const CheckInLogModel({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.type,
  });

  factory CheckInLogModel.fromJson(Map<String, dynamic> json) {
    return CheckInLogModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
    };
  }

  @override
  List<Object?> get props => [id, userId, timestamp, type];
}
