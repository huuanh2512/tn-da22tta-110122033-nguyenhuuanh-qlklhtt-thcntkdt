import 'package:facility_module/facility_module.dart';
import 'package:server_module/server_module.dart';
import '../entities/booking_detail_entity.dart';

class GetBookingHistoryUseCase {
  final BookingRepository _repository;
  final CourtRepository _courtRepository;
  final GetSportsUseCase _getSportsUseCase;

  GetBookingHistoryUseCase(
    this._repository,
    this._courtRepository,
    this._getSportsUseCase,
  );

  Future<BaseResponse<List<BookingDetailEntity>>> call({
    String? status,
    String? facilityId,
    String? dateFrom,
    String? dateTo,
    String? view,
    int? limit,
  }) async {
    final response = await _repository.getBookings(
      facilityId: facilityId,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
      view: view,
      limit: limit,
    );

    if (response.success && response.data != null) {
      final List<BookingDetailEntity> rawHistory = response.data!
          .whereType<BookingDetailEntity>()
          .toList();

      // Fetch courts to associate correct facilityId
      final courtsResponse = await _courtRepository.getCourts();
      final Map<String, CourtEntity> courtMap = {};
      if (courtsResponse.success && courtsResponse.data != null) {
        for (final court in courtsResponse.data!) {
          courtMap[court.id] = court;
        }
      }

      final sportsResponse = await _getSportsUseCase();
      final Map<String, String> sportNameMap = {};
      if (sportsResponse.success && sportsResponse.data != null) {
        for (final sport in sportsResponse.data!) {
          final name = sport.name;
          if (name != null && name.isNotEmpty) {
            sportNameMap[sport.id] = name;
          }
        }
      }

      final List<BookingDetailEntity> history = rawHistory.map((b) {
        if (b.courtId != null && courtMap.containsKey(b.courtId)) {
          final courtInfo = courtMap[b.courtId]!;
          return BookingDetailEntity(
            id: b.id,
            userId: b.userId,
            guestName: b.guestName,
            guestPhone: b.guestPhone,
            user: b.user,
            courtId: b.courtId,
            court: courtInfo,
            courtName: b.courtName ?? courtInfo.name,
            courtCode: b.courtCode,
            sportName: sportNameMap[courtInfo.sportId],
            bookingDate: b.bookingDate,
            startMinutes: b.startMinutes,
            endMinutes: b.endMinutes,
            totalPrice: b.totalPrice,
            status: b.status,
            paymentStatus: b.paymentStatus,
            cancelReason: b.cancelReason,
            cancelledBy: b.cancelledBy,
            cancelledAt: b.cancelledAt,
            createdAt: b.createdAt,
            fixedScheduleId: b.fixedScheduleId,
            isFixedSchedule: b.isFixedSchedule,
            isMatching: b.isMatching,
            matchingSessionId: b.matchingSessionId,
            isHost: b.isHost,
            paymentPolicy: b.paymentPolicy,
            myPaymentStatus: b.myPaymentStatus,
            myPaymentAmount: b.myPaymentAmount,
            membersCount: b.membersCount,
          );
        }
        return b;
      }).toList();

      if (status != null) {
        return BaseResponse(
          success: true,
          message: response.message,
          data: history.where((booking) {
            final isActiveFixedScheduleBooking =
                booking.status == 'PENDING' &&
                (booking.isFixedSchedule == true ||
                    booking.fixedScheduleId != null);

            if (status == 'PENDING') {
              return booking.status == status && !isActiveFixedScheduleBooking;
            }
            if (status == 'CONFIRMED') {
              return booking.status == status || isActiveFixedScheduleBooking;
            }
            return booking.status == status;
          }).toList(),
        );
      }
      return BaseResponse(
        success: true,
        message: response.message,
        data: history,
      );
    }

    return BaseResponse(
      success: response.success,
      message: response.message,
      data: null,
    );
  }
}
