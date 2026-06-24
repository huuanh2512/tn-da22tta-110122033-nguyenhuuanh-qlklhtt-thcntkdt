import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/domain/entities/review_entity.dart';

abstract class ReviewRepository {
  Future<BaseResponse<List<ReviewEntity>>> getReviews();
  
  Future<BaseResponse<ReviewEntity>> createReview(Map<String, dynamic> data);
  
  Future<BaseResponse<dynamic>> deleteReview(String id);
}