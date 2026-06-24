import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class PaymentService {
  final DioClient _dioClient;

  PaymentService(this._dioClient);

  Future<BaseResponse<dynamic>> getPayments() async {
    try {
      final response = await _dioClient.dio.get('/payment/');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> createPayment(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.post('/payment/', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> updatePaymentStatus(String id, String status) async {
    try {
      final response = await _dioClient.dio.put(
        '/payment/$id/status',
        data: {'status': status},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}