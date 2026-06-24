import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class SportService {
  final DioClient _dioClient;

  SportService(this._dioClient);

  Future<BaseResponse<dynamic>> getSports() async {
    try {
      final response = await _dioClient.dio.get('/sport/');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> createSport(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.post('/sport/', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> updateSport(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.put('/sport/$id', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> deleteSport(String id) async {
    try {
      final response = await _dioClient.dio.delete('/sport/$id');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}