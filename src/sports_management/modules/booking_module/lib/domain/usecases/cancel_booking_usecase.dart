import 'package:server_module/server_module.dart';

class CancelBookingUseCase {
  final BookingRepository _repository;

  CancelBookingUseCase(this._repository);

  Future<BaseResponse<BookingEntity>> call(String id) async {
    return _repository.cancelBooking(id);
  }
}
