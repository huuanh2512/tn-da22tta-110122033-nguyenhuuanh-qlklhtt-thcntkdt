import 'package:server_module/server_module.dart';

class DeleteFacilityUseCase {
  final FacilityRepository _repository;

  DeleteFacilityUseCase(this._repository);

  Future<BaseResponse<dynamic>> call(String id) async {
    return await _repository.deleteFacility(id);
  }
}
