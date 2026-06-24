import 'package:app_module/app_module.dart';
import 'package:dartz/dartz.dart';
import 'package:authentication_module/data/models/user_result.dart';
import 'package:authentication_module/data/models/sign_in_request.dart';
import 'package:authentication_module/data/models/sign_up_request.dart';
import 'package:authentication_module/data/models/sign_out_request.dart';
import 'package:authentication_module/data/models/reset_password_request.dart';
import 'package:authentication_module/data/models/update_profile_request.dart';

abstract class UserRepository {
  Future<Either<Failure, UserResult>> signIn(SignInRequest request);
  Future<Either<Failure, UserResult>> signUp(SignUpRequest request);
  Future<Either<Failure, UserResult>> signOut(SignOutRequest request);
  Future<Either<Failure, UserResult>> refreshSession(String refreshToken);
  Future<Either<Failure, UserResult>> resetPassword(ResetPasswordRequest request);
  Future<Either<Failure, UserResult>> getUserData();
  Future<Either<Failure, UserResult>> updateUserProfile(UpdateProfileRequest request);
  Future<Either<Failure, UserResult>> deleteUserAvatar(String userId);
  Future<Either<Failure, UserResult>> getLocalUser();
  Future<Either<Failure, void>> clearLocalSession();
}