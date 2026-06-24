import '../../data/datasources/local/authentication_local_data_source.dart';
import '../../data/datasources/remote/authentication_remote_data_source.dart';
import '../../data/datasources/remote/user_remote_data_source.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/repositories/user_repository.dart' as auth_domain;
import '../../domain/usecases/get_user_data_usecase.dart';
import '../../domain/usecases/refresh_session_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../domain/usecases/delete_user_avatar_usecase.dart';
import '../../domain/usecases/get_local_user_usecase.dart';
import '../../domain/usecases/clear_local_session_usecase.dart';
import '../../application/session/session_manager.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart' as server_module;

final sl = GetIt.instance;

class _ServerAuthRepositoryAdapter implements server_module.AuthRepository {
  _ServerAuthRepositoryAdapter(this._authService);

  final server_module.AuthService _authService;

  @override
  Future<server_module.BaseResponse<dynamic>> register({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) {
    return _authService.register(
      server_module.AuthRegisterRequest(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      ),
    );
  }

  @override
  Future<server_module.BaseResponse<dynamic>> signIn({
    required String email,
    required String password,
  }) {
    return _authService.signIn(email: email, password: password);
  }

  @override
  Future<server_module.BaseResponse<dynamic>> refreshToken({
    required String refreshToken,
  }) {
    return _authService.refreshToken(refreshToken: refreshToken);
  }

  @override
  Future<server_module.BaseResponse<dynamic>> signOut({
    required String userId,
  }) {
    return _authService.signOut(userId: userId);
  }

  @override
  Future<server_module.BaseResponse<dynamic>> verifyEmail({
    required String email,
    required String otp,
  }) {
    return _authService.verifyEmail(email: email, otp: otp);
  }

  @override
  Future<server_module.BaseResponse<dynamic>> resendVerification({
    required String email,
  }) {
    return _authService.resendVerification(email: email);
  }

  @override
  Future<server_module.BaseResponse<dynamic>> forgotPassword({
    required String email,
  }) {
    return _authService.forgotPassword(email: email);
  }

  @override
  Future<server_module.BaseResponse<dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _authService.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }
}

class _ServerUserRepositoryAdapter implements server_module.UserRepository {
  _ServerUserRepositoryAdapter(this._userService);

  final server_module.UserService _userService;

  server_module.BaseResponse<server_module.UserEntity> _mapToUserEntityResponse(
    server_module.BaseResponse<dynamic> response,
  ) {
    if (!response.success || response.data == null) {
      return server_module.BaseResponse<server_module.UserEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final userMap = (rawData['user'] as Map<String, dynamic>?) ?? rawData;
      final profileMap = userMap['profile'] as Map<String, dynamic>?;

      final userEntity = server_module.UserEntity(
        id: userMap['id']?.toString() ?? userMap['_id']?.toString() ?? '',
        email: userMap['email']?.toString(),
        name:
            profileMap?['name']?.toString() ??
            profileMap?['fullName']?.toString() ??
            userMap['name']?.toString(),
        avatar:
            profileMap?['avatarUrl']?.toString() ??
            profileMap?['avatar']?.toString() ??
            userMap['avatar']?.toString(),
        role: userMap['role']?.toString(),
        status: userMap['status']?.toString(),
        createdAt: userMap['createdAt'] != null
            ? DateTime.tryParse(userMap['createdAt'].toString())
            : null,
      );

      return server_module.BaseResponse<server_module.UserEntity>(
        success: response.success,
        message: response.message,
        data: userEntity,
      );
    } catch (_) {
      return server_module.BaseResponse<server_module.UserEntity>(
        success: false,
        message: 'Lỗi parse dữ liệu UserEntity',
        data: null,
      );
    }
  }

  server_module.BaseResponse<List<server_module.UserEntity>>
  _mapToUserEntityListResponse(server_module.BaseResponse<dynamic> response) {
    if (!response.success || response.data == null) {
      return server_module.BaseResponse<List<server_module.UserEntity>>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final itemsList = rawData['items'] as List<dynamic>?;

      final list = <server_module.UserEntity>[];
      if (itemsList != null) {
        for (final item in itemsList) {
          if (item is Map<String, dynamic>) {
            final profileMap = item['profile'] as Map<String, dynamic>?;
            list.add(
              server_module.UserEntity(
                id: item['id']?.toString() ?? item['_id']?.toString() ?? '',
                email: item['email']?.toString(),
                name:
                    profileMap?['name']?.toString() ??
                    profileMap?['fullName']?.toString() ??
                    item['name']?.toString(),
                avatar:
                    profileMap?['avatarUrl']?.toString() ??
                    profileMap?['avatar']?.toString() ??
                    item['avatar']?.toString(),
                role: item['role']?.toString(),
                status: item['status']?.toString(),
                createdAt: item['createdAt'] != null
                    ? DateTime.tryParse(item['createdAt'].toString())
                    : null,
              ),
            );
          }
        }
      }

      return server_module.BaseResponse<List<server_module.UserEntity>>(
        success: response.success,
        message: response.message,
        data: list,
      );
    } catch (_) {
      return server_module.BaseResponse<List<server_module.UserEntity>>(
        success: false,
        message: 'Lỗi parse danh sách UserEntity',
        data: null,
      );
    }
  }

  @override
  Future<server_module.BaseResponse<List<server_module.UserEntity>>>
  getUsers() {
    return _userService.getUsers().then(_mapToUserEntityListResponse);
  }

  @override
  Future<server_module.BaseResponse<server_module.UserEntity>> getUserById(
    String id,
  ) {
    return _userService.getUserById(id).then(_mapToUserEntityResponse);
  }

  @override
  Future<server_module.BaseResponse<server_module.UserEntity>> updateUser(
    String id,
    Map<String, dynamic> data,
  ) {
    return _userService.updateUser(id, data).then(_mapToUserEntityResponse);
  }

  @override
  Future<server_module.BaseResponse<server_module.UserEntity>> updateUserRole(
    String id,
    String role,
  ) {
    return _userService.updateUserRole(id, role).then(_mapToUserEntityResponse);
  }

  @override
  Future<server_module.BaseResponse<server_module.UserEntity>> updateUserStatus(
    String id,
    String status,
  ) {
    return _userService
        .updateUserStatus(id, status)
        .then(_mapToUserEntityResponse);
  }

  @override
  Future<server_module.BaseResponse<server_module.UserEntity>> assignFacility(
    String id,
    String facilityId,
  ) {
    return _userService
        .assignFacility(id, facilityId)
        .then(_mapToUserEntityResponse);
  }
}

Future<void> initInjection() async {
  // Storage
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  // Local Data Source
  sl.registerLazySingleton<AuthenticationLocalDataSource>(
    () => AuthenticationLocalDataSourceImpl(
      secureStorage: sl<FlutterSecureStorage>(),
    ),
  );

  // Configure AuthTokenProviderRegistry for server_module
  server_module.AuthTokenProviderRegistry.configure(() async {
    try {
      final localDataSource = sl<AuthenticationLocalDataSource>();
      return await localDataSource.getAccessToken();
    } catch (_) {
      return null;
    }
  });

  // Server Adapters
  sl.registerLazySingleton<server_module.AuthRepository>(
    () => _ServerAuthRepositoryAdapter(sl<server_module.AuthService>()),
  );

  sl.registerLazySingleton<server_module.UserRepository>(
    () => _ServerUserRepositoryAdapter(sl<server_module.UserService>()),
  );

  // Remote Data Sources
  sl.registerLazySingleton<AuthenticationRemoteDataSource>(
    () => AuthenticationRemoteDataSourceImpl(
      authRepository: sl<server_module.AuthRepository>(),
    ),
  );

  sl.registerLazySingleton<UserRemoteDataSource>(
    () => UserRemoteDataSourceImpl(
      userRepository: sl<server_module.UserRepository>(),
      authenticationLocalDataSource: sl<AuthenticationLocalDataSource>(),
    ),
  );

  // Repository
  sl.registerLazySingleton<auth_domain.UserRepository>(
    () => UserRepositoryImpl(
      authenticationLocalDataSource: sl<AuthenticationLocalDataSource>(),
      authenticationRemoteDataSource: sl<AuthenticationRemoteDataSource>(),
      userRemoteDataSource: sl<UserRemoteDataSource>(),
    ),
  );

  // UseCases
  sl.registerLazySingleton<SignInUseCase>(
    () => SignInUseCase(sl<auth_domain.UserRepository>()),
  );

  sl.registerLazySingleton<SignUpUseCase>(
    () => SignUpUseCase(sl<auth_domain.UserRepository>()),
  );

  sl.registerLazySingleton<SignOutUseCase>(
    () => SignOutUseCase(sl<auth_domain.UserRepository>()),
  );

  sl.registerLazySingleton<RefreshSessionUseCase>(
    () => RefreshSessionUseCase(sl<auth_domain.UserRepository>()),
  );

  sl.registerLazySingleton<ResetPasswordUseCase>(
    () => ResetPasswordUseCase(sl<auth_domain.UserRepository>()),
  );

  sl.registerLazySingleton<UpdateProfileUseCase>(
    () => UpdateProfileUseCase(sl<auth_domain.UserRepository>()),
  );

  sl.registerLazySingleton<DeleteUserAvatarUseCase>(
    () => DeleteUserAvatarUseCase(sl<auth_domain.UserRepository>()),
  );

  sl.registerLazySingleton<GetUserDataUseCase>(
    () => GetUserDataUseCase(sl<auth_domain.UserRepository>()),
  );

  sl.registerLazySingleton<GetLocalUserUseCase>(
    () => GetLocalUserUseCase(sl<auth_domain.UserRepository>()),
  );

  sl.registerLazySingleton<ClearLocalSessionUseCase>(
    () => ClearLocalSessionUseCase(sl<auth_domain.UserRepository>()),
  );

  // Session Manager
  sl.registerLazySingleton<SessionManager>(
    () => SessionManager(
      localDataSource: sl<AuthenticationLocalDataSource>(),
      clearLocalSessionUseCase: sl<ClearLocalSessionUseCase>(),
    ),
  );

  // Bloc
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      sl<SignInUseCase>(),
      sl<SignUpUseCase>(),
      sl<SignOutUseCase>(),
      sl<RefreshSessionUseCase>(),
      sl<ResetPasswordUseCase>(),
    ),
  );
}
