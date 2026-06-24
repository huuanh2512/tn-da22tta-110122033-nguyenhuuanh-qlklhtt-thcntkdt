import 'package:server_module/server_module.dart';

class AdvancedPerformanceReportModel extends AdvancedPerformanceReportEntity {
  const AdvancedPerformanceReportModel({
    required super.dateFrom,
    required super.dateTo,
    required super.dayCount,
    required super.summary,
    required super.sportStats,
    required super.courtStats,
    required super.facilityStats,
    required super.dailyStats,
    required super.weekdayStats,
    required super.peakHours,
    required super.customerStats,
    required super.utilizationNote,
  });

  factory AdvancedPerformanceReportModel.fromJson(Map<String, dynamic> json) {
    final dateRange = json['dateRange'] as Map<String, dynamic>? ?? const {};
    final utilizationBasis =
        json['utilizationBasis'] as Map<String, dynamic>? ?? const {};
    final summaryMap = json['summary'] as Map<String, dynamic>? ?? const {};

    return AdvancedPerformanceReportModel(
      dateFrom: dateRange['dateFrom']?.toString() ?? '',
      dateTo: dateRange['dateTo']?.toString() ?? '',
      dayCount: (dateRange['dayCount'] as num?)?.toInt() ?? 0,
      summary: AdvancedReportSummaryModel.fromJson(summaryMap),
      sportStats: _parseGroups(json['sportStats'] as List<dynamic>?),
      courtStats: (json['courtStats'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdvancedCourtStatModel.fromJson)
          .toList(),
      facilityStats: _parseGroups(json['facilityStats'] as List<dynamic>?),
      dailyStats: _parseGroups(json['dailyStats'] as List<dynamic>?),
      weekdayStats: _parseGroups(json['weekdayStats'] as List<dynamic>?),
      peakHours: (json['peakHours'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdvancedPeakHourStatModel.fromJson)
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

  static List<AdvancedGroupStatEntity> _parseGroups(List<dynamic>? items) {
    return (items ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AdvancedGroupStatModel.fromJson)
        .toList();
  }
}

class AdvancedReportSummaryModel extends AdvancedReportSummaryEntity {
  const AdvancedReportSummaryModel({
    required super.totalBookings,
    required super.activeBookings,
    required super.pendingBookings,
    required super.confirmedBookings,
    required super.completedBookings,
    required super.cancelledBookings,
    required super.bookedMinutes,
    required super.availableMinutes,
    required super.unavailableMinutes,
    required super.paidRevenue,
    required super.pendingRevenue,
    required super.paidCancelledAmount,
    required super.refundPendingAmount,
    required super.refundedAmount,
    required super.utilizationRate,
    required super.averagePaidRevenuePerActiveBooking,
  });

  factory AdvancedReportSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdvancedReportSummaryModel(
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
      activeBookings: (json['activeBookings'] as num?)?.toInt() ?? 0,
      pendingBookings: (json['pendingBookings'] as num?)?.toInt() ?? 0,
      confirmedBookings: (json['confirmedBookings'] as num?)?.toInt() ?? 0,
      completedBookings: (json['completedBookings'] as num?)?.toInt() ?? 0,
      cancelledBookings: (json['cancelledBookings'] as num?)?.toInt() ?? 0,
      bookedMinutes: (json['bookedMinutes'] as num?)?.toInt() ?? 0,
      availableMinutes: (json['availableMinutes'] as num?)?.toInt() ?? 0,
      unavailableMinutes: (json['unavailableMinutes'] as num?)?.toInt() ?? 0,
      paidRevenue: (json['paidRevenue'] as num?)?.toDouble() ?? 0,
      pendingRevenue: (json['pendingRevenue'] as num?)?.toDouble() ?? 0,
      paidCancelledAmount:
          (json['paidCancelledAmount'] as num?)?.toDouble() ?? 0,
      refundPendingAmount:
          (json['refundPendingAmount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (json['refundedAmount'] as num?)?.toDouble() ?? 0,
      utilizationRate: (json['utilizationRate'] as num?)?.toDouble() ?? 0,
      averagePaidRevenuePerActiveBooking:
          (json['averagePaidRevenuePerActiveBooking'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdvancedGroupStatModel extends AdvancedGroupStatEntity {
  const AdvancedGroupStatModel({
    required super.id,
    required super.name,
    super.date,
    super.weekday,
    required super.totalBookings,
    required super.activeBookings,
    required super.bookedMinutes,
    required super.availableMinutes,
    super.unavailableMinutes,
    super.blockCount,
    required super.paidRevenue,
    required super.utilizationRate,
  });

  factory AdvancedGroupStatModel.fromJson(Map<String, dynamic> json) {
    final date = json['date']?.toString();
    final weekday = (json['weekday'] as num?)?.toInt();
    return AdvancedGroupStatModel(
      id:
          json['sportId']?.toString() ??
          json['facilityId']?.toString() ??
          date ??
          weekday?.toString() ??
          '',
      name:
          json['sportName']?.toString() ??
          json['facilityName']?.toString() ??
          date ??
          (weekday != null ? 'Thứ ${weekday + 1}' : ''),
      date: date,
      weekday: weekday,
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
      activeBookings: (json['activeBookings'] as num?)?.toInt() ?? 0,
      bookedMinutes: (json['bookedMinutes'] as num?)?.toInt() ?? 0,
      availableMinutes: (json['availableMinutes'] as num?)?.toInt() ?? 0,
      unavailableMinutes: (json['unavailableMinutes'] as num?)?.toInt() ?? 0,
      blockCount: (json['blockCount'] as num?)?.toInt() ?? 0,
      paidRevenue: (json['paidRevenue'] as num?)?.toDouble() ?? 0,
      utilizationRate: (json['utilizationRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdvancedCourtStatModel extends AdvancedCourtStatEntity {
  const AdvancedCourtStatModel({
    required super.courtId,
    required super.courtName,
    required super.facilityId,
    required super.facilityName,
    required super.sportId,
    required super.sportName,
    required super.status,
    required super.totalBookings,
    required super.activeBookings,
    required super.bookedMinutes,
    required super.availableMinutes,
    super.unavailableMinutes,
    super.blockCount,
    required super.paidRevenue,
    required super.utilizationRate,
    super.utilizationNote,
  });

  factory AdvancedCourtStatModel.fromJson(Map<String, dynamic> json) {
    return AdvancedCourtStatModel(
      courtId: json['courtId']?.toString() ?? '',
      courtName: json['courtName']?.toString() ?? '',
      facilityId: json['facilityId']?.toString() ?? '',
      facilityName: json['facilityName']?.toString() ?? '',
      sportId: json['sportId']?.toString() ?? '',
      sportName: json['sportName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
      activeBookings: (json['activeBookings'] as num?)?.toInt() ?? 0,
      bookedMinutes: (json['bookedMinutes'] as num?)?.toInt() ?? 0,
      availableMinutes: (json['availableMinutes'] as num?)?.toInt() ?? 0,
      unavailableMinutes: (json['unavailableMinutes'] as num?)?.toInt() ?? 0,
      blockCount: (json['blockCount'] as num?)?.toInt() ?? 0,
      paidRevenue: (json['paidRevenue'] as num?)?.toDouble() ?? 0,
      utilizationRate: (json['utilizationRate'] as num?)?.toDouble() ?? 0,
      utilizationNote: json['utilizationNote']?.toString() ?? '',
    );
  }
}

class AdvancedPeakHourStatModel extends AdvancedPeakHourStatEntity {
  const AdvancedPeakHourStatModel({
    required super.hour,
    required super.label,
    required super.bookingCount,
    required super.bookedMinutes,
    required super.paidRevenue,
  });

  factory AdvancedPeakHourStatModel.fromJson(Map<String, dynamic> json) {
    return AdvancedPeakHourStatModel(
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? '',
      bookingCount: (json['bookingCount'] as num?)?.toInt() ?? 0,
      bookedMinutes: (json['bookedMinutes'] as num?)?.toInt() ?? 0,
      paidRevenue: (json['paidRevenue'] as num?)?.toDouble() ?? 0,
    );
  }
}
