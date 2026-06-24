import 'package:server_module/server_module.dart';

class CreateFacilityUseCase {
  final FacilityRepository _repository;

  CreateFacilityUseCase(this._repository);

  Future<BaseResponse<FacilityEntity>> call({
    required String name,
    required String address,
    required String city,
    required List<String> staffIds,
    required bool active,
  }) async {
    final Map<String, dynamic> data = {
      'name': name,
      'fullAddress': address,
      'city': city,
      'staffIds': staffIds,
      'active': active,
    };
    return await _repository.createFacility(data);
  }
}
