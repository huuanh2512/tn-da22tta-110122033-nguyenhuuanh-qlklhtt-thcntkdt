import { apiClient } from '../../../core/network/api_client';
import { ReviewItem, ReviewListResult, ReviewRef } from './review_types';

const normalizeId = (value: any): string => {
  if (!value) return '';
  if (typeof value === 'string') return value;
  return value.id || value._id || '';
};

const normalizeNumber = (value: any, fallback = 0): number => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const normalizeRef = (value: any): ReviewRef | null => {
  if (!value || typeof value !== 'object') return value ? { id: String(value) } : null;
  return {
    ...value,
    id: value.id || value._id || '',
    name: value.name || value.profile?.fullName || value.profile?.name || '',
  };
};

const normalizeImages = (value: any): string[] => {
  if (!value) return [];
  if (Array.isArray(value)) return value.map((item) => String(item)).filter(Boolean);
  if (typeof value === 'string') return [value];
  return [];
};

const getCourtFacility = (court: any) => court?.facility || court?.facility_id || null;
const getCourtSport = (court: any) => court?.sport || court?.sport_id || null;

export const normalizeReview = (raw: any, courtMap?: Record<string, any>): ReviewItem => {
  const source = raw || {};
  const court = normalizeRef(source.court || source.court_id || null);
  const enrichedCourt = (court?.id && courtMap?.[court.id]) ? normalizeRef({ ...courtMap[court.id], ...court }) : court;
  const facility = normalizeRef(source.facility || source.facility_id || getCourtFacility(enrichedCourt) || null);
  const sport = normalizeRef(source.sport || source.sport_id || getCourtSport(enrichedCourt) || null);
  const user = normalizeRef(source.user || source.user_id || null);
  const customer = normalizeRef(source.customer || source.customer_id || user || null);
  const booking = source.booking || source.booking_id || null;
  const hiddenFlag = Boolean(source.isHidden ?? source.is_hidden ?? source.hidden ?? false);
  const visibleFlag = source.isVisible ?? source.is_visible ?? !hiddenFlag;
  const reportedCount = normalizeNumber(source.reportedCount ?? source.reported_count, 0);

  return {
    ...source,
    id: source.id || source._id || source.reviewId || source.review_id || '',
    rating: normalizeNumber(source.rating, 0),
    comment: source.comment || '',
    content: source.content || source.comment || '',
    status: source.status || (hiddenFlag ? 'HIDDEN' : (reportedCount > 0 ? 'REPORTED' : 'VISIBLE')),
    isHidden: hiddenFlag,
    isVisible: Boolean(visibleFlag),
    createdAt: source.createdAt || source.created_at || null,
    updatedAt: source.updatedAt || source.updated_at || null,
    user,
    userId: source.userId || source.user_id || normalizeId(user),
    customer,
    booking: booking && typeof booking === 'object' ? booking : null,
    bookingId: source.bookingId || source.booking_id || normalizeId(booking) || null,
    court: enrichedCourt,
    courtId: source.courtId || source.court_id || normalizeId(enrichedCourt) || null,
    facility,
    facilityId: source.facilityId || source.facility_id || normalizeId(facility) || null,
    sport,
    sportId: source.sportId || source.sport_id || normalizeId(sport) || null,
    images: normalizeImages(source.images || source.imageUrls || source.image_urls),
    reply: source.reply || null,
    staffReply: source.staffReply || source.staff_reply || null,
    reportedCount,
    moderationReason: source.moderationReason || source.moderation_reason || source.hiddenReason || source.hidden_reason || null,
    hiddenBy: source.hiddenBy || source.hidden_by || null,
    hiddenAt: source.hiddenAt || source.hidden_at || null,
  };
};

const extractList = (payload: any): any[] => {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.items)) return payload.items;
  if (Array.isArray(payload?.reviews)) return payload.reviews;
  if (Array.isArray(payload?.data)) return payload.data;
  if (Array.isArray(payload?.data?.items)) return payload.data.items;
  if (Array.isArray(payload?.data?.reviews)) return payload.data.reviews;
  return [];
};

const extractDetail = (payload: any): any => {
  return payload?.review || payload?.data?.review || payload?.data || payload;
};

const fetchCourtMap = async (): Promise<Record<string, any>> => {
  try {
    const response = await apiClient.get('/court');
    const courts = response.data?.items || response.data?.courts || response.data?.data?.items || [];
    return courts.reduce((acc: Record<string, any>, court: any) => {
      const id = court.id || court._id;
      if (id) acc[id] = court;
      return acc;
    }, {});
  } catch {
    return {};
  }
};

export const reviewApi = {
  // Backend/mobile endpoint in use: GET /review/ with optional courtId/userId/rating query.
  async getReviews(params?: Record<string, any>): Promise<ReviewListResult> {
    const [response, courtMap] = await Promise.all([
      apiClient.get('/review/', { params }),
      fetchCourtMap(),
    ]);
    const payload = response.data;
    const items = extractList(payload).map((item) => normalizeReview(item, courtMap));
    return { items, total: payload?.total || payload?.data?.total || items.length };
  },

  async getReviewById(id: string): Promise<ReviewItem | null> {
    try {
      const response = await apiClient.get(`/review/${id}`);
      return normalizeReview(extractDetail(response.data), await fetchCourtMap());
    } catch (error: any) {
      if (error.response?.status && ![404, 405].includes(error.response.status)) throw error;
      const result = await this.getReviews({ limit: 500 });
      return result.items.find((item) => item.id === id || item._id === id) || null;
    }
  },
};
