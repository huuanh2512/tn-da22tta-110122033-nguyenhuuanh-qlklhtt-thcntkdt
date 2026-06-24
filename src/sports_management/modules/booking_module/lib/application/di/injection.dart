import 'package:get_it/get_it.dart';
import 'package:facility_module/facility_module.dart';
import 'package:server_module/server_module.dart';
import '../../data/datasources/remote/court_remote_data_source.dart';
import '../../data/datasources/remote/booking_remote_data_source.dart';
import '../../data/repositories/court_repository_impl.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../domain/usecases/get_courts_usecase.dart';
import '../../domain/usecases/get_slot_config_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/update_booking_usecase.dart';
import '../../domain/usecases/get_booking_history_usecase.dart';
import '../../domain/usecases/get_booking_detail_usecase.dart';
import '../../domain/usecases/update_booking_status_usecase.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/update_court_slot_config_usecase.dart';
import '../../domain/usecases/create_fixed_schedule_usecase.dart';
import '../../domain/usecases/get_fixed_schedules_usecase.dart';
import '../../domain/usecases/cancel_fixed_schedule_usecase.dart';
import '../../domain/usecases/approve_fixed_schedule_usecase.dart';
import '../../domain/usecases/reject_fixed_schedule_usecase.dart';
import '../../domain/usecases/join_fixed_matching_schedule_usecase.dart';
import '../../domain/usecases/leave_fixed_matching_schedule_usecase.dart';
import '../../domain/usecases/pause_fixed_schedule_usecase.dart';
import '../../domain/usecases/resume_fixed_schedule_usecase.dart';
import '../../domain/usecases/cancel_fixed_matching_occurrence_usecase.dart';
import '../../domain/usecases/get_court_performance_report_usecase.dart';
import '../../domain/usecases/get_advanced_performance_report_usecase.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // ── DataSources ─────────────────────────────────────────────────────────
  if (!sl.isRegistered<CourtRemoteDataSource>()) {
    sl.registerLazySingleton<CourtRemoteDataSource>(
      () => CourtRemoteDataSourceImpl(sl<CourtService>(), sl<DioClient>()),
    );
  }

  if (!sl.isRegistered<BookingRemoteDataSource>()) {
    sl.registerLazySingleton<BookingRemoteDataSource>(
      () => BookingRemoteDataSourceImpl(sl<BookingService>(), sl<DioClient>()),
    );
  }

  // ── Repositories ────────────────────────────────────────────────────────
  if (!sl.isRegistered<CourtRepository>()) {
    sl.registerLazySingleton<CourtRepository>(
      () => CourtRepositoryImpl(sl<CourtRemoteDataSource>()),
    );
  }

  if (!sl.isRegistered<BookingRepository>()) {
    sl.registerLazySingleton<BookingRepository>(
      () => BookingRepositoryImpl(sl<BookingRemoteDataSource>()),
    );
  }

  // ── UseCases ────────────────────────────────────────────────────────────
  if (!sl.isRegistered<GetCourtsUseCase>()) {
    sl.registerLazySingleton<GetCourtsUseCase>(
      () => GetCourtsUseCase(sl<CourtRepository>()),
    );
  }

  if (!sl.isRegistered<GetSlotConfigUseCase>()) {
    sl.registerLazySingleton<GetSlotConfigUseCase>(
      () => GetSlotConfigUseCase(sl<CourtRepository>()),
    );
  }

  if (!sl.isRegistered<UpdateCourtSlotConfigUseCase>()) {
    sl.registerLazySingleton<UpdateCourtSlotConfigUseCase>(
      () => UpdateCourtSlotConfigUseCase(sl<CourtRepository>()),
    );
  }

  if (!sl.isRegistered<CreateBookingUseCase>()) {
    sl.registerLazySingleton<CreateBookingUseCase>(
      () => CreateBookingUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<UpdateBookingUseCase>()) {
    sl.registerLazySingleton<UpdateBookingUseCase>(
      () => UpdateBookingUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<GetBookingHistoryUseCase>()) {
    sl.registerLazySingleton<GetBookingHistoryUseCase>(
      () => GetBookingHistoryUseCase(
        sl<BookingRepository>(),
        sl<CourtRepository>(),
        sl<GetSportsUseCase>(),
      ),
    );
  }

  if (!sl.isRegistered<GetCourtPerformanceReportUseCase>()) {
    sl.registerLazySingleton<GetCourtPerformanceReportUseCase>(
      () => GetCourtPerformanceReportUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<GetAdvancedPerformanceReportUseCase>()) {
    sl.registerLazySingleton<GetAdvancedPerformanceReportUseCase>(
      () => GetAdvancedPerformanceReportUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<GetBookingDetailUseCase>()) {
    sl.registerLazySingleton<GetBookingDetailUseCase>(
      () => GetBookingDetailUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<UpdateBookingStatusUseCase>()) {
    sl.registerLazySingleton<UpdateBookingStatusUseCase>(
      () => UpdateBookingStatusUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<CancelBookingUseCase>()) {
    sl.registerLazySingleton<CancelBookingUseCase>(
      () => CancelBookingUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<CreateFixedScheduleUseCase>()) {
    sl.registerLazySingleton<CreateFixedScheduleUseCase>(
      () => CreateFixedScheduleUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<GetFixedSchedulesUseCase>()) {
    sl.registerLazySingleton<GetFixedSchedulesUseCase>(
      () => GetFixedSchedulesUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<CancelFixedScheduleUseCase>()) {
    sl.registerLazySingleton<CancelFixedScheduleUseCase>(
      () => CancelFixedScheduleUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<ApproveFixedScheduleUseCase>()) {
    sl.registerLazySingleton<ApproveFixedScheduleUseCase>(
      () => ApproveFixedScheduleUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<RejectFixedScheduleUseCase>()) {
    sl.registerLazySingleton<RejectFixedScheduleUseCase>(
      () => RejectFixedScheduleUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<JoinFixedMatchingScheduleUseCase>()) {
    sl.registerLazySingleton<JoinFixedMatchingScheduleUseCase>(
      () => JoinFixedMatchingScheduleUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<LeaveFixedMatchingScheduleUseCase>()) {
    sl.registerLazySingleton<LeaveFixedMatchingScheduleUseCase>(
      () => LeaveFixedMatchingScheduleUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<PauseFixedScheduleUseCase>()) {
    sl.registerLazySingleton<PauseFixedScheduleUseCase>(
      () => PauseFixedScheduleUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<ResumeFixedScheduleUseCase>()) {
    sl.registerLazySingleton<ResumeFixedScheduleUseCase>(
      () => ResumeFixedScheduleUseCase(sl<BookingRepository>()),
    );
  }

  if (!sl.isRegistered<CancelFixedMatchingOccurrenceUseCase>()) {
    sl.registerLazySingleton<CancelFixedMatchingOccurrenceUseCase>(
      () => CancelFixedMatchingOccurrenceUseCase(sl<BookingRepository>()),
    );
  }
}
