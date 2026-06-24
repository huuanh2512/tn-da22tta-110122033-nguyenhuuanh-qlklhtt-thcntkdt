import 'package:server_module/server_module.dart';
import '../repositories/notification_repository.dart';

class GetNotificationsUseCase {
  const GetNotificationsUseCase(this._repository);

  final AppNotificationRepository _repository;

  Future<List<NotificationEntity>> call() {
    return _repository.getNotifications();
  }
}
