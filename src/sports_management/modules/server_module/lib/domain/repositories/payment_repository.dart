import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/domain/entities/payment_entity.dart';

abstract class PaymentRepository {
  Future<BaseResponse<List<PaymentEntity>>> getPayments();
  
  Future<BaseResponse<PaymentEntity>> createPayment(Map<String, dynamic> data);
  
  Future<BaseResponse<PaymentEntity>> updatePaymentStatus(String id, String status);
}