import 'package:server_module/server_module.dart';

class BookingDetailEntity extends BookingEntity {
  final UserEntity? user;
  final CourtEntity? court;
  final String? courtName;
  final String? courtCode;
  final String? sportName;
  final String? bookingDate;
  final int? startMinutes;
  final int? endMinutes;
  final DateTime? createdAt;
  final bool isMatching;
  final String? matchingSessionId;
  final bool isHost;
  final String? paymentPolicy;
  final String? myPaymentStatus;
  final double? myPaymentAmount;
  final int? membersCount;

  const BookingDetailEntity({
    required super.id,
    super.userId,
    super.guestName,
    super.guestPhone,
    this.user,
    super.courtId,
    this.court,
    this.courtName,
    this.courtCode,
    this.sportName,
    this.bookingDate,
    this.startMinutes,
    this.endMinutes,
    super.totalPrice,
    super.status,
    super.fixedScheduleId,
    super.isFixedSchedule,
    super.paymentStatus,
    super.cancelReason,
    super.cancelledBy,
    super.cancelledAt,
    this.createdAt,
    this.isMatching = false,
    this.matchingSessionId,
    this.isHost = false,
    this.paymentPolicy,
    this.myPaymentStatus,
    this.myPaymentAmount,
    this.membersCount,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    guestName,
    guestPhone,
    user,
    courtId,
    court,
    courtName,
    courtCode,
    sportName,
    bookingDate,
    startMinutes,
    endMinutes,
    totalPrice,
    status,
    fixedScheduleId,
    isFixedSchedule,
    paymentStatus,
    cancelReason,
    cancelledBy,
    cancelledAt,
    createdAt,
    isMatching,
    matchingSessionId,
    isHost,
    paymentPolicy,
    myPaymentStatus,
    myPaymentAmount,
    membersCount,
  ];
}
