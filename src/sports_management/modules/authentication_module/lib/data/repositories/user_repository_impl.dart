import 'package:app_module/app_module.dart';
import 'package:authentication_module/data/datasources/local/authentication_local_data_source.dart';
import 'package:authentication_module/data/datasources/remote/authentication_remote_data_source.dart';
import 'package:authentication_module/data/datasources/remote/user_remote_data_source.dart';
import 'package:authentication_module/data/models/sign_in_request.dart';
import 'package:authentication_module/data/models/sign_out_request.dart';
import 'package:authentication_module/data/models/sign_up_request.dart';
import 'package:authentication_module/data/models/reset_password_request.dart';
import 'package:authentication_module/data/models/update_profile_request.dart';
import 'package:authentication_module/data/models/user_result.dart';
import 'package:authentication_module/domain/repositories/user_repository.dart';
import 'package:dartz/dartz.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({
    required this._authenticationLocalDataSource,
    required this._authenticationRemoteDataSource,
    required this._userRemoteDataSource,
  });

  final AuthenticationLocalDataSource _authenticationLocalDataSource;
  final AuthenticationRemoteDataSource _authenticationRemoteDataSource;
  final UserRemoteDataSource _userRemoteDataSource;

  @override
  Future<Either<Failure, UserResult>> signUp(SignUpRequest request) async {
    final UserResult result = await _authenticationRemoteDataSource.signUp(
      request,
    );
    return Right(result);
  }

  @override
  Future<Either<Failure, UserResult>> signIn(SignInRequest request) async {
    final UserResult result = await _authenticationRemoteDataSource.signIn(
      request,
    );
    if (result.isSuccess) {
      await _authenticationLocalDataSource.saveUser(result);
    }
    return Right(result);
  }

  @override
  Future<Either<Failure, UserResult>> refreshSession(
    String refreshToken,
  ) async {
    final UserResult result = await _authenticationRemoteDataSource
        .refreshToken(refreshToken);
    if (result.isSuccess) {
      final UserResult? currentUser = await _authenticationLocalDataSource
          .getUser();
      final UserResult merged = (currentUser ?? result).copyWith(
        isSuccess: result.isSuccess,
        error: result.error,
        userId: result.userId,
        email: result.email,
        name: result.name,
        avatarUrl: result.avatarUrl,
        role: result.role,
        status: result.status,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        expiresAt: result.expiresAt,
      );
      await _authenticationLocalDataSource.saveUser(merged);
      return Right(merged);
    }
    return Right(result);
  }

  @override
  Future<Either<Failure, UserResult>> signOut(SignOutRequest request) async {
    final UserResult result = await _authenticationRemoteDataSource.signOut(
      request,
    );
    if (result.isSuccess) {
      await _authenticationLocalDataSource.clearUser();
    }
    return Right(result);
  }

  @override
  Future<Either<Failure, UserResult>> getUserData() async {
    final UserResult result = await _userRemoteDataSource.getUserData();
    return Right(result);
  }

  @override
  Future<Either<Failure, UserResult>> updateUserProfile(
    UpdateProfileRequest request,
  ) async {
    final UserResult result = await _userRemoteDataSource.updateUserProfile(
      request,
    );
    if (result.isSuccess) {
      final UserResult? currentUser = await _authenticationLocalDataSource
          .getUser();
      final base = currentUser ?? result;
      final UserResult merged = UserResult(
        isSuccess: result.isSuccess,
        error: result.error,
        userId: result.userId ?? base.userId,
        email: result.email ?? base.email,
        name: result.name ?? base.name,
        avatarUrl: null,
        role: result.role ?? base.role,
        status: result.status ?? base.status,
        accessToken: base.accessToken,
        refreshToken: base.refreshToken,
        expiresAt: base.expiresAt,
      );
      await _authenticationLocalDataSource.saveUser(merged);
      return Right(merged);
    }
    return Right(result);
  }

  @override
  Future<Either<Failure, UserResult>> deleteUserAvatar(String userId) async {
    final UserResult result = await _userRemoteDataSource.deleteUserAvatar(
      userId,
    );
    if (result.isSuccess) {
      final UserResult? currentUser = await _authenticationLocalDataSource
          .getUser();
      final UserResult merged = (currentUser ?? result).copyWith(
        isSuccess: result.isSuccess,
        error: result.error,
        userId: result.userId,
        email: result.email,
        name: result.name,
        avatarUrl: result.avatarUrl,
        role: result.role,
        status: result.status,
      );
      await _authenticationLocalDataSource.saveUser(merged);
      return Right(merged);
    }
    return Right(result);
  }

  @override
  Future<Either<Failure, UserResult>> resetPassword(
    ResetPasswordRequest request,
  ) async {
    final UserResult result = await _authenticationRemoteDataSource
        .resetPassword(request);
    return Right(result);
  }

  @override
  Future<Either<Failure, UserResult>> getLocalUser() async {
    try {
      final UserResult? user = await _authenticationLocalDataSource.getUser();
      if (user != null) {
        return Right(user);
      }
      return const Left(
        CacheFailure(message: 'No user session found in cache'),
      );
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearLocalSession() async {
    try {
      await _authenticationLocalDataSource.clearUser();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }
}
