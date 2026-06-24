import 'package:server_module/server_module.dart';
import '../entities/payment_detail_entity.dart';

class CreatePaymentUseCase {
  final PaymentRepository _repository;

  CreatePaymentUseCase(this._repository);

  Future<BaseResponse<PaymentDetailEntity>> call({
    required String bookingId,
    required double amount,
    required String method,
    required String transactionId,
  }) async {
    final response = await _repository.createPayment({
      'bookingId': bookingId,
      'amount': amount,
      'method': method,
      'transactionId': transactionId,
    });

    if (response.success && response.data != null) {
      final data = response.data;
      if (data is PaymentDetailEntity) {
        return BaseResponse(
          success: true,
          message: response.message,
          data: data,
        );
      }
    }

    return BaseResponse(
      success: response.success,
      message: response.message,
      data: null,
    );
  }
}
