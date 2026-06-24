import 'package:server_module/server_module.dart';

abstract class FacilityRemoteDataSource {
  Future<BaseResponse<dynamic>> getFacilities();
  Future<BaseResponse<dynamic>> createFacility(Map<String, dynamic> data);
  Future<BaseResponse<dynamic>> updateFacility(String id, Map<String, dynamic> data);
  Future<BaseResponse<dynamic>> deleteFacility(String id);
}

class FacilityRemoteDataSourceImpl implements FacilityRemoteDataSource {
  final FacilityService _facilityService;

  FacilityRemoteDataSourceImpl(this._facilityService);

  @override
  Future<BaseResponse<dynamic>> getFacilities() {
    return _facilityService.getFacilities();
  }

  @override
  Future<BaseResponse<dynamic>> createFacility(Map<String, dynamic> data) {
    return _facilityService.createFacility(data);
  }

  @override
  Future<BaseResponse<dynamic>> updateFacility(String id, Map<String, dynamic> data) {
    return _facilityService.updateFacility(id, data);
  }

  @override
  Future<BaseResponse<dynamic>> deleteFacility(String id) {
    return _facilityService.deleteFacility(id);
  }
}
