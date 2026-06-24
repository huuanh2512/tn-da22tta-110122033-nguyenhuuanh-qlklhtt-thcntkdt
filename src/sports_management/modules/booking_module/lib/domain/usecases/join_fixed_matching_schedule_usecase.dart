import 'package:server_module/server_module.dart';

class JoinFixedMatchingScheduleUseCase {
  final BookingRepository _repository;

  JoinFixedMatchingScheduleUseCase(this._repository);

  Future<BaseResponse<FixedScheduleEntity>> call(
    String id, {
    required String preferredTeam,
    required int memberCount,
  }) {
    return _repository.joinFixedMatchingSchedule(
      id,
      preferredTeam: preferredTeam,
      memberCount: memberCount,
    );
  }
}
