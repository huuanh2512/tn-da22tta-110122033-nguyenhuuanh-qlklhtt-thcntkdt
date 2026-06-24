import 'package:server_module/server_module.dart';

class CreateCourtUseCase {
  final CourtRepository _repository;

  CreateCourtUseCase(this._repository);

  Future<BaseResponse<CourtEntity>> call({
    required String facilityId,
    required String sportId,
    required String name,
    required int pricePerHour,
    required String status,
  }) async {
    final Map<String, dynamic> data = {
      'facilityId': facilityId,
      'sportId': sportId,
      'name': name,
      'pricePerHour': pricePerHour,
      'status': status,
    };
    return await _repository.createCourt(data);
  }
}
