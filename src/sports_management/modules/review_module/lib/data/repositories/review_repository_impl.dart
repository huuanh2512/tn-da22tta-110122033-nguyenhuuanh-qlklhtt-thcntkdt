import 'package:server_module/server_module.dart';
import '../../domain/entities/review_detail_entity.dart';
import '../datasources/remote/review_remote_data_source.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewRemoteDataSource _remoteDataSource;

  ReviewRepositoryImpl(this._remoteDataSource);

  @override
  Future<BaseResponse<List<ReviewEntity>>> getReviews() async {
    final response = await _remoteDataSource.getReviews();
    return _mapToReviewsListResponse(response);
  }

  @override
  Future<BaseResponse<ReviewEntity>> createReview(Map<String, dynamic> data) async {
    final response = await _remoteDataSource.createReview(data);
    if (!response.success || response.data == null) {
      return BaseResponse<ReviewEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }
    try {
      final rawData = response.data as Map<String, dynamic>;
      final reviewMap = (rawData['review'] as Map<String, dynamic>?) ?? rawData;
      final review = _parseReview(reviewMap);
      if (review != null) {
        return BaseResponse<ReviewEntity>(
          success: true,
          message: response.message,
          data: review,
        );
      }
      return BaseResponse<ReviewEntity>(
        success: false,
        message: 'Lỗi parse đối tượng review',
        data: null,
      );
    } catch (e) {
      return BaseResponse<ReviewEntity>(
        success: false,
        message: 'Lỗi parse review: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<dynamic>> deleteReview(String id) async {
    return await _remoteDataSource.deleteReview(id);
  }

  // ── Custom Method for Court Reviews ────────────────────────────────────────
  Future<BaseResponse<List<ReviewDetailEntity>>> getCourtReviews(String courtId) async {
    try {
      final baseResponse = await _remoteDataSource.getCourtReviews(courtId);
      return _mapToReviewsListResponse(baseResponse);
    } catch (e) {
      return BaseResponse<List<ReviewDetailEntity>>(
        success: false,
        message: 'Lỗi lấy danh sách đánh giá: $e',
        data: null,
      );
    }
  }

  // ── Parsers ────────────────────────────────────────────────────────────────
  BaseResponse<List<ReviewDetailEntity>> _mapToReviewsListResponse(
      BaseResponse<dynamic> response) {
    if (!response.success || response.data == null) {
      return BaseResponse<List<ReviewDetailEntity>>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }
    try {
      final rawData = response.data as Map<String, dynamic>;
      final itemsList = rawData['items'] as List<dynamic>? ?? [];
      final reviews = itemsList
          .whereType<Map<String, dynamic>>()
          .map(_parseReview)
          .whereType<ReviewDetailEntity>()
          .toList();
      return BaseResponse<List<ReviewDetailEntity>>(
        success: true,
        message: response.message,
        data: reviews,
      );
    } catch (e) {
      return BaseResponse<List<ReviewDetailEntity>>(
        success: false,
        message: 'Lỗi parse danh sách review: $e',
        data: null,
      );
    }
  }

  ReviewDetailEntity? _parseReview(Map<String, dynamic> map) {
    try {
      final userMap = map['user'] as Map<String, dynamic>?;
      return ReviewDetailEntity(
        id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
        userId: map['userId']?.toString(),
        facilityId: map['facilityId']?.toString(),
        rating: (map['rating'] as num?)?.toInt(),
        comment: map['comment']?.toString(),
        userName: userMap?['fullName']?.toString() ?? 'Khách hàng',
        courtId: map['courtId']?.toString(),
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString())
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}
