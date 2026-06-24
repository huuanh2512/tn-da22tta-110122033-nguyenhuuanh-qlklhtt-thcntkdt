import 'package:server_module/server_module.dart';

class CancelFixedScheduleUseCase {
  final BookingRepository _repository;

  CancelFixedScheduleUseCase(this._repository);

  Future<BaseResponse<FixedScheduleEntity>> call(String id) {
    return _repository.cancelFixedSchedule(id);
  }
}
