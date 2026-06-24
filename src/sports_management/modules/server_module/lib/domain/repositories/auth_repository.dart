import 'package:server_module/data/models/base_response.dart';

abstract class AuthRepository {
  Future<BaseResponse<dynamic>> register({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  });

  Future<BaseResponse<dynamic>> signIn({
    required String email,
    required String password,
  });

  Future<BaseResponse<dynamic>> refreshToken({required String refreshToken});

  Future<BaseResponse<dynamic>> signOut({required String userId});

  Future<BaseResponse<dynamic>> verifyEmail({
    required String email,
    required String otp,
  });

  Future<BaseResponse<dynamic>> resendVerification({required String email});

  Future<BaseResponse<dynamic>> forgotPassword({required String email});

  Future<BaseResponse<dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });
}
