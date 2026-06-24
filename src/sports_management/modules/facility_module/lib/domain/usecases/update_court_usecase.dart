import 'package:server_module/server_module.dart';

class UpdateCourtUseCase {
  final CourtRepository _repository;

  UpdateCourtUseCase(this._repository);

  Future<BaseResponse<CourtEntity>> call({
    required String id,
    required String name,
    required int pricePerHour,
    required String status,
  }) async {
    final Map<String, dynamic> data = {
      'name': name,
      'pricePerHour': pricePerHour,
      'status': status,
    };
    return await _repository.updateCourt(id, data);
  }
}
