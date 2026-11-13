import 'package:equatable/equatable.dart';

class UserAdminModel extends Equatable {
  final String id;
  final String studentId;
  final String name;
  final String email;
  final String phone;
  final String role; // 'student' | 'admin' | 'librarian'
  final String status; // 'active' | 'locked' | 'deleted'
  final DateTime? cardExpiry;
  final String? avatarUrl;
  final bool isInsideLibrary;
  final String? tempPassword;

  const UserAdminModel({
    required this.id,
    required this.studentId,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = 'student',
    this.status = 'active',
    this.cardExpiry,
    this.avatarUrl,
    this.isInsideLibrary = false,
    this.tempPassword,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isLocked => status.toLowerCase() == 'locked' || status.toUpperCase() == 'BLOCKED';
  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isLibrarian => role.toLowerCase() == 'librarian';
  bool get isStudent => role.toLowerCase() == 'student';

  factory UserAdminModel.fromJson(Map<String, dynamic> json) {
    DateTime? expiry;
    if (json['cardExpiry'] != null) {
      expiry = DateTime.tryParse(json['cardExpiry'].toString());
    }

    return UserAdminModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? 'student').toString(),
      status: (json['status'] ?? 'active').toString(),
      cardExpiry: expiry,
      avatarUrl: json['avatarUrl']?.toString(),
      isInsideLibrary: json['isInsideLibrary'] == true,
      tempPassword: json['tempPassword']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'studentId': studentId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'status': status,
      'cardExpiry': cardExpiry?.toIso8601String(),
      'avatarUrl': avatarUrl,
      'isInsideLibrary': isInsideLibrary,
      'tempPassword': tempPassword,
    };
  }

  UserAdminModel copyWith({
    String? id,
    String? studentId,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? status,
    DateTime? cardExpiry,
    String? avatarUrl,
    bool? isInsideLibrary,
    String? tempPassword,
  }) {
    return UserAdminModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      cardExpiry: cardExpiry ?? this.cardExpiry,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isInsideLibrary: isInsideLibrary ?? this.isInsideLibrary,
      tempPassword: tempPassword ?? this.tempPassword,
    );
  }

  @override
  List<Object?> get props => [
    id,
    studentId,
    name,
    email,
    phone,
    role,
    status,
    cardExpiry,
    avatarUrl,
    isInsideLibrary,
    tempPassword,
  ];
}
