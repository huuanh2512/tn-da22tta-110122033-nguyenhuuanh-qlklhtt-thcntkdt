import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_court_reviews_usecase.dart';
import '../../domain/usecases/create_review_usecase.dart';
import 'review_state.dart';

class ReviewCubit extends Cubit<ReviewState> {
  final GetCourtReviewsUseCase _getCourtReviewsUseCase;
  final CreateReviewUseCase _createReviewUseCase;

  ReviewCubit(
    this._getCourtReviewsUseCase,
    this._createReviewUseCase,
  ) : super(ReviewInitial());

  Future<void> loadCourtReviews(String courtId) async {
    emit(ReviewLoading());
    try {
      final response = await _getCourtReviewsUseCase(courtId);
      if (response.success && response.data != null) {
        final reviews = response.data!;
        double avg = 0.0;
        if (reviews.isNotEmpty) {
          final totalRating = reviews.map((r) => r.rating ?? 0).reduce((a, b) => a + b);
          avg = totalRating / reviews.length;
        }
        emit(ReviewsLoaded(reviews: reviews, averageRating: avg));
      } else {
        emit(ReviewError(response.message ?? 'Không thể tải danh sách đánh giá'));
      }
    } catch (e) {
      emit(ReviewError('Lỗi tải đánh giá: $e'));
    }
  }

  Future<void> submitReview({
    required String courtId,
    required int rating,
    required String comment,
  }) async {
    emit(ReviewSubmitting());
    try {
      final response = await _createReviewUseCase(
        courtId: courtId,
        rating: rating,
        comment: comment,
      );
      if (response.success) {
        emit(ReviewSubmitSuccess());
      } else {
        emit(ReviewError(response.message ?? 'Không thể gửi đánh giá'));
      }
    } catch (e) {
      emit(ReviewError('Lỗi gửi đánh giá: $e'));
    }
  }
}
