import 'package:server_module/server_module.dart';
import '../entities/payment_detail_entity.dart';

class UpdatePaymentStatusUseCase {
  final PaymentRepository _repository;

  UpdatePaymentStatusUseCase(this._repository);

  Future<BaseResponse<PaymentDetailEntity>> call(String id, String status) async {
    final response = await _repository.updatePaymentStatus(id, status);

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
