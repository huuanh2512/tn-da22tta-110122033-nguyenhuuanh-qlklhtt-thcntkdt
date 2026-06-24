import 'package:server_module/server_module.dart';

abstract class AppNotificationRepository {
  Future<List<NotificationEntity>> getNotifications();
  Future<BaseResponse<dynamic>> markAsRead(String id);
  Future<BaseResponse<dynamic>> markAllAsRead();
  Future<BaseResponse<dynamic>> createNotification(Map<String, dynamic> data);
}
