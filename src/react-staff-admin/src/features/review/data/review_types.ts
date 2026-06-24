export type ReviewStatus = 'VISIBLE' | 'HIDDEN' | 'PENDING' | 'REPORTED' | 'DELETED' | string;

export interface ReviewRef {
  id?: string;
  _id?: string;
  name?: string;
  email?: string;
  phone?: string;
  profile?: {
    name?: string;
    fullName?: string;
    phone?: string;
    avatar?: string;
    avatarUrl?: string;
    avatar_url?: string;
  };
  facility?: ReviewRef;
  facility_id?: ReviewRef | string;
  sport?: ReviewRef;
  sport_id?: ReviewRef | string;
  [key: string]: any;
}

export interface ReviewItem {
  id: string;
  _id?: string;
  rating?: number;
  comment?: string;
  content?: string;
  status?: ReviewStatus;
  isHidden?: boolean;
  isVisible?: boolean;
  createdAt?: string | null;
  updatedAt?: string | null;
  userId?: string;
  user?: ReviewRef | null;
  customer?: ReviewRef | null;
  bookingId?: string | null;
  booking?: Record<string, any> | null;
  courtId?: string | null;
  court?: ReviewRef | null;
  facilityId?: string | null;
  facility?: ReviewRef | null;
  sportId?: string | null;
  sport?: ReviewRef | null;
  images?: string[];
  reply?: string | Record<string, any> | null;
  staffReply?: string | Record<string, any> | null;
  reportedCount?: number;
  moderationReason?: string | null;
  hiddenBy?: string | ReviewRef | null;
  hiddenAt?: string | null;
  [key: string]: any;
}

export interface ReviewListResult {
  items: ReviewItem[];
  total: number;
}
