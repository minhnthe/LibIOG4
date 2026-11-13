import 'package:equatable/equatable.dart';

class GateModel extends Equatable {
  final String id;
  final String gateName;
  final String location;
  final String status;

  const GateModel({
    required this.id,
    required this.gateName,
    this.location = '',
    this.status = 'ACTIVE',
  });

  bool get isActive => status == 'ACTIVE';

  factory GateModel.fromJson(Map<String, dynamic> json) {
    return GateModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      gateName: (json['gateName'] ?? json['gate_name'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      status: (json['status'] ?? 'ACTIVE').toString().toUpperCase(),
    );
  }

  @override
  List<Object?> get props => [id, gateName, location, status];
}
