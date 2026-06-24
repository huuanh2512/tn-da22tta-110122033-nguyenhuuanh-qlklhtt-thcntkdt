import 'package:server_module/server_module.dart';
import '../repositories/notification_repository.dart';

class CreateNotificationUseCase {
  const CreateNotificationUseCase(this._repository);

  final AppNotificationRepository _repository;

  Future<BaseResponse<dynamic>> call({
    required String userId,
    required String title,
    required String body,
    String type = 'SYSTEM',
  }) {
    return _repository.createNotification({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
    });
  }
}
