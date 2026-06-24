import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class NotificationService {
  final DioClient _dioClient;

  NotificationService(this._dioClient);

  Future<BaseResponse<dynamic>> getNotifications() async {
    try {
      final response = await _dioClient.dio.get('/notification/');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> createNotification(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.post('/notification/', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> markAllAsRead() async {
    try {
      final response = await _dioClient.dio.put('/notification/mark-all-read');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> markAsRead(String id) async {
    try {
      final response = await _dioClient.dio.put('/notification/$id/read');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}