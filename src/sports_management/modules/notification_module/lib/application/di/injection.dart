import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';
import '../../data/datasources/remote/notification_remote_data_source.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/usecases/create_notification_usecase.dart';
import '../../domain/usecases/get_notifications_usecase.dart';
import '../../domain/usecases/mark_notification_read_usecase.dart';
import '../../domain/usecases/mark_all_notifications_read_usecase.dart';
import '../../presentation/cubit/notification_cubit.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  if (!sl.isRegistered<NotificationRemoteDataSource>()) {
    sl.registerLazySingleton<NotificationRemoteDataSource>(
      () => NotificationRemoteDataSourceImpl(sl<NotificationService>()),
    );
  }

  if (!sl.isRegistered<AppNotificationRepository>()) {
    sl.registerLazySingleton<AppNotificationRepository>(
      () => AppNotificationRepositoryImpl(sl<NotificationRemoteDataSource>()),
    );
  }

  if (!sl.isRegistered<CreateNotificationUseCase>()) {
    sl.registerLazySingleton<CreateNotificationUseCase>(
      () => CreateNotificationUseCase(sl<AppNotificationRepository>()),
    );
  }

  if (!sl.isRegistered<GetNotificationsUseCase>()) {
    sl.registerLazySingleton<GetNotificationsUseCase>(
      () => GetNotificationsUseCase(sl<AppNotificationRepository>()),
    );
  }

  if (!sl.isRegistered<MarkNotificationReadUseCase>()) {
    sl.registerLazySingleton<MarkNotificationReadUseCase>(
      () => MarkNotificationReadUseCase(sl<AppNotificationRepository>()),
    );
  }

  if (!sl.isRegistered<MarkAllNotificationsReadUseCase>()) {
    sl.registerLazySingleton<MarkAllNotificationsReadUseCase>(
      () => MarkAllNotificationsReadUseCase(sl<AppNotificationRepository>()),
    );
  }

  if (!sl.isRegistered<NotificationCubit>()) {
    sl.registerLazySingleton<NotificationCubit>(
      () => NotificationCubit(
        getNotifications: sl<GetNotificationsUseCase>(),
        markRead: sl<MarkNotificationReadUseCase>(),
        markAllRead: sl<MarkAllNotificationsReadUseCase>(),
      ),
    );
  }
}
