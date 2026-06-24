import { apiClient } from '../../../core/network/api_client';
import {
  CourtPerformanceItem,
  CustomerPerformanceItem,
  DailyPerformanceItem,
  FacilityPerformanceItem,
  NormalizedPerformanceReport,
  PeakHourItem,
  ReportParams,
  ReportSummary,
  SportPerformanceItem,
} from './report_types';

const numberValue = (...values: any[]): number => {
  const value = values.find((item) => item !== undefined && item !== null && item !== '');
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const extractReport = (payload: any) => {
  return payload?.report || payload?.data?.report || payload?.data?.result || payload?.result || payload?.data || payload || {};
};

const normalizeParams = (params: ReportParams) => ({
  ...params,
  facilityIds: params.facilityIds?.length ? params.facilityIds.join(',') : undefined,
});

const normalizeSummary = (report: any): ReportSummary => {
  const summary = report?.summary || report || {};
  return {
    totalRevenue: numberValue(summary.totalRevenue, summary.paidRevenue, report.paidRevenue),
    paidRevenue: numberValue(summary.paidRevenue, report.paidRevenue),
    pendingRevenue: numberValue(summary.pendingRevenue, report.pendingRevenue),
    refundPendingAmount: numberValue(summary.refundPendingAmount, report.refundPendingAmount, summary.refundedAmount),
    paidCancelledAmount: numberValue(summary.paidCancelledAmount, report.paidCancelledAmount),
    totalBookings: numberValue(summary.totalBookings, report.totalBookings),
    activeBookings: numberValue(summary.activeBookings, report.activeBookings, report.totalActiveBookings),
    pendingBookings: numberValue(summary.pendingBookings, report.pendingBookings),
    confirmedBookings: numberValue(summary.confirmedBookings, report.confirmedBookings),
    completedBookings: numberValue(summary.completedBookings, report.completedBookings),
    cancelledBookings: numberValue(summary.cancelledBookings, report.cancelledBookings),
    bookedMinutes: numberValue(summary.bookedMinutes, report.bookedMinutes),
    availableMinutes: numberValue(summary.availableMinutes, report.availableMinutes),
    utilizationRate: numberValue(summary.utilizationRate, report.utilizationRate),
  };
};

const normalizeGroup = (item: any): CourtPerformanceItem => ({
  ...item,
  courtId: item?.courtId,
  courtName: item?.courtName || item?.name || 'Chưa có dữ liệu',
  facilityId: item?.facilityId,
  facilityName: item?.facilityName || item?.name,
  sportId: item?.sportId,
  sportName: item?.sportName || item?.name,
  bookingCount: numberValue(item?.bookingCount, item?.activeBookings, item?.totalBookings),
  activeBookings: numberValue(item?.activeBookings, item?.totalActiveBookings),
  completedBookings: numberValue(item?.completedBookings),
  cancelledBookings: numberValue(item?.cancelledBookings),
  paidRevenue: numberValue(item?.paidRevenue, item?.totalRevenue),
  pendingRevenue: numberValue(item?.pendingRevenue),
  bookedMinutes: numberValue(item?.bookedMinutes),
  availableMinutes: numberValue(item?.availableMinutes),
  utilizationRate: numberValue(item?.utilizationRate),
});

const normalizeDaily = (item: any): DailyPerformanceItem => ({
  ...item,
  date: item?.date,
  label: item?.label || item?.date,
  paidRevenue: numberValue(item?.paidRevenue, item?.totalRevenue),
  bookingCount: numberValue(item?.bookingCount, item?.activeBookings, item?.totalBookings),
  activeBookings: numberValue(item?.activeBookings),
});

const normalizePeakHour = (item: any): PeakHourItem => ({
  ...item,
  hour: item?.hour,
  label: item?.label || (item?.hour !== undefined ? `${String(item.hour).padStart(2, '0')}:00` : 'Chưa có dữ liệu'),
  bookingCount: numberValue(item?.bookingCount),
});

const normalizeCustomer = (item: any): CustomerPerformanceItem => ({
  ...item,
  key: item?.key || item?.customerKey,
  customerKey: item?.customerKey || item?.key,
  displayName: item?.displayName || item?.name || 'Khách hàng',
  customerType: item?.customerType,
  bookingCount: numberValue(item?.bookingCount, item?.bookingsCount),
  paidRevenue: numberValue(item?.paidRevenue, item?.totalSpend, item?.totalRevenue),
});

export const normalizePerformanceReport = (payload: any): NormalizedPerformanceReport => {
  const report = extractReport(payload);
  const summary = normalizeSummary(report);
  const courtStats = (report.courtStats || report.courts || []).map(normalizeGroup);
  const facilityStats = (report.facilityStats || report.facilities || []).map((item: any) => normalizeGroup(item) as FacilityPerformanceItem);
  const sportStats = (report.sportStats || report.sports || []).map((item: any) => normalizeGroup(item) as SportPerformanceItem);
  return {
    source: 'report',
    dateRange: report.dateRange,
    summary,
    courtStats,
    facilityStats,
    sportStats,
    dailyStats: (report.dailyStats || report.days || []).map(normalizeDaily),
    peakHours: (report.peakHours || []).map(normalizePeakHour),
    customerStats: (report.customerStats || report.customers || []).map(normalizeCustomer),
    utilizationNote: report.utilizationBasis?.note || report.utilizationNote,
    raw: report,
  };
};

export const reportApi = {
  async getCourtPerformanceReport(params: ReportParams): Promise<NormalizedPerformanceReport> {
    const response = await apiClient.get('/reports/court-performance', { params: normalizeParams(params) });
    return normalizePerformanceReport(response.data);
  },

  async getAdvancedPerformanceReport(params: ReportParams): Promise<NormalizedPerformanceReport> {
    const response = await apiClient.get('/reports/advanced-performance', { params: normalizeParams(params) });
    return normalizePerformanceReport(response.data);
  },
};
