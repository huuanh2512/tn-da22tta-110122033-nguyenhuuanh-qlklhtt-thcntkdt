import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/domain/entities/sport_entity.dart';

abstract class SportRepository {
  Future<BaseResponse<List<SportEntity>>> getSports();
  
  Future<BaseResponse<SportEntity>> createSport(Map<String, dynamic> data);
  
  Future<BaseResponse<SportEntity>> updateSport(String id, Map<String, dynamic> data);
  
  Future<BaseResponse<dynamic>> deleteSport(String id);
}