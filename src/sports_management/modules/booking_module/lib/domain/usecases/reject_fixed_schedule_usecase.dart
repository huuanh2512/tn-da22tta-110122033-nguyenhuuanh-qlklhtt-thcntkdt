import 'package:server_module/server_module.dart';

class RejectFixedScheduleUseCase {
  final BookingRepository _repository;

  RejectFixedScheduleUseCase(this._repository);

  Future<BaseResponse<FixedScheduleEntity>> call(String id, {String? reason}) {
    return _repository.rejectFixedSchedule(id, reason: reason);
  }
}
