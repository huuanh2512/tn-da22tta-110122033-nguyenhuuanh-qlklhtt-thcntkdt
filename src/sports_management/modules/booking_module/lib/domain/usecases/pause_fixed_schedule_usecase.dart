import 'package:server_module/server_module.dart';

class PauseFixedScheduleUseCase {
  final BookingRepository _repository;

  PauseFixedScheduleUseCase(this._repository);

  Future<BaseResponse<FixedScheduleEntity>> call(String id) {
    return _repository.pauseFixedSchedule(id);
  }
}
