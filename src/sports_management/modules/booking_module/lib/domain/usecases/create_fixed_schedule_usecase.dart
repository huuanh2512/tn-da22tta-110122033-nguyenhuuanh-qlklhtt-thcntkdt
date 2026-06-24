import 'package:server_module/server_module.dart';

class CreateFixedScheduleUseCase {
  final BookingRepository _repository;

  CreateFixedScheduleUseCase(this._repository);

  Future<BaseResponse<FixedScheduleEntity>> call(Map<String, dynamic> data) {
    return _repository.createFixedSchedule(data);
  }
}
