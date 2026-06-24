import { apiClient } from '../../../core/network/api_client';
import { MatchingListResult, MatchingMember, MatchingSession, MatchingTeam } from './matching_types';

const normalizeId = (value: any): string => {
  if (!value) return '';
  if (typeof value === 'string') return value;
  return value.id || value._id || '';
};

const normalizeNumber = (value: any, fallback = 0): number => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const normalizeRef = (value: any) => {
  if (!value || typeof value !== 'object') return value || null;
  return {
    ...value,
    id: value.id || value._id || '',
    name: value.name || value.profile?.fullName || value.profile?.name || '',
    iconUrl: value.iconUrl || value.icon_url || '',
  };
};

const normalizeMember = (raw: any): MatchingMember => {
  const source = raw || {};
  const user = normalizeRef(source.user || source.user_id || null);
  return {
    ...source,
    user,
    userId: source.userId || normalizeId(user),
    name: source.name || user?.name || user?.profile?.fullName || user?.profile?.name || '',
    teamCode: source.teamCode ?? source.team_code ?? null,
    representedCount: normalizeNumber(source.representedCount ?? source.represented_count, 1),
    joinMode: source.joinMode || source.join_mode || 'INDIVIDUAL',
    teamName: source.teamName || source.team_name || '',
    joinedAt: source.joinedAt || source.joined_at || null,
  };
};

const normalizeTeam = (raw: any): MatchingTeam => {
  const source = raw || {};
  return {
    ...source,
    teamCode: source.teamCode || source.team_code || '',
    maxPlayers: normalizeNumber(source.maxPlayers ?? source.max_players, 0),
    representativeUserId: source.representativeUserId || source.representative_user_id || null,
  };
};

export const normalizeMatchingSession = (raw: any): MatchingSession => {
  const source = raw || {};
  const host = normalizeRef(source.host || source.host_id || null);
  const facility = normalizeRef(source.facility || source.facility_id || source.court?.facility || source.court?.facility_id || null);
  const court = normalizeRef(source.court || source.court_id || null);
  const sport = normalizeRef(source.sport || source.sport_id || source.court?.sport || source.court?.sport_id || null);
  const fixedSchedule = source.fixedSchedule || source.fixed_schedule || source.fixed_schedule_id || null;
  const booking = source.booking || source.booking_id || null;

  return {
    ...source,
    id: source.id || source._id || source.matchingSessionId || '',
    matchingSessionId: source.matchingSessionId || source.matching_session_id || source.id || source._id || '',
    host,
    hostId: source.hostId || normalizeId(host),
    facility,
    facilityId: source.facilityId || normalizeId(facility),
    court,
    courtId: source.courtId || normalizeId(court) || null,
    sport,
    sportId: source.sportId || normalizeId(sport),
    booking: booking && typeof booking === 'object' ? booking : null,
    bookingId: source.bookingId || source.booking_id || normalizeId(booking) || null,
    fixedSchedule: fixedSchedule && typeof fixedSchedule === 'object' ? fixedSchedule : null,
    fixedScheduleId: source.fixedScheduleId || source.fixed_schedule_id || normalizeId(fixedSchedule) || null,
    isFixedSchedule: Boolean(source.isFixedSchedule ?? source.is_fixed_schedule ?? source.fixedScheduleId ?? source.fixed_schedule_id),
    bookingDate: source.bookingDate || source.booking_date || source.occurrenceDate || source.occurrence_date || '',
    occurrenceDate: source.occurrenceDate || source.occurrence_date || source.bookingDate || source.booking_date || '',
    startMinutes: normalizeNumber(source.startMinutes ?? source.start_minutes, 0),
    endMinutes: normalizeNumber(source.endMinutes ?? source.end_minutes, 0),
    totalPlayersNeeded: normalizeNumber(source.totalPlayersNeeded ?? source.total_players_needed, 0),
    approvedCount: normalizeNumber(source.approvedCount ?? source.approved_count, 0),
    availableSpots: normalizeNumber(source.availableSpots ?? source.available_spots, 0),
    autoApprove: Boolean(source.autoApprove ?? source.auto_approve ?? false),
    paymentPolicy: source.paymentPolicy || source.payment_policy || 'HOST_PAY_ALL',
    teamMode: source.teamMode || source.team_mode || 'INDIVIDUAL',
    hostTeamCode: source.hostTeamCode || source.host_team_code || 'A',
    hostRepresentedCount: normalizeNumber(source.hostRepresentedCount ?? source.host_represented_count, 1),
    teamSize: normalizeNumber(source.teamSize ?? source.team_size, 0),
    teamAOccupancy: normalizeNumber(source.teamAOccupancy ?? source.team_a_occupancy, 0),
    teamBOccupancy: normalizeNumber(source.teamBOccupancy ?? source.team_b_occupancy, 0),
    teams: Array.isArray(source.teams) ? source.teams.map(normalizeTeam) : [],
    members: Array.isArray(source.members) ? source.members.map(normalizeMember) : [],
    status: source.status || 'OPEN',
    createdAt: source.createdAt || source.created_at || null,
    updatedAt: source.updatedAt || source.updated_at || null,
  };
};

const extractList = (payload: any): any[] => {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.items)) return payload.items;
  if (Array.isArray(payload?.matchingSessions)) return payload.matchingSessions;
  if (Array.isArray(payload?.sessions)) return payload.sessions;
  if (Array.isArray(payload?.data)) return payload.data;
  if (Array.isArray(payload?.data?.items)) return payload.data.items;
  if (Array.isArray(payload?.data?.matchingSessions)) return payload.data.matchingSessions;
  if (Array.isArray(payload?.data?.sessions)) return payload.data.sessions;
  return [];
};

const extractDetail = (payload: any): any => {
  return payload?.matchingSession || payload?.session || payload?.data?.matchingSession || payload?.data?.session || payload?.data || payload;
};

export const matchingApi = {
  async getMatchingSessions(params?: Record<string, any>): Promise<MatchingListResult> {
    const response = await apiClient.get('/matching', { params });
    const payload = response.data;
    const items = extractList(payload).map(normalizeMatchingSession);
    return { items, total: payload?.total || payload?.data?.total || items.length };
  },

  async getMatchingSessionById(id: string): Promise<MatchingSession | null> {
    try {
      const response = await apiClient.get(`/matching/${id}`);
      return normalizeMatchingSession(extractDetail(response.data));
    } catch (error: any) {
      if (error.response?.status && error.response.status !== 404) throw error;
      const result = await this.getMatchingSessions({ limit: 500 });
      return result.items.find((item) => item.id === id || item._id === id || item.matchingSessionId === id) || null;
    }
  },
};
