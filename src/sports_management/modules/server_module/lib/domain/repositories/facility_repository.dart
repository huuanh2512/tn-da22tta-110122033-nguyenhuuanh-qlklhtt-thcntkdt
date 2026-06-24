import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/domain/entities/facility_entity.dart';

abstract class FacilityRepository {
  Future<BaseResponse<List<FacilityEntity>>> getFacilities();
  
  Future<BaseResponse<FacilityEntity>> createFacility(Map<String, dynamic> data);
  
  Future<BaseResponse<FacilityEntity>> updateFacility(String id, Map<String, dynamic> data);
  
  Future<BaseResponse<dynamic>> deleteFacility(String id);
}