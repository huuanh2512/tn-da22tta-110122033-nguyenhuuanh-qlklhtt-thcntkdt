import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/auth/auth_register_request.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class AuthService {
  final DioClient _dioClient;

  AuthService(this._dioClient);

  Future<BaseResponse<dynamic>> register(AuthRegisterRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/register',
        data: {
          'email': request.email,
          'password': request.password,
          if (request.fullName != null && request.fullName!.trim().isNotEmpty)
            'fullName': request.fullName!.trim(),
          if (request.phone != null && request.phone!.trim().isNotEmpty)
            'phone': request.phone!.trim(),
        },
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/sign-in',
        data: {'email': email, 'password': password},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> refreshToken({
    required String refreshToken,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> signOut({required String userId}) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/sign-out',
        data: {'userId': userId},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> verifyEmail({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/verify-email',
        data: {'email': email, 'otp': otp},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> resendVerification({
    required String email,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/resend-verification',
        data: {'email': email},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> firebaseRegister({
    required String firebaseIdToken,
    String? fullName,
    String? phone,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/firebase/register',
        data: {
          'firebaseIdToken': firebaseIdToken,
          if (fullName?.trim().isNotEmpty == true) 'fullName': fullName!.trim(),
          if (phone?.trim().isNotEmpty == true) 'phone': phone!.trim(),
        },
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> firebaseCompleteEmailVerification(
    String firebaseIdToken,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/firebase/complete-email-verification',
        data: {'firebaseIdToken': firebaseIdToken},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> firebaseLogin(String firebaseIdToken) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/firebase/login',
        data: {'firebaseIdToken': firebaseIdToken},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> forgotPassword({required String email}) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/reset-password',
        data: {'email': email, 'otp': otp, 'newPassword': newPassword},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> changePassword({
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/change-password',
        data: {'otp': otp, 'newPassword': newPassword},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}
