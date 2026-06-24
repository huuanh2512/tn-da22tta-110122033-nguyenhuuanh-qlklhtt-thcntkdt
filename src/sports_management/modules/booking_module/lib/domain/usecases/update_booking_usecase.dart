import 'package:server_module/server_module.dart';

class UpdateBookingUseCase {
  final BookingRepository _bookingRepository;

  UpdateBookingUseCase(this._bookingRepository);

  Future<BaseResponse<BookingEntity>> call(
    String id, {
    String? courtId,
    String? bookingDate,
    int? startMinutes,
    int? endMinutes,
  }) async {
    return _bookingRepository.updateBooking(id, {
      'courtId': ?courtId,
      'bookingDate': ?bookingDate,
      'startMinutes': ?startMinutes,
      'endMinutes': ?endMinutes,
    });
  }
}
