import 'package:server_module/server_module.dart';
import '../entities/matching_session_entity.dart';
import '../repositories/matching_repository.dart';

class UpdateMemberStatusUseCase {
  final MatchingRepository repository;

  UpdateMemberStatusUseCase(this.repository);

  Future<BaseResponse<MatchingSessionEntity>> call({
    required String id,
    required String userId,
    required String status,
  }) {
    return repository.updateMemberStatus(id, userId, status);
  }
}
