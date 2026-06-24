import 'package:server_module/server_module.dart';
import '../../domain/entities/matching_session_entity.dart';
import '../../domain/entities/match_queue_entity.dart';
import '../../domain/repositories/matching_repository.dart';
import '../datasources/remote/matching_remote_data_source.dart';
import '../models/matching_session_model.dart';
import '../models/match_queue_model.dart';

class MatchingRepositoryImpl implements MatchingRepository {
  final MatchingRemoteDataSource _remoteDataSource;

  MatchingRepositoryImpl(this._remoteDataSource);

  @override
  Future<BaseResponse<List<MatchingSessionEntity>>> getMatchingSessions({
    String? sportId,
    String? facilityId,
    String? bookingDate,
    int? neededSpots,
  }) async {
    final response = await _remoteDataSource.getMatchingSessions(
      sportId: sportId,
      facilityId: facilityId,
      bookingDate: bookingDate,
      neededSpots: neededSpots,
    );

    if (!response.success || response.data == null) {
      return BaseResponse<List<MatchingSessionEntity>>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final items = rawData['items'] as List<dynamic>? ?? [];
      final list = items
          .whereType<Map<String, dynamic>>()
          .map((json) => MatchingSessionModel.fromJson(json))
          .toList();

      return BaseResponse<List<MatchingSessionEntity>>(
        success: true,
        message: response.message,
        data: list,
      );
    } catch (e) {
      return BaseResponse<List<MatchingSessionEntity>>(
        success: false,
        message: 'Lỗi parse danh sách phòng ghép: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<MatchingSessionEntity>> getMatchingSessionDetail(
    String id,
  ) async {
    final response = await _remoteDataSource.getMatchingSessionDetail(id);
    return _parseSessionResponse(response);
  }

  @override
  Future<BaseResponse<MatchingSessionEntity>> createMatchingSession(
    Map<String, dynamic> data,
  ) async {
    final response = await _remoteDataSource.createMatchingSession(data);
    return _parseSessionResponse(response);
  }

  @override
  Future<BaseResponse<MatchingSessionEntity>> joinMatchingSession(
    String id, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _remoteDataSource.joinMatchingSession(
      id,
      data: data,
    );
    return _parseSessionResponse(response);
  }

  @override
  Future<BaseResponse<MatchingSessionEntity>> leaveMatchingSession(
    String id,
  ) async {
    final response = await _remoteDataSource.leaveMatchingSession(id);
    return _parseSessionResponse(response);
  }

  @override
  Future<BaseResponse<MatchingSessionEntity>> updateMemberStatus(
    String id,
    String userId,
    String status,
  ) async {
    final response = await _remoteDataSource.updateMemberStatus(
      id,
      userId,
      status,
    );
    return _parseSessionResponse(response);
  }

  @override
  Future<BaseResponse<MatchingSessionEntity>> updateSessionStatus(
    String id,
    String status,
  ) async {
    final response = await _remoteDataSource.updateSessionStatus(id, status);
    return _parseSessionResponse(response);
  }

  @override
  Future<BaseResponse<MatchQueueEntity>> joinQueue(
    Map<String, dynamic> data,
  ) async {
    final response = await _remoteDataSource.joinQueue(data);
    if (!response.success || response.data == null) {
      return BaseResponse<MatchQueueEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final queueJson = (rawData['queue'] as Map<String, dynamic>?) ?? rawData;
      final queue = MatchQueueModel.fromJson(queueJson);

      return BaseResponse<MatchQueueEntity>(
        success: true,
        message: response.message,
        data: queue,
      );
    } catch (e) {
      return BaseResponse<MatchQueueEntity>(
        success: false,
        message: 'Lỗi parse hàng chờ: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<void>> leaveQueue() async {
    final response = await _remoteDataSource.leaveQueue();
    return BaseResponse<void>(
      success: response.success,
      message: response.message,
      data: null,
    );
  }

  @override
  Future<BaseResponse<MatchQueueEntity>> getQueueStatus() async {
    final response = await _remoteDataSource.getQueueStatus();
    if (!response.success || response.data == null) {
      return BaseResponse<MatchQueueEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final queueJson =
          (rawData['active'] as Map<String, dynamic>?) ??
          (rawData['data'] as Map<String, dynamic>?) ??
          (rawData.containsKey('id') || rawData.containsKey('_id')
              ? rawData
              : null);
      if (queueJson == null) {
        return BaseResponse<MatchQueueEntity>(
          success: true,
          message: 'Không có hàng chờ hoạt động',
          data: null,
        );
      }

      final queue = MatchQueueModel.fromJson(queueJson);
      return BaseResponse<MatchQueueEntity>(
        success: true,
        message: response.message,
        data: queue,
      );
    } catch (e) {
      return BaseResponse<MatchQueueEntity>(
        success: false,
        message: 'Lỗi parse trạng thái hàng chờ: $e',
        data: null,
      );
    }
  }

  BaseResponse<MatchingSessionEntity> _parseSessionResponse(
    BaseResponse<dynamic> response,
  ) {
    if (!response.success || response.data == null) {
      return BaseResponse<MatchingSessionEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final sessionJson =
          (rawData['session'] as Map<String, dynamic>?) ??
          (rawData['data'] as Map<String, dynamic>?) ??
          rawData;
      final session = MatchingSessionModel.fromJson(sessionJson);

      return BaseResponse<MatchingSessionEntity>(
        success: true,
        message: response.message,
        data: session,
      );
    } catch (e) {
      return BaseResponse<MatchingSessionEntity>(
        success: false,
        message: 'Lỗi parse phòng ghép: $e',
        data: null,
      );
    }
  }
}
