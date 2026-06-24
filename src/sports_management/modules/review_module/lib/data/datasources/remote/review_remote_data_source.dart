import 'package:server_module/server_module.dart';

abstract class ReviewRemoteDataSource {
  Future<BaseResponse<dynamic>> getReviews();
  Future<BaseResponse<dynamic>> createReview(Map<String, dynamic> data);
  Future<BaseResponse<dynamic>> deleteReview(String id);
  Future<BaseResponse<dynamic>> getCourtReviews(String courtId);
}

class ReviewRemoteDataSourceImpl implements ReviewRemoteDataSource {
  final ReviewService _reviewService;
  final DioClient _dioClient;

  ReviewRemoteDataSourceImpl(this._reviewService, this._dioClient);

  @override
  Future<BaseResponse<dynamic>> getReviews() {
    return _reviewService.getReviews();
  }

  @override
  Future<BaseResponse<dynamic>> createReview(Map<String, dynamic> data) {
    return _reviewService.createReview(data);
  }

  @override
  Future<BaseResponse<dynamic>> deleteReview(String id) {
    return _reviewService.deleteReview(id);
  }

  @override
  Future<BaseResponse<dynamic>> getCourtReviews(String courtId) async {
    final response = await _dioClient.dio.get(
      '/review/',
      queryParameters: {'courtId': courtId},
    );
    return BaseResponse.fromJson(response.data, (json) => json);
  }
}
