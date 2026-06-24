import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class ContentService {
  final DioClient _dioClient;

  ContentService(this._dioClient);

  Future<BaseResponse<dynamic>> getEmojis({Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dioClient.dio.get(
        '/emoji', 
        queryParameters: queryParams,
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> getHelpdesks({Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dioClient.dio.get(
        '/helpdesk', 
        queryParameters: queryParams,
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}