import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String? email;
  final String? name;
  final String? avatar;
  final String? role;
  final String? status;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    this.email,
    this.name,
    this.avatar,
    this.role,
    this.status,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'] as String?,
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
      role: json['role'] as String?,
      status: json['status'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar': avatar,
      'role': role,
      'status': status,
    };
  }

  @override
  List<Object?> get props => [id, email, name, avatar, role, status, createdAt];
}