import 'package:server_module/server_module.dart';
import '../entities/match_queue_entity.dart';
import '../repositories/matching_repository.dart';

class GetQueueStatusUseCase {
  final MatchingRepository repository;

  GetQueueStatusUseCase(this.repository);

  Future<BaseResponse<MatchQueueEntity>> call() {
    return repository.getQueueStatus();
  }
}
