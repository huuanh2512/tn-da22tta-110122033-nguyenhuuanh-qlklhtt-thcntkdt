import 'package:server_module/server_module.dart';

class DeleteReviewUseCase {
  final ReviewRepository _repository;

  DeleteReviewUseCase(this._repository);

  Future<BaseResponse<dynamic>> call(String id) async {
    return await _repository.deleteReview(id);
  }
}
