import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/domain/entities/notification_entity.dart';

abstract class NotificationRepository {
  Future<BaseResponse<List<NotificationEntity>>> getNotifications();
  
  Future<BaseResponse<NotificationEntity>> createNotification(Map<String, dynamic> data);
  
  Future<BaseResponse<dynamic>> markAllAsRead();
  
  Future<BaseResponse<dynamic>> markAsRead(String id);
}