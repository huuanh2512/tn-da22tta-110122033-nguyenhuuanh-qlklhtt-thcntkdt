import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/domain/entities/court_entity.dart';

abstract class CourtRepository {
  Future<BaseResponse<List<CourtEntity>>> getCourts({
    String? facilityId,
    String? sportId,
  });

  Future<BaseResponse<CourtEntity>> createCourt(Map<String, dynamic> data);

  Future<BaseResponse<CourtEntity>> updateCourt(
    String id,
    Map<String, dynamic> data,
  );

  Future<BaseResponse<dynamic>> deleteCourt(String id);

  Future<BaseResponse<dynamic>> getCourtSlotConfig(String id);

  Future<BaseResponse<dynamic>> updateCourtSlotConfig(
    String id,
    Map<String, dynamic> data,
  );
}
