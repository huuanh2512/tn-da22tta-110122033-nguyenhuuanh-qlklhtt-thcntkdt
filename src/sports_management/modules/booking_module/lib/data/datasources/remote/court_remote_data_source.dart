import 'package:server_module/server_module.dart';

abstract class CourtRemoteDataSource {
  Future<BaseResponse<dynamic>> getCourts({
    String? facilityId,
    String? sportId,
  });
  Future<BaseResponse<dynamic>> createCourt(Map<String, dynamic> data);
  Future<BaseResponse<dynamic>> updateCourt(
    String id,
    Map<String, dynamic> data,
  );
  Future<BaseResponse<dynamic>> deleteCourt(String id);
  Future<BaseResponse<dynamic>> getCourtSlotConfig(
    String actualId,
    String query,
  );
  Future<BaseResponse<dynamic>> updateCourtSlotConfig(
    String id,
    Map<String, dynamic> data,
  );
}

class CourtRemoteDataSourceImpl implements CourtRemoteDataSource {
  final CourtService _courtService;
  final DioClient _dioClient;

  CourtRemoteDataSourceImpl(this._courtService, this._dioClient);

  @override
  Future<BaseResponse<dynamic>> getCourts({
    String? facilityId,
    String? sportId,
  }) async {
    final dio = _dioClient.dio;
    final queryParameters = <String, dynamic>{'limit': 10000};
    if (facilityId != null && facilityId.isNotEmpty) {
      queryParameters['facilityId'] = facilityId;
    }
    if (sportId != null && sportId.isNotEmpty) {
      queryParameters['sportId'] = sportId;
    }
    final dioResponse = await dio.get(
      '/court/',
      queryParameters: queryParameters,
    );
    return BaseResponse.fromJson(dioResponse.data, (json) => json);
  }

  @override
  Future<BaseResponse<dynamic>> createCourt(Map<String, dynamic> data) {
    return _courtService.createCourt(data);
  }

  @override
  Future<BaseResponse<dynamic>> updateCourt(
    String id,
    Map<String, dynamic> data,
  ) {
    return _courtService.updateCourt(id, data);
  }

  @override
  Future<BaseResponse<dynamic>> deleteCourt(String id) {
    return _courtService.deleteCourt(id);
  }

  @override
  Future<BaseResponse<dynamic>> getCourtSlotConfig(
    String actualId,
    String query,
  ) async {
    final dio = _dioClient.dio;
    try {
      final response = await dio.get('/court/$actualId/slot-config$query');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  @override
  Future<BaseResponse<dynamic>> updateCourtSlotConfig(
    String id,
    Map<String, dynamic> data,
  ) {
    return _courtService.updateCourtSlotConfig(id, data);
  }
}
