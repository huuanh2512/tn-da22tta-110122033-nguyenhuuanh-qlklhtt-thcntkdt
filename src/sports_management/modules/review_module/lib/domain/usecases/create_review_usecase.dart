import 'package:server_module/server_module.dart';

class CreateReviewUseCase {
  final ReviewRepository _repository;

  CreateReviewUseCase(this._repository);

  Future<BaseResponse<ReviewEntity>> call({
    required String courtId,
    required int rating,
    required String comment,
  }) async {
    final Map<String, dynamic> data = {
      'courtId': courtId,
      'rating': rating,
      'comment': comment,
    };
    return await _repository.createReview(data);
  }
}
