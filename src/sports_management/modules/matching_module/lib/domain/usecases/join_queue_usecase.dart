import 'package:server_module/server_module.dart';
import '../entities/match_queue_entity.dart';
import '../repositories/matching_repository.dart';

class JoinQueueUseCase {
  final MatchingRepository repository;

  JoinQueueUseCase(this.repository);

  Future<BaseResponse<MatchQueueEntity>> call(Map<String, dynamic> data) {
    return repository.joinQueue(data);
  }
}
