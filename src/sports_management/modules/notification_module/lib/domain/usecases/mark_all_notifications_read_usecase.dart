import 'package:server_module/server_module.dart';
import '../repositories/notification_repository.dart';

class MarkAllNotificationsReadUseCase {
  const MarkAllNotificationsReadUseCase(this._repository);

  final AppNotificationRepository _repository;

  Future<BaseResponse<dynamic>> call() {
    return _repository.markAllAsRead();
  }
}
