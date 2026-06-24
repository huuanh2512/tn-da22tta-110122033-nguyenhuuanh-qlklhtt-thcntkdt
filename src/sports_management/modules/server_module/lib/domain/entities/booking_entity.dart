import 'package:equatable/equatable.dart';

class BookingEntity extends Equatable {
  final String id;
  final String? userId;
  final String? guestName;
  final String? guestPhone;
  final String? courtId;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? status;
  final double? totalPrice;
  final String? fixedScheduleId;
  final bool? isFixedSchedule;
  final String? paymentStatus;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;

  const BookingEntity({
    required this.id,
    this.userId,
    this.guestName,
    this.guestPhone,
    this.courtId,
    this.startTime,
    this.endTime,
    this.status,
    this.totalPrice,
    this.fixedScheduleId,
    this.isFixedSchedule,
    this.paymentStatus,
    this.cancelReason,
    this.cancelledBy,
    this.cancelledAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    guestName,
    guestPhone,
    courtId,
    startTime,
    endTime,
    status,
    totalPrice,
    fixedScheduleId,
    isFixedSchedule,
    paymentStatus,
    cancelReason,
    cancelledBy,
    cancelledAt,
  ];
}
