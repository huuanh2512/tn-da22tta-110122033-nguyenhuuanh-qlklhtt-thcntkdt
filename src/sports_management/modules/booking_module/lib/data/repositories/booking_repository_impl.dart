// ignore_for_file: avoid_print
import 'package:server_module/server_module.dart';
import '../../domain/entities/booking_detail_entity.dart';
import '../datasources/remote/booking_remote_data_source.dart';
import '../models/advanced_performance_report_model.dart';
import '../models/court_performance_report_model.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource _remoteDataSource;

  BookingRepositoryImpl(this._remoteDataSource);

  @override
  Future<BaseResponse<List<BookingEntity>>> getBookings({
    String? facilityId,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? view,
    int? limit,
  }) async {
    try {
      final response = await _remoteDataSource.getBookings(
        facilityId: facilityId,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
        view: view,
        limit: limit,
      );
      if (!response.success || response.data == null) {
        return BaseResponse<List<BookingEntity>>(
          success: response.success,
          message: response.message,
          data: null,
        );
      }
      final rawData = response.data as Map<String, dynamic>;
      final itemsList = rawData['items'] as List<dynamic>? ?? [];
      final bookings = itemsList
          .whereType<Map<String, dynamic>>()
          .map(_parseBooking)
          .whereType<BookingEntity>()
          .toList();
      return BaseResponse<List<BookingEntity>>(
        success: true,
        message: response.message,
        data: bookings,
      );
    } catch (e) {
      return BaseResponse<List<BookingEntity>>(
        success: false,
        message: 'Lỗi parse danh sách booking: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<CourtPerformanceReportEntity>> getCourtPerformanceReport({
    String? facilityId,
    String? courtId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final response = await _remoteDataSource.getCourtPerformanceReport(
        facilityId: facilityId,
        courtId: courtId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (!response.success || response.data == null) {
        return BaseResponse<CourtPerformanceReportEntity>(
          success: response.success,
          message: response.message,
          data: null,
        );
      }
      final rawData = response.data as Map<String, dynamic>;
      final reportMap = rawData['report'] as Map<String, dynamic>? ?? rawData;
      return BaseResponse<CourtPerformanceReportEntity>(
        success: true,
        message: response.message,
        data: CourtPerformanceReportModel.fromJson(reportMap),
      );
    } catch (e) {
      return BaseResponse<CourtPerformanceReportEntity>(
        success: false,
        message: 'Lỗi parse báo cáo hiệu suất: $e',
        data: null,
      );
    }
  }

  @override
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
  }) async {
    try {
      final response = await _remoteDataSource.getAdvancedPerformanceReport(
        facilityId: facilityId,
        facilityIds: facilityIds,
        sportId: sportId,
        courtId: courtId,
        status: status,
        include: include,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (!response.success || response.data == null) {
        return BaseResponse<AdvancedPerformanceReportEntity>(
          success: response.success,
          message: response.message,
          data: null,
        );
      }
      final rawData = response.data as Map<String, dynamic>;
      final reportMap = rawData['report'] as Map<String, dynamic>? ?? rawData;
      return BaseResponse<AdvancedPerformanceReportEntity>(
        success: true,
        message: response.message,
        data: AdvancedPerformanceReportModel.fromJson(reportMap),
      );
    } catch (e) {
      return BaseResponse<AdvancedPerformanceReportEntity>(
        success: false,
        message: 'Lỗi parse báo cáo hiệu suất nâng cao: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<BookingEntity>> getBookingById(String id) async {
    final response = await _remoteDataSource.getBookingById(id);
    return _mapToBookingResponse(response);
  }

  @override
  Future<BaseResponse<BookingEntity>> createBooking(
    Map<String, dynamic> data,
  ) async {
    final response = await _remoteDataSource.createBooking(data);
    return _mapToBookingResponse(response);
  }

  @override
  Future<BaseResponse<BookingEntity>> updateBooking(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _remoteDataSource.updateBooking(id, data);
    return _mapToBookingResponse(response);
  }

  @override
  Future<BaseResponse<BookingEntity>> updateBookingStatus(
    String id,
    String status,
  ) async {
    final response = await _remoteDataSource.updateBookingStatus(id, status);
    return _mapToBookingResponse(response);
  }

  @override
  Future<BaseResponse<BookingEntity>> cancelBooking(String id) async {
    final response = await _remoteDataSource.cancelBooking(id);
    return _mapToBookingResponse(response);
  }

  // ---------------------------------------------------------------------------

  BaseResponse<BookingEntity> _mapToBookingResponse(
    BaseResponse<dynamic> response,
  ) {
    if (!response.success || response.data == null) {
      return BaseResponse<BookingEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }
    try {
      final rawData = response.data as Map<String, dynamic>;
      // API trả về { "booking": { ... } } hoặc trực tiếp object
      final bookingMap =
          (rawData['booking'] as Map<String, dynamic>?) ?? rawData;
      final booking = _parseBooking(bookingMap);
      return BaseResponse<BookingEntity>(
        success: true,
        message: response.message,
        data: booking,
      );
    } catch (e) {
      return BaseResponse<BookingEntity>(
        success: false,
        message: 'Lỗi parse booking: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<FixedScheduleEntity>> createFixedSchedule(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _remoteDataSource.createFixedSchedule(data);
      if (!response.success || response.data == null) {
        return BaseResponse<FixedScheduleEntity>(
          success: response.success,
          message: response.message,
          data: null,
        );
      }
      final rawData = response.data as Map<String, dynamic>;
      final scheduleMap =
          (rawData['schedule'] as Map<String, dynamic>?) ?? rawData;
      final schedule = _parseFixedSchedule(scheduleMap);
      if (schedule == null) {
        return BaseResponse<FixedScheduleEntity>(
          success: false,
          message: 'Lỗi parse fixed schedule',
          data: null,
        );
      }
      return BaseResponse<FixedScheduleEntity>(
        success: true,
        message: response.message,
        data: schedule,
      );
    } catch (e) {
      return BaseResponse<FixedScheduleEntity>(
        success: false,
        message: 'Lỗi parse fixed schedule: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<List<FixedScheduleEntity>>> getFixedSchedules({
    String? status,
    String? type,
  }) async {
    try {
      final response = await _remoteDataSource.getFixedSchedules(
        status: status,
        type: type,
      );
      if (!response.success || response.data == null) {
        return BaseResponse<List<FixedScheduleEntity>>(
          success: response.success,
          message: response.message,
          data: null,
        );
      }
      final rawData = response.data as Map<String, dynamic>;
      final itemsList = rawData['items'] as List<dynamic>? ?? [];
      final schedules = itemsList
          .whereType<Map<String, dynamic>>()
          .map(_parseFixedSchedule)
          .whereType<FixedScheduleEntity>()
          .toList();
      return BaseResponse<List<FixedScheduleEntity>>(
        success: true,
        message: response.message,
        data: schedules,
      );
    } catch (e) {
      return BaseResponse<List<FixedScheduleEntity>>(
        success: false,
        message: 'Lỗi parse danh sách fixed schedules: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<FixedScheduleEntity>> cancelFixedSchedule(
    String id,
  ) async {
    try {
      final response = await _remoteDataSource.cancelFixedSchedule(id);
      return _mapToFixedScheduleResponse(
        response,
        parseErrorMessage: 'Lỗi parse fixed schedule sau khi hủy',
      );
    } catch (e) {
      return BaseResponse<FixedScheduleEntity>(
        success: false,
        message: 'Lỗi parse fixed schedule sau khi hủy: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<FixedScheduleEntity>> pauseFixedSchedule(
    String id,
  ) async {
    try {
      final response = await _remoteDataSource.pauseFixedSchedule(id);
      return _mapToFixedScheduleResponse(
        response,
        parseErrorMessage: 'Lỗi parse fixed schedule sau khi tạm dừng',
      );
    } catch (e) {
      return BaseResponse<FixedScheduleEntity>(
        success: false,
        message: 'Lỗi tạm dừng lịch cố định: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<FixedScheduleEntity>> resumeFixedSchedule(
    String id,
  ) async {
    try {
      final response = await _remoteDataSource.resumeFixedSchedule(id);
      return _mapToFixedScheduleResponse(
        response,
        parseErrorMessage: 'Lỗi parse fixed schedule sau khi tiếp tục',
      );
    } catch (e) {
      return BaseResponse<FixedScheduleEntity>(
        success: false,
        message: 'Lỗi tiếp tục lịch cố định: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<FixedScheduleEntity>> cancelFixedMatchingOccurrence(
    String id, {
    required String date,
    String? reason,
  }) async {
    try {
      final response = await _remoteDataSource.cancelFixedMatchingOccurrence(
        id,
        date: date,
        reason: reason,
      );
      return _mapToFixedScheduleResponse(
        response,
        parseErrorMessage: 'Lỗi parse fixed schedule sau khi hủy một buổi',
      );
    } catch (e) {
      return BaseResponse<FixedScheduleEntity>(
        success: false,
        message: 'Lỗi hủy một buổi lịch ghép cố định: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<FixedScheduleEntity>> approveFixedSchedule(
    String id,
  ) async {
    try {
      final response = await _remoteDataSource.approveFixedSchedule(id);
      return _mapToFixedScheduleResponse(
        response,
        parseErrorMessage: 'Lỗi parse fixed schedule sau khi duyệt',
      );
    } catch (e) {
      return BaseResponse<FixedScheduleEntity>(
        success: false,
        message: 'Lỗi parse fixed schedule sau khi duyệt: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<FixedScheduleEntity>> rejectFixedSchedule(
    String id, {
    String? reason,
  }) async {
    try {
      final response = await _remoteDataSource.rejectFixedSchedule(
        id,
        reason: reason,
      );
      return _mapToFixedScheduleResponse(
        response,
        parseErrorMessage: 'Lỗi parse fixed schedule sau khi từ chối',
      );
    } catch (e) {
      return BaseResponse<FixedScheduleEntity>(
        success: false,
        message: 'Lỗi parse fixed schedule sau khi từ chối: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<FixedScheduleEntity>> joinFixedMatchingSchedule(
    String id, {
    required String preferredTeam,
    required int memberCount,
  }) async {
    try {
      final response = await _remoteDataSource.joinFixedMatchingSchedule(
        id,
        preferredTeam: preferredTeam,
        memberCount: memberCount,
      );
      return _mapToFixedScheduleResponse(
        response,
        parseErrorMessage: 'Lỗi parse fixed matching sau khi tham gia',
      );
    } catch (e) {
      return BaseResponse<FixedScheduleEntity>(
        success: false,
        message: 'Lỗi tham gia lịch ghép cố định: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<FixedScheduleEntity>> leaveFixedMatchingSchedule(
    String id,
  ) async {
    try {
      final response = await _remoteDataSource.leaveFixedMatchingSchedule(id);
      return _mapToFixedScheduleResponse(
        response,
        parseErrorMessage: 'Lỗi parse fixed matching sau khi rời',
      );
    } catch (e) {
      return BaseResponse<FixedScheduleEntity>(
        success: false,
        message: 'Lỗi rời lịch ghép cố định: $e',
        data: null,
      );
    }
  }

  // ---------------------------------------------------------------------------

  BaseResponse<FixedScheduleEntity> _mapToFixedScheduleResponse(
    BaseResponse<dynamic> response, {
    required String parseErrorMessage,
  }) {
    if (!response.success || response.data == null) {
      return BaseResponse<FixedScheduleEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    final rawData = response.data as Map<String, dynamic>;
    final scheduleMap = (rawData['schedule'] as Map<String, dynamic>?) != null
        ? {
            ...(rawData['schedule'] as Map<String, dynamic>),
            if (rawData['cancellationSummary'] is Map<String, dynamic>)
              'cancellationSummary': rawData['cancellationSummary'],
          }
        : rawData;
    final schedule = _parseFixedSchedule(scheduleMap);
    if (schedule == null) {
      return BaseResponse<FixedScheduleEntity>(
        success: false,
        message: parseErrorMessage,
        data: null,
      );
    }
    return BaseResponse<FixedScheduleEntity>(
      success: true,
      message: response.message,
      data: schedule,
    );
  }

  BookingEntity? _parseBooking(Map<String, dynamic> map) {
    try {
      // 1. Parse User
      final userMap = map['user'] as Map<String, dynamic>?;
      UserEntity? userEntity;
      if (userMap != null) {
        final profile = userMap['profile'] is Map
            ? Map<String, dynamic>.from(userMap['profile'] as Map)
            : const <String, dynamic>{};
        userEntity = UserEntity(
          id: userMap['id']?.toString() ?? userMap['_id']?.toString() ?? '',
          name:
              userMap['name']?.toString() ??
              profile['name']?.toString() ??
              profile['fullName']?.toString() ??
              '',
          email: userMap['email']?.toString(),
          phone: userMap['phone']?.toString() ?? profile['phone']?.toString(),
        );
      }

      // 2. Parse Court
      final courtMap = map['court'] as Map<String, dynamic>?;
      CourtEntity? courtEntity;
      if (courtMap != null) {
        courtEntity = CourtEntity(
          id: courtMap['id']?.toString() ?? '',
          name: courtMap['name']?.toString() ?? '',
          facilityId: courtMap['facilityId']?.toString(),
        );
      }

      final fixedScheduleId =
          map['fixedScheduleId']?.toString() ??
          map['fixed_schedule_id']?.toString() ??
          map['fixedSchedule']?['id']?.toString() ??
          map['fixedSchedule']?['_id']?.toString();
      final isFixedSchedule =
          _readBool(map['isFixedSchedule']) ??
          _readBool(map['is_fixed_schedule']) ??
          (fixedScheduleId != null);

      // 3. Return BookingDetailEntity
      return BookingDetailEntity(
        id: map['id']?.toString() ?? '',
        userId:
            map['userId']?.toString() ??
            map['user_id']?.toString() ??
            userMap?['id']?.toString() ??
            userMap?['_id']?.toString(),
        guestName:
            map['guestName']?.toString() ?? map['guest_name']?.toString(),
        guestPhone:
            map['guestPhone']?.toString() ?? map['guest_phone']?.toString(),
        user: userEntity,
        courtId: courtMap?['id']?.toString(),
        court: courtEntity,
        courtName: courtMap?['name']?.toString(),
        courtCode: courtMap?['code']?.toString(),
        bookingDate: _normalizeDate(map['bookingDate']?.toString()),
        startMinutes: map['startMinutes'] as int?,
        endMinutes: map['endMinutes'] as int?,
        totalPrice: (map['totalPrice'] as num?)?.toDouble(),
        status: map['status']?.toString(),
        cancelReason:
            map['cancelReason']?.toString() ?? map['cancel_reason']?.toString(),
        cancelledBy:
            map['cancelledBy']?.toString() ?? map['cancelled_by']?.toString(),
        cancelledAt: map['cancelledAt'] != null || map['cancelled_at'] != null
            ? DateTime.tryParse(
                (map['cancelledAt'] ?? map['cancelled_at']).toString(),
              )
            : null,
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString())
            : null,
        fixedScheduleId: fixedScheduleId,
        isFixedSchedule: isFixedSchedule,
        paymentStatus:
            map['paymentStatus']?.toString() ??
            map['payment_status']?.toString(),
        isMatching:
            _readBool(map['isMatching']) ??
            _readBool(map['is_matching']) ??
            false,
        matchingSessionId:
            map['matchingSessionId']?.toString() ??
            map['matching_session_id']?.toString(),
        isHost: _readBool(map['isHost']) ?? _readBool(map['is_host']) ?? false,
        paymentPolicy:
            map['paymentPolicy']?.toString() ??
            map['payment_policy']?.toString(),
        myPaymentStatus:
            map['myPaymentStatus']?.toString() ??
            map['my_payment_status']?.toString(),
        myPaymentAmount:
            (map['myPaymentAmount'] as num?)?.toDouble() ??
            (map['my_payment_amount'] as num?)?.toDouble(),
        membersCount:
            (map['membersCount'] as num?)?.toInt() ??
            (map['members_count'] as num?)?.toInt(),
      );
    } catch (e) {
      print("Lỗi parse booking: $e");
      return null;
    }
  }

  FixedScheduleEntity? _parseFixedSchedule(Map<String, dynamic> map) {
    try {
      // 1. Parse User
      final userMap = map['user'] as Map<String, dynamic>?;
      UserEntity? userEntity;
      if (userMap != null) {
        userEntity = UserEntity(
          id: userMap['id']?.toString() ?? userMap['_id']?.toString() ?? '',
          name: userMap['name']?.toString() ?? '',
          email: userMap['email']?.toString(),
        );
      }

      // 2. Parse Sport
      final sportMap = map['sport'] as Map<String, dynamic>?;
      SportEntity? sportEntity;
      if (sportMap != null) {
        sportEntity = SportEntity(
          id: sportMap['id']?.toString() ?? sportMap['_id']?.toString() ?? '',
          name: sportMap['name']?.toString() ?? '',
        );
      }

      // 3. Parse Facility
      final facilityMap = map['facility'] as Map<String, dynamic>?;
      FacilityEntity? facilityEntity;
      if (facilityMap != null) {
        facilityEntity = FacilityEntity(
          id:
              facilityMap['id']?.toString() ??
              facilityMap['_id']?.toString() ??
              '',
          name: facilityMap['name']?.toString() ?? '',
          address: facilityMap['address']?.toString(),
        );
      }

      // 4. Parse Court
      final courtMap = map['court'] as Map<String, dynamic>?;
      CourtEntity? courtEntity;
      if (courtMap != null) {
        courtEntity = CourtEntity(
          id: courtMap['id']?.toString() ?? courtMap['_id']?.toString() ?? '',
          name: courtMap['name']?.toString() ?? '',
          facilityId:
              facilityMap?['id']?.toString() ?? map['facilityId']?.toString(),
        );
      }

      final matchingConfigMap = map['matchingConfig'] is Map<String, dynamic>
          ? map['matchingConfig'] as Map<String, dynamic>
          : map['matching_config'] is Map<String, dynamic>
          ? map['matching_config'] as Map<String, dynamic>
          : null;
      final exceptionDates = (map['exceptionDates'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .toList();
      final cancellationSummary =
          map['cancellationSummary'] is Map<String, dynamic>
          ? map['cancellationSummary'] as Map<String, dynamic>
          : null;

      return FixedScheduleEntity(
        id: map['id']?.toString() ?? map['_id']?.toString() ?? '',
        user: userEntity,
        type: map['type']?.toString(),
        sport: sportEntity,
        facility: facilityEntity,
        court: courtEntity,
        pricePerHour:
            (courtMap?['pricePerHour'] as num?)?.toInt() ??
            (map['pricePerHour'] as num?)?.toInt(),
        startMinutes: map['startMinutes'] as int?,
        endMinutes: map['endMinutes'] as int?,
        frequency: map['frequency']?.toString(),
        daysOfWeek: (map['daysOfWeek'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList(),
        startDate: _normalizeDate(map['startDate']?.toString()),
        endDate: _normalizeDate(map['endDate']?.toString()),
        status: map['status']?.toString(),
        matchingConfig: matchingConfigMap,
        fixedMatchingConfig: matchingConfigMap != null
            ? FixedMatchingConfigEntity.fromJson(matchingConfigMap)
            : null,
        readiness:
            map['readiness']?.toString() ??
            matchingConfigMap?['readiness']?.toString(),
        exceptionDates: exceptionDates,
        cancellationSummary: cancellationSummary,
        pausedAt: map['pausedAt'] != null
            ? DateTime.tryParse(map['pausedAt'].toString())
            : null,
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString())
            : null,
      );
    } catch (e) {
      print("Lỗi parse fixed schedule: $e");
      return null;
    }
  }

  String? _normalizeDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return null;
    final trimmed = rawDate.trim();
    if (trimmed.length == 10 &&
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return trimmed;
    }
    try {
      final parsed = DateTime.parse(trimmed).toLocal();
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (_) {
      if (trimmed.contains('T')) {
        return trimmed.split('T').first;
      }
      return trimmed;
    }
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return null;
  }
}
