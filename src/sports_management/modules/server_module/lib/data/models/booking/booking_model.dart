import 'package:equatable/equatable.dart';

class BookingModel extends Equatable {
  final String id;
  final String? userId;
  final String? courtId;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? status;
  final double? totalPrice;
  final String? fixedScheduleId;
  final bool? isFixedSchedule;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;

  const BookingModel({
    required this.id,
    this.userId,
    this.courtId,
    this.startTime,
    this.endTime,
    this.status,
    this.totalPrice,
    this.fixedScheduleId,
    this.isFixedSchedule,
    this.cancelReason,
    this.cancelledBy,
    this.cancelledAt,
  });

  static bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return null;
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final fixedScheduleId = json['fixedScheduleId']?.toString() ??
        json['fixed_schedule_id']?.toString() ??
        json['fixedSchedule']?['id']?.toString() ??
        json['fixedSchedule']?['_id']?.toString();

    return BookingModel(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId'] as String?,
      courtId: json['courtId'] as String?,
      startTime: json['startTime'] != null 
          ? DateTime.tryParse(json['startTime'].toString()) 
          : null,
      endTime: json['endTime'] != null 
          ? DateTime.tryParse(json['endTime'].toString()) 
          : null,
      status: json['status'] as String?,
      totalPrice: (json['totalPrice'] as num?)?.toDouble(),
      fixedScheduleId: fixedScheduleId,
      isFixedSchedule: _readBool(json['isFixedSchedule']) ??
          _readBool(json['is_fixed_schedule']) ??
          (fixedScheduleId != null),
      cancelReason: json['cancelReason']?.toString() ?? json['cancel_reason']?.toString(),
      cancelledBy: json['cancelledBy']?.toString() ?? json['cancelled_by']?.toString(),
      cancelledAt: json['cancelledAt'] != null || json['cancelled_at'] != null
          ? DateTime.tryParse((json['cancelledAt'] ?? json['cancelled_at']).toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'courtId': courtId,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status,
      'totalPrice': totalPrice,
      'fixedScheduleId': fixedScheduleId,
      'isFixedSchedule': isFixedSchedule,
      'cancelReason': cancelReason,
      'cancelledBy': cancelledBy,
      'cancelledAt': cancelledAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        courtId,
        startTime,
        endTime,
        status,
        totalPrice,
        fixedScheduleId,
        isFixedSchedule,
        cancelReason,
        cancelledBy,
        cancelledAt,
      ];
}
