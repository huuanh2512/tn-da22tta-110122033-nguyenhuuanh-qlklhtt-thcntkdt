import 'package:server_module/server_module.dart';
import '../entities/payment_detail_entity.dart';

class GetPaymentsUseCase {
  final PaymentRepository _repository;

  GetPaymentsUseCase(this._repository);

  Future<BaseResponse<List<PaymentDetailEntity>>> call({String? status}) async {
    final response = await _repository.getPayments();

    if (response.success && response.data != null) {
      final List<PaymentDetailEntity> payments =
          response.data!.whereType<PaymentDetailEntity>().toList();

      if (status != null) {
        return BaseResponse(
          success: true,
          message: response.message,
          data: payments.where((p) => p.status == status).toList(),
        );
      }
      return BaseResponse(
        success: true,
        message: response.message,
        data: payments,
      );
    }

    return BaseResponse(
      success: response.success,
      message: response.message,
      data: null,
    );
  }
}
