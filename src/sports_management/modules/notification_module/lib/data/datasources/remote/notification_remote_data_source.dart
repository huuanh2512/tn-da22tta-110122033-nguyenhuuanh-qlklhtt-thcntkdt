import 'package:server_module/server_module.dart';

abstract class NotificationRemoteDataSource {
  Future<BaseResponse<dynamic>> getNotifications();
  Future<BaseResponse<dynamic>> markAsRead(String id);
  Future<BaseResponse<dynamic>> markAllAsRead();
  Future<BaseResponse<dynamic>> createNotification(Map<String, dynamic> data);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final NotificationService _notificationService;

  NotificationRemoteDataSourceImpl(this._notificationService);

  @override
  Future<BaseResponse<dynamic>> getNotifications() {
    return _notificationService.getNotifications();
  }

  @override
  Future<BaseResponse<dynamic>> markAsRead(String id) {
    return _notificationService.markAsRead(id);
  }

  @override
  Future<BaseResponse<dynamic>> markAllAsRead() {
    return _notificationService.markAllAsRead();
  }

  @override
  Future<BaseResponse<dynamic>> createNotification(Map<String, dynamic> data) {
    return _notificationService.createNotification(data);
  }
}
