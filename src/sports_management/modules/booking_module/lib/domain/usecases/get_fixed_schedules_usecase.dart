import 'package:server_module/server_module.dart';

class GetFixedSchedulesUseCase {
  final BookingRepository _repository;

  GetFixedSchedulesUseCase(this._repository);

  Future<BaseResponse<List<FixedScheduleEntity>>> call({String? status, String? type}) {
    return _repository.getFixedSchedules(status: status, type: type);
  }
}
