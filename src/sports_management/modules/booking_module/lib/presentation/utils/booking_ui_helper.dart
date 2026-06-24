import 'package:server_module/server_module.dart';

class BookingUiHelper {
  const BookingUiHelper._();

  static const vietnamUtcOffset = Duration(hours: 7);
  static const autoCancelReason = 'AUTO_CANCEL_STAFF_NOT_APPROVED';
  static const systemActor = 'SYSTEM';
  static const customerActor = 'CUSTOMER';

  static DateTime? bookingStartAt(BookingEntity booking) {
    final date = _bookingDate(booking);
    final startMinutes = _startMinutes(booking);
    if (date == null || startMinutes == null) return null;

    final parts = date.split('-').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((part) => part == null)) return null;

    final vietnamLocalAsUtc = DateTime.utc(
      parts[0]!,
      parts[1]!,
      parts[2]!,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
    return vietnamLocalAsUtc.subtract(vietnamUtcOffset);
  }

  static Duration? durationUntilStart(BookingEntity booking, {DateTime? now}) {
    final startAt = bookingStartAt(booking);
    if (startAt == null) return null;
    return startAt.difference((now ?? DateTime.now()).toUtc());
  }

  static bool? isWithinTwoHoursBeforeStart(
    BookingEntity booking, {
    DateTime? now,
  }) {
    final duration = durationUntilStart(booking, now: now);
    if (duration == null) return null;
    return !duration.isNegative && duration < const Duration(hours: 2);
  }

  static bool? hasStarted(BookingEntity booking, {DateTime? now}) {
    final duration = durationUntilStart(booking, now: now);
    if (duration == null) return null;
    return duration <= Duration.zero;
  }

  static bool isAutoCancelled(BookingEntity booking) {
    return booking.status == 'CANCELLED' &&
        (booking.cancelReason == autoCancelReason ||
            booking.cancelledBy == systemActor);
  }

  static bool isFixedSchedulePendingPayment(BookingEntity booking) {
    return booking.status == 'PENDING' &&
        (booking.isFixedSchedule == true || booking.fixedScheduleId != null);
  }

  static String statusTextVi(BookingEntity booking) {
    if (isAutoCancelled(booking)) return 'Đã hủy tự động';
    if (isFixedSchedulePendingPayment(booking)) return 'Chờ thanh toán';

    switch (booking.status) {
      case 'PENDING':
        return 'Chờ nhân viên duyệt';
      case 'CONFIRMED':
        return 'Đã được duyệt';
      case 'CANCELLED':
        return 'Đã hủy';
      case 'COMPLETED':
        return 'Đã hoàn tất';
      default:
        return booking.status ?? 'Không xác định';
    }
  }

  static String statusTextEn(BookingEntity booking) {
    if (isAutoCancelled(booking)) return 'Auto-cancelled';
    if (isFixedSchedulePendingPayment(booking)) return 'Pending payment';

    switch (booking.status) {
      case 'PENDING':
        return 'Pending approval';
      case 'CONFIRMED':
        return 'Approved';
      case 'CANCELLED':
        return 'Cancelled';
      case 'COMPLETED':
        return 'Completed';
      default:
        return booking.status ?? 'Unknown';
    }
  }

  static String? cancellationMessageVi(BookingEntity booking) {
    if (booking.status != 'CANCELLED') return null;

    if (isAutoCancelled(booking)) {
      return 'Đơn đặt sân đã bị hủy tự động vì chưa được nhân viên duyệt trước giờ bắt đầu 10 phút.';
    }
    if (booking.cancelledBy == customerActor) {
      return 'Bạn đã hủy đơn đặt sân này.';
    }
    if (booking.cancelReason != null && booking.cancelReason!.isNotEmpty) {
      return 'Đơn đặt sân đã bị hủy. Lý do: ${friendlyCancelReason(booking.cancelReason!)}';
    }
    return 'Đơn đặt sân đã bị hủy.';
  }

  static String? cancellationMessageEn(BookingEntity booking) {
    if (booking.status != 'CANCELLED') return null;

    if (isAutoCancelled(booking)) {
      return 'This booking was automatically cancelled because staff had not approved it 10 minutes before the start time.';
    }
    if (booking.cancelledBy == customerActor) {
      return 'You cancelled this booking.';
    }
    if (booking.cancelReason != null && booking.cancelReason!.isNotEmpty) {
      return 'This booking was cancelled. Reason: ${friendlyCancelReason(booking.cancelReason!)}';
    }
    return 'This booking was cancelled.';
  }

  static String friendlyCancelReason(String reason) {
    switch (reason) {
      case autoCancelReason:
        return 'Chưa được nhân viên duyệt trước giờ bắt đầu 10 phút';
      case 'CUSTOMER_REQUESTED':
        return 'Khách hàng yêu cầu hủy';
      case 'STAFF_OR_ADMIN_REQUESTED':
        return 'Nhân viên hoặc quản trị viên hủy';
      default:
        return reason.replaceAll('_', ' ').toLowerCase();
    }
  }

  static String formatDateTime(DateTime value) {
    return DateDisplayFormatter.dateTime(value);
  }

  static String? _bookingDate(BookingEntity booking) {
    try {
      final dynamic value = booking;
      return value.bookingDate as String?;
    } catch (_) {
      return null;
    }
  }

  static int? _startMinutes(BookingEntity booking) {
    try {
      final dynamic value = booking;
      return value.startMinutes as int?;
    } catch (_) {
      return null;
    }
  }
}
