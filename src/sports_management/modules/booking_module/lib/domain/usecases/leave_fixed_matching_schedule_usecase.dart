import 'package:server_module/server_module.dart';

class LeaveFixedMatchingScheduleUseCase {
  final BookingRepository _repository;

  LeaveFixedMatchingScheduleUseCase(this._repository);

  Future<BaseResponse<FixedScheduleEntity>> call(String id) {
    return _repository.leaveFixedMatchingSchedule(id);
  }
}
