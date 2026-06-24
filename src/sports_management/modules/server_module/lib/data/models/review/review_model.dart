import 'package:equatable/equatable.dart';

class ReviewModel extends Equatable {
  final String id;
  final String? userId;
  final String? facilityId;
  final int? rating;
  final String? comment;

  const ReviewModel({
    required this.id,
    this.userId,
    this.facilityId,
    this.rating,
    this.comment,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId'] as String?,
      facilityId: json['facilityId'] as String?,
      rating: json['rating'] as int?,
      comment: json['comment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'facilityId': facilityId,
      'rating': rating,
      'comment': comment,
    };
  }

  @override
  List<Object?> get props => [id, userId, facilityId, rating, comment];
}