import 'package:server_module/server_module.dart';
import '../entities/matching_session_entity.dart';
import '../repositories/matching_repository.dart';

class GetMatchingSessionsUseCase {
  final MatchingRepository repository;

  GetMatchingSessionsUseCase(this.repository);

  Future<BaseResponse<List<MatchingSessionEntity>>> call({
    String? sportId,
    String? facilityId,
    String? bookingDate,
    int? neededSpots,
  }) {
    return repository.getMatchingSessions(
      sportId: sportId,
      facilityId: facilityId,
      bookingDate: bookingDate,
      neededSpots: neededSpots,
    );
  }
}
