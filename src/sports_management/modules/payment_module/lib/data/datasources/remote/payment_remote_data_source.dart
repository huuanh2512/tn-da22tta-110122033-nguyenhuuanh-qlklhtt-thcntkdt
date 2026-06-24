import 'package:server_module/server_module.dart';

abstract class PaymentRemoteDataSource {
  Future<BaseResponse<dynamic>> getPayments();
  Future<BaseResponse<dynamic>> createPayment(Map<String, dynamic> data);
  Future<BaseResponse<dynamic>> updatePaymentStatus(String id, String status);
}

class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  final PaymentService _paymentService;
  final DioClient _dioClient;

  PaymentRemoteDataSourceImpl(this._paymentService, this._dioClient);

  @override
  Future<BaseResponse<dynamic>> getPayments() async {
    final dio = _dioClient.dio;
    final dioResponse = await dio.get('/payment/', queryParameters: {'limit': 10000});
    return BaseResponse.fromJson(dioResponse.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> createPayment(Map<String, dynamic> data) {
    return _paymentService.createPayment(data);
  }

  @override
  Future<BaseResponse<dynamic>> updatePaymentStatus(String id, String status) {
    return _paymentService.updatePaymentStatus(id, status);
  }
}
