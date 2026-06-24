import 'package:get_it/get_it.dart';
// server_module types are registered via module init
import 'package:server_module/application/di/injection.dart' as server_di;
import 'package:authentication_module/application/di/injection.dart' as auth_di;
import 'package:facility_module/facility_module.dart' as facility_di;
import 'package:booking_module/booking_module.dart' as booking_di;
import 'package:payment_module/payment_module.dart' as payment_di;
import 'package:review_module/review_module.dart' as review_di;
import 'package:user_management_module/user_management_module.dart' as user_management_di;
import 'package:notification_module/notification_module.dart' as notification_di;
import 'package:notification_module/notification_module.dart';
import 'package:matching_module/matching_module.dart' as matching_di;

final GetIt getIt = GetIt.instance;

final class RootInjection {
  const RootInjection._();

  static Future<void> setup() async {
    _registerCore();
    await server_di.initInjection(getIt);
    await auth_di.initInjection();
    await facility_di.initInjection();
    await booking_di.initInjection();
    await payment_di.initInjection();
    await review_di.initInjection();
    await user_management_di.initInjection();
    await notification_di.initInjection();
    await matching_di.initInjection();

    // Link notification event bus stream to NotificationCubit
    final eventBus = getIt<AppNotificationEventBus>();
    getIt<NotificationCubit>().setEventStream(eventBus.stream);
  }

  static void _registerCore() {
    getIt.registerLazySingleton<AppNotificationEventBus>(
      () => AppNotificationEventBus(),
    );
  }
}
