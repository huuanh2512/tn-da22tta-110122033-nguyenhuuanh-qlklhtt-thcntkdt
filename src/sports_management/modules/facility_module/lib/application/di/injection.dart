import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';
import '../../data/datasources/remote/facility_remote_data_source.dart';
import '../../data/datasources/remote/sport_remote_data_source.dart';
import '../../data/repositories/facility_repository_impl.dart';
import '../../data/repositories/sport_repository_impl.dart';
import '../../domain/usecases/get_facilities_usecase.dart';
import '../../domain/usecases/get_sports_usecase.dart';

import '../../domain/usecases/create_facility_usecase.dart';
import '../../domain/usecases/update_facility_usecase.dart';
import '../../domain/usecases/delete_facility_usecase.dart';
import '../../domain/usecases/get_facility_courts_usecase.dart';
import '../../domain/usecases/create_court_usecase.dart';
import '../../domain/usecases/update_court_usecase.dart';
import '../../domain/usecases/delete_court_usecase.dart';
import '../../domain/usecases/get_staff_users_usecase.dart';
import '../../domain/usecases/create_sport_usecase.dart';
import '../../domain/usecases/update_sport_usecase.dart';
import '../../domain/usecases/delete_sport_usecase.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // DataSources
  if (!sl.isRegistered<FacilityRemoteDataSource>()) {
    sl.registerLazySingleton<FacilityRemoteDataSource>(
      () => FacilityRemoteDataSourceImpl(sl<FacilityService>()),
    );
  }

  if (!sl.isRegistered<SportRemoteDataSource>()) {
    sl.registerLazySingleton<SportRemoteDataSource>(
      () => SportRemoteDataSourceImpl(sl<SportService>()),
    );
  }

  // Repositories
  if (!sl.isRegistered<FacilityRepository>()) {
    sl.registerLazySingleton<FacilityRepository>(
      () => FacilityRepositoryImpl(sl<FacilityRemoteDataSource>()),
    );
  }

  if (!sl.isRegistered<SportRepository>()) {
    sl.registerLazySingleton<SportRepository>(
      () => SportRepositoryImpl(sl<SportRemoteDataSource>()),
    );
  }

  // UseCases
  if (!sl.isRegistered<GetFacilitiesUseCase>()) {
    sl.registerLazySingleton<GetFacilitiesUseCase>(
      () => GetFacilitiesUseCase(sl<FacilityRepository>()),
    );
  }

  if (!sl.isRegistered<GetSportsUseCase>()) {
    sl.registerLazySingleton<GetSportsUseCase>(
      () => GetSportsUseCase(sl<SportRepository>()),
    );
  }

  if (!sl.isRegistered<CreateFacilityUseCase>()) {
    sl.registerLazySingleton<CreateFacilityUseCase>(
      () => CreateFacilityUseCase(sl<FacilityRepository>()),
    );
  }

  if (!sl.isRegistered<UpdateFacilityUseCase>()) {
    sl.registerLazySingleton<UpdateFacilityUseCase>(
      () => UpdateFacilityUseCase(sl<FacilityRepository>()),
    );
  }

  if (!sl.isRegistered<DeleteFacilityUseCase>()) {
    sl.registerLazySingleton<DeleteFacilityUseCase>(
      () => DeleteFacilityUseCase(sl<FacilityRepository>()),
    );
  }

  if (!sl.isRegistered<GetFacilityCourtsUseCase>()) {
    sl.registerLazySingleton<GetFacilityCourtsUseCase>(
      () => GetFacilityCourtsUseCase(sl<CourtRepository>()),
    );
  }

  if (!sl.isRegistered<CreateCourtUseCase>()) {
    sl.registerLazySingleton<CreateCourtUseCase>(
      () => CreateCourtUseCase(sl<CourtRepository>()),
    );
  }

  if (!sl.isRegistered<UpdateCourtUseCase>()) {
    sl.registerLazySingleton<UpdateCourtUseCase>(
      () => UpdateCourtUseCase(sl<CourtRepository>()),
    );
  }

  if (!sl.isRegistered<DeleteCourtUseCase>()) {
    sl.registerLazySingleton<DeleteCourtUseCase>(
      () => DeleteCourtUseCase(sl<CourtRepository>()),
    );
  }

  if (!sl.isRegistered<GetStaffUsersUseCase>()) {
    sl.registerLazySingleton<GetStaffUsersUseCase>(
      () => GetStaffUsersUseCase(sl<DioClient>()),
    );
  }

  if (!sl.isRegistered<CreateSportUseCase>()) {
    sl.registerLazySingleton<CreateSportUseCase>(
      () => CreateSportUseCase(sl<SportRepository>()),
    );
  }

  if (!sl.isRegistered<UpdateSportUseCase>()) {
    sl.registerLazySingleton<UpdateSportUseCase>(
      () => UpdateSportUseCase(sl<SportRepository>()),
    );
  }

  if (!sl.isRegistered<DeleteSportUseCase>()) {
    sl.registerLazySingleton<DeleteSportUseCase>(
      () => DeleteSportUseCase(sl<SportRepository>()),
    );
  }
}
