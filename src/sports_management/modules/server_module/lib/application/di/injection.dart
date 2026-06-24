import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/remote/services/auth_service.dart';
import 'package:server_module/data/remote/services/user_service.dart';
import 'package:server_module/data/remote/services/booking_service.dart';
import 'package:server_module/data/remote/services/facility_service.dart';
import 'package:server_module/data/remote/services/court_service.dart';
import 'package:server_module/data/remote/services/sport_service.dart';
import 'package:server_module/data/remote/services/payment_service.dart';
import 'package:server_module/data/remote/services/notification_service.dart';
import 'package:server_module/data/remote/services/review_service.dart';
import 'package:server_module/data/remote/services/upload_service.dart';
import 'package:server_module/data/remote/services/content_service.dart';

Future<void> initInjection([dynamic locator]) async {
  final sl =
      locator ??
      (throw StateError(
        'Pass a GetIt instance when calling initInjection from outside this package',
      ));

  sl.registerLazySingleton<DioClient>(() => DioClient());

  sl.registerLazySingleton<AuthService>(() => AuthService(sl<DioClient>()));
  sl.registerLazySingleton<UserService>(() => UserService(sl<DioClient>()));
  sl.registerLazySingleton<BookingService>(
    () => BookingService(sl<DioClient>()),
  );
  sl.registerLazySingleton<FacilityService>(
    () => FacilityService(sl<DioClient>()),
  );
  sl.registerLazySingleton<CourtService>(() => CourtService(sl<DioClient>()));
  sl.registerLazySingleton<SportService>(() => SportService(sl<DioClient>()));
  sl.registerLazySingleton<PaymentService>(
    () => PaymentService(sl<DioClient>()),
  );
  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(sl<DioClient>()),
  );
  sl.registerLazySingleton<ReviewService>(() => ReviewService(sl<DioClient>()));
  sl.registerLazySingleton<UploadService>(() => UploadService(sl<DioClient>()));
  sl.registerLazySingleton<ContentService>(
    () => ContentService(sl<DioClient>()),
  );
}
