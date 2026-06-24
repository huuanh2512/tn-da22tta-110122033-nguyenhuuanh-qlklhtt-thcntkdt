import 'package:server_module/server_module.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/remote/notification_remote_data_source.dart';

class AppNotificationRepositoryImpl implements AppNotificationRepository {
  AppNotificationRepositoryImpl(this._remoteDataSource);

  final NotificationRemoteDataSource _remoteDataSource;

  @override
  Future<List<NotificationEntity>> getNotifications() async {
    final response = await _remoteDataSource.getNotifications();
    if (response.success && response.data != null) {
      try {
        final List list;
        if (response.data is List) {
          list = response.data as List;
        } else if (response.data is Map) {
          final dataMap = response.data as Map<String, dynamic>;
          list = dataMap['items'] as List? ?? [];
        } else {
          return [];
        }
        return list.map((json) {
          final model = NotificationModel.fromJson(json as Map<String, dynamic>);
          return NotificationEntity(
            id: model.id,
            userId: model.userId,
            title: model.title,
            content: model.content,
            type: model.type,
            metadata: model.metadata,
            isRead: model.isRead,
            createdAt: model.createdAt,
          );
        }).toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  @override
  Future<BaseResponse<dynamic>> markAsRead(String id) {
    return _remoteDataSource.markAsRead(id);
  }

  @override
  Future<BaseResponse<dynamic>> markAllAsRead() {
    return _remoteDataSource.markAllAsRead();
  }

  @override
  Future<BaseResponse<dynamic>> createNotification(Map<String, dynamic> data) {
    return _remoteDataSource.createNotification(data);
  }
}
