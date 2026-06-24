import 'package:server_module/server_module.dart';
import '../entities/booking_detail_entity.dart';

class GetBookingDetailUseCase {
  final BookingRepository _repository;

  GetBookingDetailUseCase(this._repository);

  Future<BaseResponse<BookingDetailEntity>> call(String id) async {
    final response = await _repository.getBookingById(id);

    if (response.success && response.data != null) {
      final data = response.data;
      if (data is BookingDetailEntity) {
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
