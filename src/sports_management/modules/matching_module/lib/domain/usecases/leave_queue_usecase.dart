import 'package:server_module/server_module.dart';
import '../repositories/matching_repository.dart';

class LeaveQueueUseCase {
  final MatchingRepository repository;

  LeaveQueueUseCase(this.repository);

  Future<BaseResponse<void>> call() {
    return repository.leaveQueue();
  }
}
