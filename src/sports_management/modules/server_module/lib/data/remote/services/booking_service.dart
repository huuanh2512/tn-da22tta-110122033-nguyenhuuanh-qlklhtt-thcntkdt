import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class BookingService {
  final DioClient _dioClient;

  BookingService(this._dioClient);

  Future<BaseResponse<dynamic>> getBookings() async {
    try {
      final response = await _dioClient.dio.get('/booking/');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> getBookingById(String id) async {
    try {
      final response = await _dioClient.dio.get('/booking/$id');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> createBooking(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.post('/booking/', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> updateBooking(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.dio.put('/booking/$id', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> updateBookingStatus(
    String id,
    String status,
  ) async {
    try {
      final response = await _dioClient.dio.put(
        '/booking/$id/status',
        data: {'status': status},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> cancelBooking(String id) async {
    try {
      final response = await _dioClient.dio.put('/booking/$id/cancel');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}
