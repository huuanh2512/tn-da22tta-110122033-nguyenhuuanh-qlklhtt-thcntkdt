import 'package:server_module/server_module.dart';
import '../entities/matching_session_entity.dart';
import '../repositories/matching_repository.dart';

class UpdateSessionStatusUseCase {
  final MatchingRepository repository;

  UpdateSessionStatusUseCase(this.repository);

  Future<BaseResponse<MatchingSessionEntity>> call(String id, String status) {
    return repository.updateSessionStatus(id, status);
  }
}
