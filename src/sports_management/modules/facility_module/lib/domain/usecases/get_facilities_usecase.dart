import 'package:server_module/server_module.dart';

class GetFacilitiesUseCase {
  final FacilityRepository _facilityRepository;

  GetFacilitiesUseCase(this._facilityRepository);

  Future<BaseResponse<List<FacilityEntity>>> call() {
    return _facilityRepository.getFacilities();
  }
}
