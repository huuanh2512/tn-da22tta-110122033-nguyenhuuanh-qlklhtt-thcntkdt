import 'package:server_module/server_module.dart';

abstract class BookingRemoteDataSource {
  Future<BaseResponse<dynamic>> getBookings({
    String? facilityId,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? view,
    int? limit,
  });
  Future<BaseResponse<dynamic>> getCourtPerformanceReport({
    String? facilityId,
    String? courtId,
    required String dateFrom,
    required String dateTo,
  });
  Future<BaseResponse<dynamic>> getAdvancedPerformanceReport({
    String? facilityId,
    List<String>? facilityIds,
    String? sportId,
    String? courtId,
    String? status,
    String? include,
    required String dateFrom,
    required String dateTo,
  });
  Future<BaseResponse<dynamic>> getBookingById(String id);
  Future<BaseResponse<dynamic>> createBooking(Map<String, dynamic> data);
  Future<BaseResponse<dynamic>> updateBooking(
    String id,
    Map<String, dynamic> data,
  );
  Future<BaseResponse<dynamic>> updateBookingStatus(String id, String status);
  Future<BaseResponse<dynamic>> cancelBooking(String id);
  Future<BaseResponse<dynamic>> createFixedSchedule(Map<String, dynamic> data);
  Future<BaseResponse<dynamic>> getFixedSchedules({
    String? status,
    String? type,
  });
  Future<BaseResponse<dynamic>> cancelFixedSchedule(String id);
  Future<BaseResponse<dynamic>> pauseFixedSchedule(String id);
  Future<BaseResponse<dynamic>> resumeFixedSchedule(String id);
  Future<BaseResponse<dynamic>> cancelFixedMatchingOccurrence(
    String id, {
    required String date,
    String? reason,
  });
  Future<BaseResponse<dynamic>> approveFixedSchedule(String id);
  Future<BaseResponse<dynamic>> rejectFixedSchedule(
    String id, {
    String? reason,
  });
  Future<BaseResponse<dynamic>> joinFixedMatchingSchedule(
    String id, {
    required String preferredTeam,
    required int memberCount,
  });
  Future<BaseResponse<dynamic>> leaveFixedMatchingSchedule(String id);
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final BookingService _bookingService;
  final DioClient _dioClient;

  BookingRemoteDataSourceImpl(this._bookingService, this._dioClient);

  @override
  Future<BaseResponse<dynamic>> getBookings({
    String? facilityId,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? view,
    int? limit,
  }) async {
    final dio = _dioClient.dio;
    final queryParameters = <String, dynamic>{
      'limit': limit ?? 500,
      if (facilityId != null && facilityId.isNotEmpty) 'facilityId': facilityId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      if (view != null && view.isNotEmpty) 'view': view,
    };
    final dioResponse = await dio.get(
      '/booking/',
      queryParameters: queryParameters,
    );
    return BaseResponse.fromJson(dioResponse.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> getCourtPerformanceReport({
    String? facilityId,
    String? courtId,
    required String dateFrom,
    required String dateTo,
  }) async {
    final response = await _dioClient.dio.get(
      '/reports/court-performance',
      queryParameters: {
        if (facilityId != null && facilityId.isNotEmpty)
          'facilityId': facilityId,
        if (courtId != null && courtId.isNotEmpty) 'courtId': courtId,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      },
    );
    return BaseResponse.fromJson(response.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> getAdvancedPerformanceReport({
    String? facilityId,
    List<String>? facilityIds,
    String? sportId,
    String? courtId,
    String? status,
    String? include,
    required String dateFrom,
    required String dateTo,
  }) async {
    final response = await _dioClient.dio.get(
      '/reports/advanced-performance',
      queryParameters: {
        if (facilityId != null && facilityId.isNotEmpty)
          'facilityId': facilityId,
        if (facilityIds != null && facilityIds.isNotEmpty)
          'facilityIds': facilityIds.join(','),
        if (sportId != null && sportId.isNotEmpty) 'sportId': sportId,
        if (courtId != null && courtId.isNotEmpty) 'courtId': courtId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (include != null && include.isNotEmpty) 'include': include,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      },
    );
    return BaseResponse.fromJson(response.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> getBookingById(String id) {
    return _bookingService.getBookingById(id);
  }

  @override
  Future<BaseResponse<dynamic>> createBooking(Map<String, dynamic> data) {
    return _bookingService.createBooking(data);
  }

  @override
  Future<BaseResponse<dynamic>> updateBooking(
    String id,
    Map<String, dynamic> data,
  ) {
    return _bookingService.updateBooking(id, data);
  }

  @override
  Future<BaseResponse<dynamic>> updateBookingStatus(String id, String status) {
    return _bookingService.updateBookingStatus(id, status);
  }

  @override
  Future<BaseResponse<dynamic>> cancelBooking(String id) {
    return _bookingService.cancelBooking(id);
  }

  @override
  Future<BaseResponse<dynamic>> createFixedSchedule(
    Map<String, dynamic> data,
  ) async {
    final dio = _dioClient.dio;
    try {
      final response = await dio.post('/fixed-schedule', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> getFixedSchedules({
    String? status,
    String? type,
  }) async {
    final dio = _dioClient.dio;
    // ignore: use_null_aware_elements
    final response = await dio.get(
      '/fixed-schedule',
      queryParameters: {'status': ?status, 'type': ?type},
    );
    return BaseResponse.fromJson(response.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> cancelFixedSchedule(String id) async {
    final dio = _dioClient.dio;
    final response = await dio.put('/fixed-schedule/$id/cancel');
    return BaseResponse.fromJson(response.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> pauseFixedSchedule(String id) async {
    final dio = _dioClient.dio;
    final response = await dio.put('/fixed-schedule/$id/pause');
    return BaseResponse.fromJson(response.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> resumeFixedSchedule(String id) async {
    final dio = _dioClient.dio;
    final response = await dio.put('/fixed-schedule/$id/resume');
    return BaseResponse.fromJson(response.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> cancelFixedMatchingOccurrence(
    String id, {
    required String date,
    String? reason,
  }) async {
    final dio = _dioClient.dio;
    final response = await dio.post(
      '/fixed-schedule/$id/occurrences/$date/cancel',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return BaseResponse.fromJson(response.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> approveFixedSchedule(String id) async {
    final dio = _dioClient.dio;
    final response = await dio.put('/fixed-schedule/$id/approve');
    return BaseResponse.fromJson(response.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> rejectFixedSchedule(
    String id, {
    String? reason,
  }) async {
    final dio = _dioClient.dio;
    final response = await dio.put(
      '/fixed-schedule/$id/reject',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return BaseResponse.fromJson(response.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> joinFixedMatchingSchedule(
    String id, {
    required String preferredTeam,
    required int memberCount,
  }) async {
    final dio = _dioClient.dio;
    final response = await dio.post(
      '/fixed-schedule/$id/matching/join',
      data: {'preferredTeam': preferredTeam, 'memberCount': memberCount},
    );
    return BaseResponse.fromJson(response.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> leaveFixedMatchingSchedule(String id) async {
    final dio = _dioClient.dio;
    final response = await dio.post('/fixed-schedule/$id/matching/leave');
    return BaseResponse.fromJson(response.data, (json) => json);
  }
}
