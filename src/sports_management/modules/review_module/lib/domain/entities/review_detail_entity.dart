import 'package:server_module/server_module.dart';

class ReviewDetailEntity extends ReviewEntity {
  final String? userName;
  final String? courtId;
  final DateTime? createdAt;

  const ReviewDetailEntity({
    required super.id,
    super.userId,
    super.facilityId,
    super.rating,
    super.comment,
    this.userName,
    this.courtId,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        facilityId,
        rating,
        comment,
        userName,
        courtId,
        createdAt,
      ];
}
