import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/domain/entities/booking_entity.dart';
import 'package:server_module/domain/entities/fixed_schedule_entity.dart';
import 'package:server_module/domain/entities/court_performance_report_entity.dart';

abstract class BookingRepository {
  Future<BaseResponse<List<BookingEntity>>> getBookings({
    String? facilityId,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? view,
    int? limit,
  });

  Future<BaseResponse<CourtPerformanceReportEntity>> getCourtPerformanceReport({
    String? facilityId,
    String? courtId,
    required String dateFrom,
    required String dateTo,
  });

  Future<BaseResponse<AdvancedPerformanceReportEntity>>
  getAdvancedPerformanceReport({
    String? facilityId,
    List<String>? facilityIds,
    String? sportId,
    String? courtId,
    String? status,
    String? include,
    required String dateFrom,
    required String dateTo,
  });

  Future<BaseResponse<BookingEntity>> getBookingById(String id);

  Future<BaseResponse<BookingEntity>> createBooking(Map<String, dynamic> data);

  Future<BaseResponse<BookingEntity>> updateBooking(
    String id,
    Map<String, dynamic> data,
  );

  Future<BaseResponse<BookingEntity>> updateBookingStatus(
    String id,
    String status,
  );

  Future<BaseResponse<BookingEntity>> cancelBooking(String id);

  Future<BaseResponse<FixedScheduleEntity>> createFixedSchedule(
    Map<String, dynamic> data,
  );

  Future<BaseResponse<List<FixedScheduleEntity>>> getFixedSchedules({
    String? status,
    String? type,
  });

  Future<BaseResponse<FixedScheduleEntity>> cancelFixedSchedule(String id);

  Future<BaseResponse<FixedScheduleEntity>> pauseFixedSchedule(String id);

  Future<BaseResponse<FixedScheduleEntity>> resumeFixedSchedule(String id);

  Future<BaseResponse<FixedScheduleEntity>> cancelFixedMatchingOccurrence(
    String id, {
    required String date,
    String? reason,
  });

  Future<BaseResponse<FixedScheduleEntity>> approveFixedSchedule(String id);

  Future<BaseResponse<FixedScheduleEntity>> rejectFixedSchedule(
    String id, {
    String? reason,
  });

  Future<BaseResponse<FixedScheduleEntity>> joinFixedMatchingSchedule(
    String id, {
    required String preferredTeam,
    required int memberCount,
  });

  Future<BaseResponse<FixedScheduleEntity>> leaveFixedMatchingSchedule(
    String id,
  );
}
