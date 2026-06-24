import 'package:server_module/server_module.dart';
import '../entities/matching_session_entity.dart';
import '../repositories/matching_repository.dart';

class GetMatchingSessionDetailUseCase {
  final MatchingRepository repository;

  GetMatchingSessionDetailUseCase(this.repository);

  Future<BaseResponse<MatchingSessionEntity>> call(String id) {
    return repository.getMatchingSessionDetail(id);
  }
}
