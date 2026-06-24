import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';
import '../../data/datasources/remote/user_management_remote_data_source.dart';
import '../../data/repositories/admin_user_repository_impl.dart';
import '../../domain/usecases/get_users_usecase.dart';
import '../../domain/usecases/update_user_role_usecase.dart';
import '../../domain/usecases/update_user_status_usecase.dart';
import '../../domain/usecases/assign_facility_usecase.dart';
import '../../domain/usecases/update_user_usecase.dart';
import '../../domain/usecases/provision_firebase_user_usecase.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // Remote DataSource
  if (!sl.isRegistered<UserManagementRemoteDataSource>()) {
    sl.registerLazySingleton<UserManagementRemoteDataSource>(
      () => UserManagementRemoteDataSourceImpl(sl<UserService>()),
    );
  }

  // Repository admin riêng – tránh conflict với UserRepository của authentication_module
  if (!sl.isRegistered<AdminUserRepositoryImpl>()) {
    sl.registerLazySingleton<AdminUserRepositoryImpl>(
      () => AdminUserRepositoryImpl(sl<UserManagementRemoteDataSource>()),
    );
  }

  // UseCases
  if (!sl.isRegistered<GetUsersUseCase>()) {
    sl.registerLazySingleton<GetUsersUseCase>(
      () => GetUsersUseCase(sl<AdminUserRepositoryImpl>()),
    );
  }

  if (!sl.isRegistered<UpdateUserRoleUseCase>()) {
    sl.registerLazySingleton<UpdateUserRoleUseCase>(
      () => UpdateUserRoleUseCase(sl<AdminUserRepositoryImpl>()),
    );
  }

  if (!sl.isRegistered<UpdateUserStatusUseCase>()) {
    sl.registerLazySingleton<UpdateUserStatusUseCase>(
      () => UpdateUserStatusUseCase(sl<AdminUserRepositoryImpl>()),
    );
  }

  if (!sl.isRegistered<AssignFacilityUseCase>()) {
    sl.registerLazySingleton<AssignFacilityUseCase>(
      () => AssignFacilityUseCase(sl<AdminUserRepositoryImpl>()),
    );
  }

  if (!sl.isRegistered<UpdateUserUseCase>()) {
    sl.registerLazySingleton<UpdateUserUseCase>(
      () => UpdateUserUseCase(sl<AdminUserRepositoryImpl>()),
    );
  }

  if (!sl.isRegistered<ProvisionFirebaseUserUseCase>()) {
    sl.registerLazySingleton<ProvisionFirebaseUserUseCase>(
      () => ProvisionFirebaseUserUseCase(sl<AdminUserRepositoryImpl>()),
    );
  }
}
