import 'package:server_module/server_module.dart';

/// Gọi POST /booking/ để tạo lịch đặt sân
class CreateBookingUseCase {
  final BookingRepository _bookingRepository;

  CreateBookingUseCase(this._bookingRepository);

  /// [bookingDate] dạng "yyyy-MM-dd", e.g. "2026-06-15"
  /// [startMinutes] và [endMinutes] là số phút từ 00:00, e.g. 420 = 07:00
  Future<BaseResponse<BookingEntity>> call({
    required String courtId,
    required String bookingDate,
    required int startMinutes,
    required int endMinutes,
    required double totalPrice,
    String? userId,
    String? guestName,
    String? guestPhone,
  }) async {
    return _bookingRepository.createBooking({
      'courtId': courtId,
      'bookingDate': bookingDate,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'totalPrice': totalPrice,
      'userId': ?userId,
      'guestName': ?guestName,
      'guestPhone': ?guestPhone,
    });
  }
}
