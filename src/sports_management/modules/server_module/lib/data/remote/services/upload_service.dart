import 'package:dio/dio.dart';
import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class UploadService {
  final DioClient _dioClient;

  UploadService(this._dioClient);

  Future<BaseResponse<dynamic>> uploadSingle(FormData formData) async {
    try {
      final response = await _dioClient.dio.post(
        '/upload/single',
        data: formData,
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> uploadMultiple(FormData formData) async {
    try {
      final response = await _dioClient.dio.post(
        '/upload/multiple',
        data: formData,
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}