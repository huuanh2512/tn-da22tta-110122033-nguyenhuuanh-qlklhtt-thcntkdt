import { apiClient } from '../../../core/network/api_client';
import { FixedScheduleItem, FixedScheduleListResult } from './fixed_schedule_types';

const normalizeId = (value: any): string => {
  if (!value) return '';
  if (typeof value === 'string') return value;
  return value.id || value._id || '';
};

export const normalizeFixedSchedule = (raw: any): FixedScheduleItem => {
  const source = raw || {};
  const user = source.user || source.customer || source.user_id || null;
  const facility = source.facility || source.facility_id || source.court?.facility || source.court?.facility_id || null;
  const court = source.court || source.court_id || null;
  const sport = source.sport || source.sport_id || null;
  const matchingConfig = source.matchingConfig || source.matching_config || null;

  return {
    ...source,
    id: source.id || source._id || '',
    user,
    userId: source.userId || normalizeId(user),
    facility,
    facilityId: source.facilityId || normalizeId(facility),
    court,
    courtId: source.courtId || normalizeId(court),
    sport,
    sportId: source.sportId || normalizeId(sport),
    fixedScheduleCode: source.fixedScheduleCode || source.code || source.scheduleCode,
    startDate: source.startDate || source.start_date,
    endDate: source.endDate || source.end_date,
    daysOfWeek: source.daysOfWeek || source.days_of_week || (source.dayOfWeek !== undefined ? [source.dayOfWeek] : []),
    startMinutes: source.startMinutes ?? source.start_minutes,
    endMinutes: source.endMinutes ?? source.end_minutes,
    matchingConfig,
    isMatching: source.isMatching ?? (source.type === 'MATCHING' || Boolean(matchingConfig)),
    exceptionDates: source.exceptionDates || source.exception_dates || [],
    createdAt: source.createdAt || source.created_at || null,
    updatedAt: source.updatedAt || source.updated_at || null,
    approvedBy: source.approvedBy || source.approved_by || null,
    approvedAt: source.approvedAt || source.approved_at || null,
    rejectionReason: source.rejectionReason || source.rejection_reason || null,
  };
};

const extractList = (payload: any): any[] => {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.items)) return payload.items;
  if (Array.isArray(payload?.fixedSchedules)) return payload.fixedSchedules;
  if (Array.isArray(payload?.data)) return payload.data;
  if (Array.isArray(payload?.data?.items)) return payload.data.items;
  if (Array.isArray(payload?.data?.fixedSchedules)) return payload.data.fixedSchedules;
  return [];
};

const extractDetail = (payload: any): any => {
  return payload?.fixedSchedule || payload?.schedule || payload?.data?.fixedSchedule || payload?.data?.schedule || payload?.data || payload;
};

export const fixedScheduleApi = {
  // Backend/mobile endpoints: GET /fixed-schedule, PUT /fixed-schedule/:id/(approve|reject|pause|resume|cancel)
  async getFixedSchedules(params?: Record<string, any>): Promise<FixedScheduleListResult> {
    const response = await apiClient.get('/fixed-schedule', { params });
    const payload = response.data;
    const items = extractList(payload).map(normalizeFixedSchedule);
    return { items, total: payload?.total || payload?.data?.total || items.length };
  },

  async getFixedScheduleById(id: string): Promise<FixedScheduleItem | null> {
    try {
      const response = await apiClient.get(`/fixed-schedule/${id}`);
      return normalizeFixedSchedule(extractDetail(response.data));
    } catch (error: any) {
      if (error.response?.status && error.response.status !== 404) throw error;
      const result = await this.getFixedSchedules({ limit: 500 });
      return result.items.find((item) => item.id === id || item._id === id) || null;
    }
  },

  async approveFixedSchedule(id: string): Promise<FixedScheduleItem | null> {
    const response = await apiClient.put(`/fixed-schedule/${id}/approve`);
    const schedule = extractDetail(response.data);
    return schedule ? normalizeFixedSchedule(schedule) : null;
  },

  async rejectFixedSchedule(id: string, reason?: string): Promise<FixedScheduleItem | null> {
    const response = await apiClient.put(`/fixed-schedule/${id}/reject`, reason ? { reason } : {});
    const schedule = extractDetail(response.data);
    return schedule ? normalizeFixedSchedule(schedule) : null;
  },

  async pauseFixedSchedule(id: string): Promise<FixedScheduleItem | null> {
    const response = await apiClient.put(`/fixed-schedule/${id}/pause`);
    const schedule = extractDetail(response.data);
    return schedule ? normalizeFixedSchedule(schedule) : null;
  },

  async resumeFixedSchedule(id: string): Promise<FixedScheduleItem | null> {
    const response = await apiClient.put(`/fixed-schedule/${id}/resume`);
    const schedule = extractDetail(response.data);
    return schedule ? normalizeFixedSchedule(schedule) : null;
  },

  async cancelFixedSchedule(id: string): Promise<FixedScheduleItem | null> {
    const response = await apiClient.put(`/fixed-schedule/${id}/cancel`);
    const schedule = extractDetail(response.data);
    return schedule ? normalizeFixedSchedule(schedule) : null;
  },
};
