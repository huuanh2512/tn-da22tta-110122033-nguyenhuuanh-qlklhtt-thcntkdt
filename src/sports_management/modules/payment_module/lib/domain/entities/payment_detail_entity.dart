import 'package:server_module/server_module.dart';

class PaymentDetailEntity extends PaymentEntity {
  final BookingEntity? booking;
  final String? courtName;
  final String? sportName;
  final String? bookingDate;
  final int? startMinutes;
  final int? endMinutes;
  final DateTime? createdAt;
  final String? transactionId;
  final DateTime? refundedAt;
  final String? refundedBy;
  final String? refundReason;

  const PaymentDetailEntity({
    required super.id,
    super.bookingId,
    super.amount,
    super.method,
    super.status,
    this.booking,
    this.courtName,
    this.sportName,
    this.bookingDate,
    this.startMinutes,
    this.endMinutes,
    this.createdAt,
    this.transactionId,
    this.refundedAt,
    this.refundedBy,
    this.refundReason,
  });

  @override
  List<Object?> get props => [
    id,
    bookingId,
    amount,
    method,
    status,
    booking,
    courtName,
    sportName,
    bookingDate,
    startMinutes,
    endMinutes,
    createdAt,
    transactionId,
    refundedAt,
    refundedBy,
    refundReason,
  ];
}
