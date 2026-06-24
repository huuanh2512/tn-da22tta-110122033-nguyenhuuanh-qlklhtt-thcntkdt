import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';
import '../data/datasources/remote/matching_remote_data_source.dart';
import '../data/repositories/matching_repository_impl.dart';
import '../domain/repositories/matching_repository.dart';
import '../domain/usecases/get_matching_sessions_usecase.dart';
import '../domain/usecases/get_matching_session_detail_usecase.dart';
import '../domain/usecases/create_matching_session_usecase.dart';
import '../domain/usecases/join_matching_session_usecase.dart';
import '../domain/usecases/leave_matching_session_usecase.dart';
import '../domain/usecases/update_member_status_usecase.dart';
import '../domain/usecases/update_session_status_usecase.dart';
import '../domain/usecases/join_queue_usecase.dart';
import '../domain/usecases/leave_queue_usecase.dart';
import '../domain/usecases/get_queue_status_usecase.dart';
import '../presentation/bloc/matching_bloc.dart';
import '../presentation/bloc/match_queue_bloc.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // Remote DataSource
  if (!sl.isRegistered<MatchingRemoteDataSource>()) {
    sl.registerLazySingleton<MatchingRemoteDataSource>(
      () => MatchingRemoteDataSourceImpl(sl<DioClient>()),
    );
  }

  // Repository
  if (!sl.isRegistered<MatchingRepository>()) {
    sl.registerLazySingleton<MatchingRepository>(
      () => MatchingRepositoryImpl(sl<MatchingRemoteDataSource>()),
    );
  }

  // UseCases
  if (!sl.isRegistered<GetMatchingSessionsUseCase>()) {
    sl.registerLazySingleton(() => GetMatchingSessionsUseCase(sl<MatchingRepository>()));
  }
  if (!sl.isRegistered<GetMatchingSessionDetailUseCase>()) {
    sl.registerLazySingleton(() => GetMatchingSessionDetailUseCase(sl<MatchingRepository>()));
  }
  if (!sl.isRegistered<CreateMatchingSessionUseCase>()) {
    sl.registerLazySingleton(() => CreateMatchingSessionUseCase(sl<MatchingRepository>()));
  }
  if (!sl.isRegistered<JoinMatchingSessionUseCase>()) {
    sl.registerLazySingleton(() => JoinMatchingSessionUseCase(sl<MatchingRepository>()));
  }
  if (!sl.isRegistered<LeaveMatchingSessionUseCase>()) {
    sl.registerLazySingleton(() => LeaveMatchingSessionUseCase(sl<MatchingRepository>()));
  }
  if (!sl.isRegistered<UpdateMemberStatusUseCase>()) {
    sl.registerLazySingleton(() => UpdateMemberStatusUseCase(sl<MatchingRepository>()));
  }
  if (!sl.isRegistered<UpdateSessionStatusUseCase>()) {
    sl.registerLazySingleton(() => UpdateSessionStatusUseCase(sl<MatchingRepository>()));
  }
  if (!sl.isRegistered<JoinQueueUseCase>()) {
    sl.registerLazySingleton(() => JoinQueueUseCase(sl<MatchingRepository>()));
  }
  if (!sl.isRegistered<LeaveQueueUseCase>()) {
    sl.registerLazySingleton(() => LeaveQueueUseCase(sl<MatchingRepository>()));
  }
  if (!sl.isRegistered<GetQueueStatusUseCase>()) {
    sl.registerLazySingleton(() => GetQueueStatusUseCase(sl<MatchingRepository>()));
  }

  // BLoCs
  if (!sl.isRegistered<MatchingBloc>()) {
    sl.registerFactory(
      () => MatchingBloc(
        getSessionsUseCase: sl<GetMatchingSessionsUseCase>(),
        getSessionDetailUseCase: sl<GetMatchingSessionDetailUseCase>(),
        createSessionUseCase: sl<CreateMatchingSessionUseCase>(),
        joinSessionUseCase: sl<JoinMatchingSessionUseCase>(),
        leaveSessionUseCase: sl<LeaveMatchingSessionUseCase>(),
        updateMemberStatusUseCase: sl<UpdateMemberStatusUseCase>(),
        updateSessionStatusUseCase: sl<UpdateSessionStatusUseCase>(),
        remoteDataSource: sl<MatchingRemoteDataSource>(),
      ),
    );
  }
  if (!sl.isRegistered<MatchQueueBloc>()) {
    sl.registerFactory(
      () => MatchQueueBloc(
        joinQueueUseCase: sl<JoinQueueUseCase>(),
        leaveQueueUseCase: sl<LeaveQueueUseCase>(),
        getQueueStatusUseCase: sl<GetQueueStatusUseCase>(),
      ),
    );
  }
}
