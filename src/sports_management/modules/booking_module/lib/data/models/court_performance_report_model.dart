import 'package:server_module/server_module.dart';

class CourtPerformanceReportModel extends CourtPerformanceReportEntity {
  const CourtPerformanceReportModel({
    required super.dateFrom,
    required super.dateTo,
    required super.dayCount,
    required super.totalBookings,
    required super.totalActiveBookings,
    required super.pendingBookings,
    required super.confirmedBookings,
    required super.completedBookings,
    required super.cancelledBookings,
    required super.paidRevenue,
    required super.pendingRevenue,
    required super.paidCancelledAmount,
    required super.refundPendingAmount,
    required super.refundedAmount,
    required super.baseAvailableMinutes,
    required super.availableMinutes,
    required super.unavailableMinutes,
    required super.bookedMinutes,
    required super.blockCount,
    required super.utilizationRate,
    required super.courtStats,
    required super.peakHours,
    required super.customerStats,
    required super.utilizationNote,
  });

  factory CourtPerformanceReportModel.fromJson(Map<String, dynamic> json) {
    final dateRange = json['dateRange'] as Map<String, dynamic>? ?? const {};
    final utilizationBasis =
        json['utilizationBasis'] as Map<String, dynamic>? ?? const {};

    return CourtPerformanceReportModel(
      dateFrom: dateRange['dateFrom']?.toString() ?? '',
      dateTo: dateRange['dateTo']?.toString() ?? '',
      dayCount: (dateRange['dayCount'] as num?)?.toInt() ?? 0,
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
      totalActiveBookings: (json['totalActiveBookings'] as num?)?.toInt() ?? 0,
      pendingBookings: (json['pendingBookings'] as num?)?.toInt() ?? 0,
      confirmedBookings: (json['confirmedBookings'] as num?)?.toInt() ?? 0,
      completedBookings: (json['completedBookings'] as num?)?.toInt() ?? 0,
      cancelledBookings: (json['cancelledBookings'] as num?)?.toInt() ?? 0,
      paidRevenue: (json['paidRevenue'] as num?)?.toDouble() ?? 0,
      pendingRevenue: (json['pendingRevenue'] as num?)?.toDouble() ?? 0,
      paidCancelledAmount:
          (json['paidCancelledAmount'] as num?)?.toDouble() ?? 0,
      refundPendingAmount:
          (json['refundPendingAmount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (json['refundedAmount'] as num?)?.toDouble() ?? 0,
      baseAvailableMinutes:
          (json['baseAvailableMinutes'] as num?)?.toInt() ?? 0,
      availableMinutes: (json['availableMinutes'] as num?)?.toInt() ?? 0,
      unavailableMinutes: (json['unavailableMinutes'] as num?)?.toInt() ?? 0,
      bookedMinutes: (json['bookedMinutes'] as num?)?.toInt() ?? 0,
      blockCount: (json['blockCount'] as num?)?.toInt() ?? 0,
      utilizationRate: (json['utilizationRate'] as num?)?.toDouble() ?? 0,
      courtStats: (json['courtStats'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => CourtPerformanceStatEntity(
              courtId: item['courtId']?.toString() ?? '',
              courtName: item['courtName']?.toString() ?? '',
              status: item['status']?.toString() ?? '',
              activeBookings: (item['activeBookings'] as num?)?.toInt() ?? 0,
              confirmedBookings:
                  (item['confirmedBookings'] as num?)?.toInt() ?? 0,
              completedBookings:
                  (item['completedBookings'] as num?)?.toInt() ?? 0,
              bookedMinutes: (item['bookedMinutes'] as num?)?.toInt() ?? 0,
              baseAvailableMinutes:
                  (item['baseAvailableMinutes'] as num?)?.toInt() ?? 0,
              availableMinutes:
                  (item['availableMinutes'] as num?)?.toInt() ?? 0,
              unavailableMinutes:
                  (item['unavailableMinutes'] as num?)?.toInt() ?? 0,
              blockCount: (item['blockCount'] as num?)?.toInt() ?? 0,
              blockedBookingCount:
                  (item['blockedBookingCount'] as num?)?.toInt() ?? 0,
              utilizationRate:
                  (item['utilizationRate'] as num?)?.toDouble() ?? 0,
              bookingShareRate:
                  (item['bookingShareRate'] as num?)?.toDouble() ?? 0,
              paidRevenue: (item['paidRevenue'] as num?)?.toDouble() ?? 0,
              utilizationNote: item['utilizationNote']?.toString() ?? '',
            ),
          )
          .toList(),
      peakHours: (json['peakHours'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => PeakHourStatEntity(
              label: item['label']?.toString() ?? '',
              bookingCount: (item['bookingCount'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
      customerStats: (json['customerStats'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => ReportCustomerStatEntity(
              customerKey: item['customerKey']?.toString() ?? '',
              displayName: item['displayName']?.toString() ?? '',
              bookingCount: (item['bookingCount'] as num?)?.toInt() ?? 0,
              paidRevenue: (item['paidRevenue'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(),
      utilizationNote: utilizationBasis['note']?.toString() ?? '',
    );
  }
}
