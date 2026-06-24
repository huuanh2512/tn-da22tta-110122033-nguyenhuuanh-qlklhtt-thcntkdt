import 'package:server_module/server_module.dart';

class ResumeFixedScheduleUseCase {
  final BookingRepository _repository;

  ResumeFixedScheduleUseCase(this._repository);

  Future<BaseResponse<FixedScheduleEntity>> call(String id) {
    return _repository.resumeFixedSchedule(id);
  }
}
