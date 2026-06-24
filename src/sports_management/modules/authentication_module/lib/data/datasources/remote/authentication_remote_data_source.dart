import 'package:authentication_module/data/models/reset_password_request.dart';
import 'package:authentication_module/data/models/sign_in_request.dart';
import 'package:authentication_module/data/models/sign_out_request.dart';
import 'package:authentication_module/data/models/sign_up_request.dart';
import 'package:authentication_module/data/models/user_result.dart';
import 'package:flutter/foundation.dart';
import 'package:server_module/server_module.dart';

abstract class AuthenticationRemoteDataSource {
  Future<UserResult> signUp(SignUpRequest request);

  Future<UserResult> signIn(SignInRequest request);

  Future<UserResult> refreshToken(String refreshToken);

  Future<UserResult> signOut(SignOutRequest request);

  Future<UserResult> resetPassword(ResetPasswordRequest request);
}

class AuthenticationRemoteDataSourceImpl
    implements AuthenticationRemoteDataSource {
  AuthenticationRemoteDataSourceImpl({required this._authRepository});

  final AuthRepository _authRepository;

  @override
  Future<UserResult> signUp(SignUpRequest request) async {
    try {
      final result = await _authRepository.register(
        email: request.email.trim().toLowerCase(),
        password: request.password.trim(),
        fullName: request.fullName?.trim(),
        phone: request.phone?.trim(),
      );

      if (!result.success) {
        return UserResult(
          isSuccess: false,
          code: result.code,
          error: result.message ?? 'Đăng ký thất bại.',
        );
      }
      debugPrint('${result.data}');
      return _mapAuthDataToUserResult(result.data);
    } catch (error) {
      return UserResult(isSuccess: false, error: error.toString());
    }
  }

  @override
  Future<UserResult> signIn(SignInRequest request) async {
    try {
      final result = await _authRepository.signIn(
        email: request.username.trim().toLowerCase(),
        password: request.password.trim(),
      );

      if (!result.success) {
        return UserResult(
          isSuccess: false,
          code: result.code,
          error: result.message ?? 'Đăng nhập thất bại.',
        );
      }
      debugPrint('${result.data}');
      return _mapAuthDataToUserResult(result.data);
    } catch (error) {
      return UserResult(isSuccess: false, error: error.toString());
    }
  }

  @override
  Future<UserResult> signOut(SignOutRequest request) async {
    try {
      final result = await _authRepository.signOut(userId: request.token);

      return UserResult(
        isSuccess: result.success,
        error: result.success ? null : result.message,
      );
    } catch (error) {
      return UserResult(isSuccess: false, error: error.toString());
    }
  }

  @override
  Future<UserResult> refreshToken(String refreshToken) async {
    try {
      final result = await _authRepository.refreshToken(
        refreshToken: refreshToken.trim(),
      );

      if (!result.success) {
        return UserResult(
          isSuccess: false,
          error: result.message ?? 'Refresh token thất bại.',
        );
      }
      debugPrint('${result.data}');
      return _mapAuthDataToUserResult(result.data);
    } catch (error) {
      return UserResult(isSuccess: false, error: error.toString());
    }
  }

  @override
  Future<UserResult> resetPassword(ResetPasswordRequest request) async {
    try {
      final result = await _authRepository.resetPassword(
        email: request.email.trim().toLowerCase(),
        otp: request.otp.trim(),
        newPassword: request.newPassword.trim(),
      );

      return UserResult(
        isSuccess: result.success,
        error: result.success ? null : result.message,
      );
    } catch (error) {
      return UserResult(isSuccess: false, error: error.toString());
    }
  }

  UserResult _mapAuthDataToUserResult(dynamic rawData) {
    final Map<String, dynamic>? data = rawData as Map<String, dynamic>?;

    final Map<String, dynamic>? result =
        (data?['result'] as Map<String, dynamic>?) ?? data;

    final bool success = result?['success'] == true;

    if (!success) {
      return UserResult(
        isSuccess: false,
        error: result?['message']?.toString() ?? 'Có lỗi xảy ra.',
      );
    }

    final Map<String, dynamic>? user =
        (data?['user'] as Map<String, dynamic>?) ??
        ((data?['data'] as Map<String, dynamic>?)?['user']
            as Map<String, dynamic>?);

    final Map<String, dynamic>? profile =
        user?['profile'] as Map<String, dynamic>?;

    return UserResult(
      isSuccess: true,
      userId: user?['id']?.toString(),
      email: user?['email']?.toString(),
      name: profile?['name']?.toString(),
      avatarUrl: profile?['avatarUrl']?.toString(),
      role: user?['role']?.toString(),
      status: user?['status']?.toString(),
      accessToken: data?['accessToken']?.toString(),
      refreshToken: data?['refreshToken']?.toString(),
      expiresAt: data?['expiresAt'] != null
          ? DateTime.tryParse(data!['expiresAt'].toString())?.toLocal()
          : null,
    );
  }
}
