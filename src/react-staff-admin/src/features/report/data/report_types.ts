export interface ReportDateRange {
  dateFrom?: string;
  dateTo?: string;
  dayCount?: number;
}

export interface ReportParams {
  facilityId?: string;
  facilityIds?: string[];
  courtId?: string;
  sportId?: string;
  status?: string;
  include?: string;
  dateFrom: string;
  dateTo: string;
}

export interface ReportSummary {
  totalRevenue: number;
  paidRevenue: number;
  pendingRevenue: number;
  refundPendingAmount: number;
  paidCancelledAmount: number;
  totalBookings: number;
  activeBookings: number;
  pendingBookings: number;
  confirmedBookings: number;
  completedBookings: number;
  cancelledBookings: number;
  bookedMinutes: number;
  availableMinutes: number;
  utilizationRate: number;
}

export interface CourtPerformanceItem {
  courtId?: string;
  courtName?: string;
  facilityId?: string;
  facilityName?: string;
  sportId?: string;
  sportName?: string;
  status?: string;
  bookingCount: number;
  activeBookings: number;
  completedBookings: number;
  cancelledBookings: number;
  paidRevenue: number;
  pendingRevenue: number;
  bookedMinutes: number;
  availableMinutes: number;
  utilizationRate: number;
  utilizationNote?: string;
}

export interface FacilityPerformanceItem extends CourtPerformanceItem {}
export interface SportPerformanceItem extends CourtPerformanceItem {}

export interface DailyPerformanceItem {
  date?: string;
  label?: string;
  paidRevenue: number;
  bookingCount: number;
  activeBookings: number;
}

export interface PeakHourItem {
  hour?: number;
  label?: string;
  bookingCount: number;
}

export interface CustomerPerformanceItem {
  key?: string;
  customerKey?: string;
  displayName?: string;
  customerType?: string;
  bookingCount: number;
  paidRevenue: number;
}

export interface NormalizedPerformanceReport {
  source: 'report' | 'fallback';
  dateRange?: ReportDateRange;
  summary: ReportSummary;
  courtStats: CourtPerformanceItem[];
  facilityStats: FacilityPerformanceItem[];
  sportStats: SportPerformanceItem[];
  dailyStats: DailyPerformanceItem[];
  peakHours: PeakHourItem[];
  customerStats: CustomerPerformanceItem[];
  utilizationNote?: string;
  raw?: any;
}
