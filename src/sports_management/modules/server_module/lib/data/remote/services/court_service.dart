import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class CourtService {
  final DioClient _dioClient;

  CourtService(this._dioClient);

  Future<BaseResponse<dynamic>> getCourts() async {
    try {
      final response = await _dioClient.dio.get('/court/');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> createCourt(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.post('/court/', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> updateCourt(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.put('/court/$id', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> deleteCourt(String id) async {
    try {
      final response = await _dioClient.dio.delete('/court/$id');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> getCourtSlotConfig(String id) async {
    try {
      final response = await _dioClient.dio.get('/court/$id/slot-config');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> updateCourtSlotConfig(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.put(
        '/court/$id/slot-config',
        data: data,
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}