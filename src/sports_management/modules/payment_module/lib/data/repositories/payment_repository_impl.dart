import 'package:server_module/server_module.dart';
import '../../domain/entities/payment_detail_entity.dart';
import '../datasources/remote/payment_remote_data_source.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource _remoteDataSource;

  PaymentRepositoryImpl(this._remoteDataSource);

  @override
  Future<BaseResponse<List<PaymentEntity>>> getPayments() async {
    try {
      final response = await _remoteDataSource.getPayments();
      if (!response.success || response.data == null) {
        return BaseResponse<List<PaymentEntity>>(
          success: response.success,
          message: response.message,
          data: null,
        );
      }
      final rawData = response.data as Map<String, dynamic>;
      final itemsList = rawData['items'] as List<dynamic>? ?? [];
      final payments = itemsList
          .whereType<Map<String, dynamic>>()
          .map(_parsePayment)
          .whereType<PaymentDetailEntity>()
          .toList();
      return BaseResponse<List<PaymentEntity>>(
        success: true,
        message: response.message,
        data: payments,
      );
    } catch (e) {
      return BaseResponse<List<PaymentEntity>>(
        success: false,
        message: 'Lỗi parse danh sách payment: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<PaymentEntity>> createPayment(
    Map<String, dynamic> data,
  ) async {
    final response = await _remoteDataSource.createPayment(data);
    return _mapToPaymentResponse(response);
  }

  @override
  Future<BaseResponse<PaymentEntity>> updatePaymentStatus(
    String id,
    String status,
  ) async {
    final response = await _remoteDataSource.updatePaymentStatus(id, status);
    return _mapToPaymentResponse(response);
  }

  // ---------------------------------------------------------------------------

  BaseResponse<PaymentDetailEntity> _mapToPaymentResponse(
    BaseResponse<dynamic> response,
  ) {
    if (!response.success || response.data == null) {
      return BaseResponse<PaymentDetailEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }
    try {
      final rawData = response.data as Map<String, dynamic>;
      final paymentMap =
          (rawData['payment'] as Map<String, dynamic>?) ?? rawData;
      final payment = _parsePayment(paymentMap);
      if (payment != null) {
        return BaseResponse<PaymentDetailEntity>(
          success: true,
          message: response.message,
          data: payment,
        );
      }
      return BaseResponse<PaymentDetailEntity>(
        success: false,
        message: 'Lỗi parse đối tượng payment',
        data: null,
      );
    } catch (e) {
      return BaseResponse<PaymentDetailEntity>(
        success: false,
        message: 'Lỗi parse payment: $e',
        data: null,
      );
    }
  }

  PaymentDetailEntity? _parsePayment(Map<String, dynamic> map) {
    try {
      final bookingMap = map['booking'] as Map<String, dynamic>?;
      BookingEntity? bookingEntity;
      if (bookingMap != null) {
        bookingEntity = BookingEntity(
          id:
              bookingMap['_id']?.toString() ??
              bookingMap['id']?.toString() ??
              '',
          userId: bookingMap['userId']?.toString(),
          courtId: bookingMap['courtId']?.toString(),
          status: bookingMap['status']?.toString(),
          totalPrice: (bookingMap['totalPrice'] as num?)?.toDouble(),
        );
      }

      final courtMap = bookingMap?['court'] as Map<String, dynamic>?;
      final sportMap = bookingMap?['sport'] as Map<String, dynamic>?;

      return PaymentDetailEntity(
        id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
        bookingId:
            map['bookingId']?.toString() ??
            bookingMap?['id']?.toString() ??
            bookingMap?['_id']?.toString(),
        amount: (map['amount'] as num?)?.toDouble(),
        method: map['method']?.toString(),
        status: map['status']?.toString(),
        booking: bookingEntity,
        courtName:
            courtMap?['name']?.toString() ??
            bookingMap?['courtName']?.toString(),
        sportName:
            sportMap?['name']?.toString() ??
            bookingMap?['sportName']?.toString(),
        bookingDate: _normalizeDate(bookingMap?['bookingDate']?.toString()),
        startMinutes: (bookingMap?['startMinutes'] as num?)?.toInt(),
        endMinutes: (bookingMap?['endMinutes'] as num?)?.toInt(),
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString())
            : null,
        transactionId: map['transactionId']?.toString(),
        refundedAt: map['refundedAt'] != null
            ? DateTime.tryParse(map['refundedAt'].toString())
            : null,
        refundedBy: map['refundedBy']?.toString(),
        refundReason: map['refundReason']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  String? _normalizeDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return null;
    final trimmed = rawDate.trim();
    if (trimmed.length == 10 &&
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return trimmed;
    }
    try {
      final parsed = DateTime.parse(trimmed).toLocal();
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (_) {
      if (trimmed.contains('T')) {
        return trimmed.split('T').first;
      }
      return trimmed;
    }
  }
}
