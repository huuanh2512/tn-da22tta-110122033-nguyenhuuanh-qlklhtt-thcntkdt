import 'package:equatable/equatable.dart';
import '../../domain/entities/review_detail_entity.dart';

abstract class ReviewState extends Equatable {
  const ReviewState();

  @override
  List<Object?> get props => [];
}

class ReviewInitial extends ReviewState {}

class ReviewLoading extends ReviewState {}

class ReviewsLoaded extends ReviewState {
  final List<ReviewDetailEntity> reviews;
  final double averageRating;

  const ReviewsLoaded({
    required this.reviews,
    required this.averageRating,
  });

  @override
  List<Object?> get props => [reviews, averageRating];
}

class ReviewError extends ReviewState {
  final String message;

  const ReviewError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReviewSubmitting extends ReviewState {}

class ReviewSubmitSuccess extends ReviewState {}
