import 'package:server_module/server_module.dart';

class ApproveFixedScheduleUseCase {
  final BookingRepository _repository;

  ApproveFixedScheduleUseCase(this._repository);

  Future<BaseResponse<FixedScheduleEntity>> call(String id) {
    return _repository.approveFixedSchedule(id);
  }
}
