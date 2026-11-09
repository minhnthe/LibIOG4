import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String studentId;
  final String name;
  final String email;
  final String role;
  final String status;
  final bool isInside;

  const UserModel({
    required this.id,
    this.studentId = '',
    required this.name,
    required this.email,
    required this.role,
    this.status = 'ACTIVE',
    this.isInside = false,
  });

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get isLibrarian => role.toUpperCase() == 'LIBRARIAN';
  bool get isStaff => isAdmin || isLibrarian;
  bool get isStudent => role.toUpperCase() == 'STUDENT';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      studentId: (json['studentId'] ?? json['student_id'] ?? '').toString(),
      name: (json['name'] ?? json['fullName'] ?? json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['roleName'] ?? json['role'] ?? 'STUDENT').toString().toUpperCase(),
      status: (json['status'] ?? 'ACTIVE').toString(),
      isInside: json['isInsideLibrary'] == true ||
          json['isInside'] == true ||
          json['is_inside'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'name': name,
      'email': email,
      'role': role,
      'status': status,
      'isInside': isInside,
    };
  }

  @override
  List<Object?> get props => [id, studentId, name, email, role, status, isInside];
}
