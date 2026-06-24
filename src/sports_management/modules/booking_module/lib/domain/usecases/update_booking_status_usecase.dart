import 'package:server_module/server_module.dart';

class UpdateBookingStatusUseCase {
  final BookingRepository _repository;

  UpdateBookingStatusUseCase(this._repository);

  Future<BaseResponse<BookingEntity>> call(String id, String status) async {
    return await _repository.updateBookingStatus(id, status);
  }
}
