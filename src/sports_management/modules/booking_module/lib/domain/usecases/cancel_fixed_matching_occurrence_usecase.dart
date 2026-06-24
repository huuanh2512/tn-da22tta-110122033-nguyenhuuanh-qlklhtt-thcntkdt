import 'package:server_module/server_module.dart';

class CancelFixedMatchingOccurrenceUseCase {
  final BookingRepository _repository;

  CancelFixedMatchingOccurrenceUseCase(this._repository);

  Future<BaseResponse<FixedScheduleEntity>> call(
    String id, {
    required String date,
    String? reason,
  }) {
    return _repository.cancelFixedMatchingOccurrence(
      id,
      date: date,
      reason: reason,
    );
  }
}
