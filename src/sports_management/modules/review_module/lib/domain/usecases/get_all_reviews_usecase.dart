import 'package:server_module/server_module.dart';
import '../entities/review_detail_entity.dart';

class GetAllReviewsUseCase {
  final ReviewRepository _repository;

  GetAllReviewsUseCase(this._repository);

  Future<BaseResponse<List<ReviewDetailEntity>>> call({int? ratingFilter}) async {
    final response = await _repository.getReviews();

    if (!response.success || response.data == null) {
      return BaseResponse<List<ReviewDetailEntity>>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    final reviews = response.data!
        .whereType<ReviewDetailEntity>()
        .toList();

    if (ratingFilter != null) {
      return BaseResponse<List<ReviewDetailEntity>>(
        success: true,
        message: response.message,
        data: reviews.where((r) => r.rating == ratingFilter).toList(),
      );
    }

    return BaseResponse<List<ReviewDetailEntity>>(
      success: true,
      message: response.message,
      data: reviews,
    );
  }
}
