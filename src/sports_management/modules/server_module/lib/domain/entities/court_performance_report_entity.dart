class CourtPerformanceReportEntity {
  final String dateFrom;
  final String dateTo;
  final int dayCount;
  final int totalBookings;
  final int totalActiveBookings;
  final int pendingBookings;
  final int confirmedBookings;
  final int completedBookings;
  final int cancelledBookings;
  final double paidRevenue;
  final double pendingRevenue;
  final double paidCancelledAmount;
  final double refundPendingAmount;
  final double refundedAmount;
  final int baseAvailableMinutes;
  final int availableMinutes;
  final int unavailableMinutes;
  final int bookedMinutes;
  final int blockCount;
  final double utilizationRate;
  final List<CourtPerformanceStatEntity> courtStats;
  final List<PeakHourStatEntity> peakHours;
  final List<ReportCustomerStatEntity> customerStats;
  final String utilizationNote;

  const CourtPerformanceReportEntity({
    required this.dateFrom,
    required this.dateTo,
    required this.dayCount,
    required this.totalBookings,
    required this.totalActiveBookings,
    required this.pendingBookings,
    required this.confirmedBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.paidRevenue,
    required this.pendingRevenue,
    required this.paidCancelledAmount,
    required this.refundPendingAmount,
    required this.refundedAmount,
    required this.baseAvailableMinutes,
    required this.availableMinutes,
    required this.unavailableMinutes,
    required this.bookedMinutes,
    required this.blockCount,
    required this.utilizationRate,
    required this.courtStats,
    required this.peakHours,
    required this.customerStats,
    required this.utilizationNote,
  });
}

class CourtPerformanceStatEntity {
  final String courtId;
  final String courtName;
  final String status;
  final int activeBookings;
  final int confirmedBookings;
  final int completedBookings;
  final int bookedMinutes;
  final int baseAvailableMinutes;
  final int availableMinutes;
  final int unavailableMinutes;
  final int blockCount;
  final int blockedBookingCount;
  final double utilizationRate;
  final double bookingShareRate;
  final double paidRevenue;

  const CourtPerformanceStatEntity({
    required this.courtId,
    required this.courtName,
    required this.status,
    required this.activeBookings,
    required this.confirmedBookings,
    required this.completedBookings,
    required this.bookedMinutes,
    required this.baseAvailableMinutes,
    required this.availableMinutes,
    required this.unavailableMinutes,
    required this.blockCount,
    required this.blockedBookingCount,
    required this.utilizationRate,
    required this.bookingShareRate,
    required this.paidRevenue,
    this.utilizationNote = '',
  });

  final String utilizationNote;
}

class PeakHourStatEntity {
  final String label;
  final int bookingCount;

  const PeakHourStatEntity({required this.label, required this.bookingCount});
}

class ReportCustomerStatEntity {
  final String customerKey;
  final String displayName;
  final int bookingCount;
  final double paidRevenue;

  const ReportCustomerStatEntity({
    required this.customerKey,
    required this.displayName,
    required this.bookingCount,
    required this.paidRevenue,
  });
}

class AdvancedPerformanceReportEntity {
  final String dateFrom;
  final String dateTo;
  final int dayCount;
  final AdvancedReportSummaryEntity summary;
  final List<AdvancedGroupStatEntity> sportStats;
  final List<AdvancedCourtStatEntity> courtStats;
  final List<AdvancedGroupStatEntity> facilityStats;
  final List<AdvancedGroupStatEntity> dailyStats;
  final List<AdvancedGroupStatEntity> weekdayStats;
  final List<AdvancedPeakHourStatEntity> peakHours;
  final List<ReportCustomerStatEntity> customerStats;
  final String utilizationNote;

  const AdvancedPerformanceReportEntity({
    required this.dateFrom,
    required this.dateTo,
    required this.dayCount,
    required this.summary,
    required this.sportStats,
    required this.courtStats,
    required this.facilityStats,
    required this.dailyStats,
    required this.weekdayStats,
    required this.peakHours,
    required this.customerStats,
    required this.utilizationNote,
  });
}

class AdvancedReportSummaryEntity {
  final int totalBookings;
  final int activeBookings;
  final int pendingBookings;
  final int confirmedBookings;
  final int completedBookings;
  final int cancelledBookings;
  final int bookedMinutes;
  final int availableMinutes;
  final int unavailableMinutes;
  final double paidRevenue;
  final double pendingRevenue;
  final double paidCancelledAmount;
  final double refundPendingAmount;
  final double refundedAmount;
  final double utilizationRate;
  final double averagePaidRevenuePerActiveBooking;

  const AdvancedReportSummaryEntity({
    required this.totalBookings,
    required this.activeBookings,
    required this.pendingBookings,
    required this.confirmedBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.bookedMinutes,
    required this.availableMinutes,
    required this.unavailableMinutes,
    required this.paidRevenue,
    required this.pendingRevenue,
    required this.paidCancelledAmount,
    required this.refundPendingAmount,
    required this.refundedAmount,
    required this.utilizationRate,
    required this.averagePaidRevenuePerActiveBooking,
  });
}

class AdvancedGroupStatEntity {
  final String id;
  final String name;
  final String? date;
  final int? weekday;
  final int totalBookings;
  final int activeBookings;
  final int bookedMinutes;
  final int availableMinutes;
  final int unavailableMinutes;
  final int blockCount;
  final double paidRevenue;
  final double utilizationRate;

  const AdvancedGroupStatEntity({
    required this.id,
    required this.name,
    this.date,
    this.weekday,
    required this.totalBookings,
    required this.activeBookings,
    required this.bookedMinutes,
    required this.availableMinutes,
    this.unavailableMinutes = 0,
    this.blockCount = 0,
    required this.paidRevenue,
    required this.utilizationRate,
  });
}

class AdvancedCourtStatEntity extends AdvancedGroupStatEntity {
  String get courtId => id;
  String get courtName => name;

  final String facilityId;
  final String facilityName;
  final String sportId;
  final String sportName;
  final String status;
  final String utilizationNote;

  const AdvancedCourtStatEntity({
    required String courtId,
    required String courtName,
    required this.facilityId,
    required this.facilityName,
    required this.sportId,
    required this.sportName,
    required this.status,
    required super.totalBookings,
    required super.activeBookings,
    required super.bookedMinutes,
    required super.availableMinutes,
    super.unavailableMinutes,
    super.blockCount,
    required super.paidRevenue,
    required super.utilizationRate,
    this.utilizationNote = '',
  }) : super(id: courtId, name: courtName);
}

class AdvancedPeakHourStatEntity {
  final int hour;
  final String label;
  final int bookingCount;
  final int bookedMinutes;
  final double paidRevenue;

  const AdvancedPeakHourStatEntity({
    required this.hour,
    required this.label,
    required this.bookingCount,
    required this.bookedMinutes,
    required this.paidRevenue,
  });
}
