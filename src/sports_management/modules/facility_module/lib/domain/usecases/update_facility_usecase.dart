import 'package:server_module/server_module.dart';

class UpdateFacilityUseCase {
  final FacilityRepository _repository;

  UpdateFacilityUseCase(this._repository);

  Future<BaseResponse<FacilityEntity>> call({
    required String id,
    String? name,
    String? address,
    String? city,
    List<String>? staffIds,
    bool? active,
  }) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (address != null) data['fullAddress'] = address;
    if (city != null) data['city'] = city;
    if (staffIds != null) data['staffIds'] = staffIds;
    if (active != null) data['active'] = active;
    return await _repository.updateFacility(id, data);
  }
}
