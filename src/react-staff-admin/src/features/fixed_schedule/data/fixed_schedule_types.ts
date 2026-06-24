export type FixedScheduleStatus =
  | 'PENDING_APPROVAL'
  | 'ACTIVE'
  | 'PAUSED'
  | 'CANCELLED'
  | 'REJECTED'
  | 'EXPIRED'
  | string;

export interface FixedSchedulePerson {
  id?: string;
  _id?: string;
  name?: string;
  email?: string;
  phone?: string;
  profile?: {
    fullName?: string;
    name?: string;
    phone?: string;
    avatar?: string;
  };
}

export interface FixedScheduleRef {
  id?: string;
  _id?: string;
  name?: string;
  code?: string;
  pricePerHour?: number;
  facility?: FixedScheduleRef;
  facility_id?: FixedScheduleRef | string;
}

export interface FixedScheduleExceptionDate {
  date?: string;
  type?: string;
  reason?: string;
}

export interface FixedScheduleItem {
  id: string;
  _id?: string;
  fixedScheduleCode?: string;
  userId?: string;
  user?: FixedSchedulePerson | null;
  customer?: FixedSchedulePerson | null;
  facilityId?: string;
  facility?: FixedScheduleRef | null;
  courtId?: string;
  court?: FixedScheduleRef | null;
  sportId?: string;
  sport?: FixedScheduleRef | null;
  type?: string;
  isMatching?: boolean;
  startDate?: string;
  endDate?: string;
  dayOfWeek?: number;
  daysOfWeek?: number[];
  startTime?: string;
  endTime?: string;
  startMinutes?: number;
  endMinutes?: number;
  frequency?: string;
  status?: FixedScheduleStatus;
  matchingConfig?: Record<string, any> | null;
  matching_config?: Record<string, any> | null;
  readiness?: string | null;
  note?: string;
  createdAt?: string | null;
  updatedAt?: string | null;
  approvedBy?: string | FixedSchedulePerson | null;
  approvedAt?: string | null;
  rejectionReason?: string | null;
  exceptionDates?: FixedScheduleExceptionDate[];
  bookingIds?: string[];
  bookings?: any[];
  cancellationSummary?: Record<string, any> | null;
  conflicts?: any[];
  [key: string]: any;
}

export interface FixedScheduleListResult {
  items: FixedScheduleItem[];
  total: number;
}
