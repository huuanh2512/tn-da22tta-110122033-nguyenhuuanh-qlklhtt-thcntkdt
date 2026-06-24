import 'package:equatable/equatable.dart';

class ReviewEntity extends Equatable {
  final String id;
  final String? userId;
  final String? facilityId;
  final int? rating;
  final String? comment;

  const ReviewEntity({
    required this.id,
    this.userId,
    this.facilityId,
    this.rating,
    this.comment,
  });

  @override
  List<Object?> get props => [id, userId, facilityId, rating, comment];
}