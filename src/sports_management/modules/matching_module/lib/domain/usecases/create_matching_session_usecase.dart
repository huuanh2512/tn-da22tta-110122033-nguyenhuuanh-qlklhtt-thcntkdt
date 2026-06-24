import 'package:server_module/server_module.dart';
import '../entities/matching_session_entity.dart';
import '../repositories/matching_repository.dart';

class CreateMatchingSessionUseCase {
  final MatchingRepository repository;

  CreateMatchingSessionUseCase(this.repository);

  Future<BaseResponse<MatchingSessionEntity>> call(Map<String, dynamic> data) {
    return repository.createMatchingSession(data);
  }
}
