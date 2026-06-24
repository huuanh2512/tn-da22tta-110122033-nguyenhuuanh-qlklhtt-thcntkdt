import 'package:server_module/server_module.dart';
import '../../domain/entities/booking_detail_entity.dart';

class BookingDetailModel extends BookingDetailEntity {
  const BookingDetailModel({
    required super.id,
    super.userId,
    super.guestName,
    super.guestPhone,
    super.user,
    super.courtId,
    super.court,
    super.courtName,
    super.courtCode,
    super.sportName,
    super.bookingDate,
    super.startMinutes,
    super.endMinutes,
    super.totalPrice,
    super.status,
    super.fixedScheduleId,
    super.isFixedSchedule,
    super.paymentStatus,
    super.cancelReason,
    super.cancelledBy,
    super.cancelledAt,
    super.createdAt,
    super.isMatching,
    super.matchingSessionId,
    super.isHost,
    super.paymentPolicy,
    super.myPaymentStatus,
    super.myPaymentAmount,
    super.membersCount,
  });

  factory BookingDetailModel.fromJson(Map<String, dynamic> json) {
    // Manual mapping for UserEntity to avoid UserModel mismatch if any
    UserEntity? userEntity;
    if (json['user'] != null) {
      final u = json['user'];
      final profile = u['profile'] is Map
          ? Map<String, dynamic>.from(u['profile'] as Map)
          : const <String, dynamic>{};
      userEntity = UserEntity(
        id: u['_id'] ?? u['id'] ?? '',
        email: u['email'],
        name: u['name'] ?? profile['name'] ?? profile['fullName'],
        avatar: u['avatar'],
        phone: u['phone']?.toString() ?? profile['phone']?.toString(),
        role: u['role'],
        status: u['status'],
      );
    }

    // Manual mapping for CourtEntity to avoid CourtModel mismatch if any
    CourtEntity? courtEntity;
    if (json['court'] != null) {
      final c = json['court'];
      courtEntity = CourtEntity(
        id: c['_id'] ?? c['id'] ?? '',
        facilityId: c['facilityId'],
        sportId: c['sportId'],
        name: c['name'],
        status: c['status'],
      );
    }

    return BookingDetailModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString(),
      guestName:
          json['guestName']?.toString() ?? json['guest_name']?.toString(),
      guestPhone:
          json['guestPhone']?.toString() ?? json['guest_phone']?.toString(),
      user: userEntity,
      courtId: json['courtId']?.toString(),
      court: courtEntity,
      courtName: json['court']?['name']?.toString(),
      courtCode: json['court']?['code']?.toString(),
      sportName:
          json['sport']?['name']?.toString() ??
          json['court']?['sport']?['name']?.toString() ??
          json['sportName']?.toString(),
      bookingDate: json['bookingDate']?.toString(),
      startMinutes: (json['startMinutes'] as num?)?.toInt(),
      endMinutes: (json['endMinutes'] as num?)?.toInt(),
      totalPrice: (json['totalPrice'] as num?)?.toDouble(),
      status: json['status']?.toString(),
      fixedScheduleId:
          json['fixedScheduleId']?.toString() ??
          json['fixed_schedule_id']?.toString(),
      isFixedSchedule:
          json['isFixedSchedule'] as bool? ??
          json['is_fixed_schedule'] as bool?,
      paymentStatus:
          json['paymentStatus']?.toString() ??
          json['payment_status']?.toString(),
      cancelReason:
          json['cancelReason']?.toString() ?? json['cancel_reason']?.toString(),
      cancelledBy:
          json['cancelledBy']?.toString() ?? json['cancelled_by']?.toString(),
      cancelledAt: json['cancelledAt'] != null || json['cancelled_at'] != null
          ? DateTime.tryParse(
              (json['cancelledAt'] ?? json['cancelled_at']).toString(),
            )
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      isMatching:
          json['isMatching'] as bool? ?? json['is_matching'] as bool? ?? false,
      matchingSessionId:
          json['matchingSessionId']?.toString() ??
          json['matching_session_id']?.toString(),
      isHost: json['isHost'] as bool? ?? json['is_host'] as bool? ?? false,
      paymentPolicy:
          json['paymentPolicy']?.toString() ??
          json['payment_policy']?.toString(),
      myPaymentStatus:
          json['myPaymentStatus']?.toString() ??
          json['my_payment_status']?.toString(),
      myPaymentAmount:
          (json['myPaymentAmount'] as num?)?.toDouble() ??
          (json['my_payment_amount'] as num?)?.toDouble(),
      membersCount:
          (json['membersCount'] as num?)?.toInt() ??
          (json['members_count'] as num?)?.toInt(),
    );
  }
}
