import 'package:server_module/server_module.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../entities/review_detail_entity.dart';

class GetCourtReviewsUseCase {
  final ReviewRepository _repository;

  GetCourtReviewsUseCase(this._repository);

  Future<BaseResponse<List<ReviewDetailEntity>>> call(String courtId) async {
    if (_repository is ReviewRepositoryImpl) {
      return await _repository.getCourtReviews(courtId);
    }
    return BaseResponse<List<ReviewDetailEntity>>(
      success: false,
      message: 'Repository implementation is invalid',
      data: null,
    );
  }
}
