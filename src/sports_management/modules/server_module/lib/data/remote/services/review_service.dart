import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class ReviewService {
  final DioClient _dioClient;

  ReviewService(this._dioClient);

  Future<BaseResponse<dynamic>> getReviews() async {
    try {
      final response = await _dioClient.dio.get('/review/');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> createReview(Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.dio.post('/review/', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> deleteReview(String id) async {
    try {
      final response = await _dioClient.dio.delete('/review/$id');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}