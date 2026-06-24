import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class FacilityService {
  final DioClient _dioClient;

  FacilityService(this._dioClient);

  Future<BaseResponse<dynamic>> getFacilities() async {
    try {
      final response = await _dioClient.dio.get('/facility/');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> createFacility(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.post('/facility/', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> updateFacility(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.put('/facility/$id', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> deleteFacility(String id) async {
    try {
      final response = await _dioClient.dio.delete('/facility/$id');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}