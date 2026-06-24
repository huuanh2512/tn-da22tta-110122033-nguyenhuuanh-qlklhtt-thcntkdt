import 'package:server_module/server_module.dart';
import '../entities/matching_session_entity.dart';
import '../repositories/matching_repository.dart';

class LeaveMatchingSessionUseCase {
  final MatchingRepository repository;

  LeaveMatchingSessionUseCase(this.repository);

  Future<BaseResponse<MatchingSessionEntity>> call(String id) {
    return repository.leaveMatchingSession(id);
  }
}
