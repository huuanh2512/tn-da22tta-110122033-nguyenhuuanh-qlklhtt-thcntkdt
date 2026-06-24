import 'package:equatable/equatable.dart';

class UserResult extends Equatable {
  const UserResult({
    required this.isSuccess,
    this.error,
    this.code,
    this.userId,
    this.email,
    this.name,
    this.avatarUrl,
    this.role,
    this.status,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final bool isSuccess;
  final String? error;
  final String? code;
  final String? userId;
  final String? email;
  final String? name;
  final String? avatarUrl;
  final String? role;
  final String? status;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  factory UserResult.fromJson(Map<String, dynamic> json) {
    return UserResult(
      isSuccess: json['isSuccess'] as bool? ?? false,
      error: json['error'] as String?,
      code: json['code'] as String?,
      userId: json['userId'] as String?,
      email: json['email'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String?,
      status: json['status'] as String?,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'error': error,
      'code': code,
      'userId': userId,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'role': role,
      'status': status,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  UserResult copyWith({
    bool? isSuccess,
    String? error,
    String? code,
    String? userId,
    String? email,
    String? name,
    String? avatarUrl,
    String? role,
    String? status,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return UserResult(
      isSuccess: isSuccess ?? this.isSuccess,
      error: error ?? this.error,
      code: code ?? this.code,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      status: status ?? this.status,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  List<Object?> get props => [
    isSuccess,
    error,
    code,
    userId,
    email,
    name,
    avatarUrl,
    role,
    status,
    accessToken,
    refreshToken,
    expiresAt,
  ];
}
