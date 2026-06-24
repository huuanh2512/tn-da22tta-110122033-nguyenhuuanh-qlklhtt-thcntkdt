import 'package:server_module/server_module.dart';
import '../repositories/notification_repository.dart';

class MarkNotificationReadUseCase {
  const MarkNotificationReadUseCase(this._repository);

  final AppNotificationRepository _repository;

  Future<BaseResponse<dynamic>> call(String id) {
    return _repository.markAsRead(id);
  }
}
