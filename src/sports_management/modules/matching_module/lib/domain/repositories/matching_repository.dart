import 'package:server_module/server_module.dart';
import '../entities/matching_session_entity.dart';
import '../entities/match_queue_entity.dart';

abstract class MatchingRepository {
  Future<BaseResponse<List<MatchingSessionEntity>>> getMatchingSessions({
    String? sportId,
    String? facilityId,
    String? bookingDate,
    int? neededSpots,
  });

  Future<BaseResponse<MatchingSessionEntity>> getMatchingSessionDetail(
    String id,
  );

  Future<BaseResponse<MatchingSessionEntity>> createMatchingSession(
    Map<String, dynamic> data,
  );

  Future<BaseResponse<MatchingSessionEntity>> joinMatchingSession(
    String id, {
    Map<String, dynamic>? data,
  });

  Future<BaseResponse<MatchingSessionEntity>> leaveMatchingSession(String id);

  Future<BaseResponse<MatchingSessionEntity>> updateMemberStatus(
    String id,
    String userId,
    String status,
  );

  Future<BaseResponse<MatchingSessionEntity>> updateSessionStatus(
    String id,
    String status,
  );

  Future<BaseResponse<MatchQueueEntity>> joinQueue(Map<String, dynamic> data);

  Future<BaseResponse<void>> leaveQueue();

  Future<BaseResponse<MatchQueueEntity>> getQueueStatus();
}
