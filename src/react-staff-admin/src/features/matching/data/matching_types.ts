export type MatchingStatus = 'OPEN' | 'FULL' | 'CANCELLED' | 'COMPLETED' | string;
export type MatchingTeamMode = 'INDIVIDUAL' | 'TEAM_FILL' | 'TEAM_VS_TEAM' | string;

export interface MatchingRef {
  id?: string;
  _id?: string;
  name?: string;
  city?: string;
  email?: string;
  phone?: string;
  iconUrl?: string;
  icon_url?: string;
  profile?: {
    name?: string;
    fullName?: string;
    avatar?: string;
    avatarUrl?: string;
    avatar_url?: string;
    phone?: string;
  };
  facility?: MatchingRef;
  sport?: MatchingRef;
  [key: string]: any;
}

export interface MatchingTeam {
  teamCode?: string;
  name?: string;
  maxPlayers?: number;
  representativeUserId?: string | null;
  [key: string]: any;
}

export interface MatchingMember {
  user?: MatchingRef | null;
  userId?: string;
  name?: string;
  status?: string;
  teamCode?: string | null;
  representedCount?: number;
  joinMode?: string;
  teamName?: string;
  note?: string;
  joinedAt?: string;
  [key: string]: any;
}

export interface MatchingSession {
  id: string;
  _id?: string;
  matchingSessionId?: string;
  host?: MatchingRef | null;
  hostId?: string;
  sport?: MatchingRef | null;
  sportId?: string;
  facility?: MatchingRef | null;
  facilityId?: string;
  court?: MatchingRef | null;
  courtId?: string | null;
  booking?: Record<string, any> | null;
  bookingId?: string | null;
  fixedSchedule?: Record<string, any> | null;
  fixedScheduleId?: string | null;
  isFixedSchedule?: boolean;
  bookingDate?: string;
  occurrenceDate?: string;
  startMinutes?: number;
  endMinutes?: number;
  startTime?: string;
  endTime?: string;
  joinMode?: string;
  readiness?: string;
  userJoinStatus?: string;
  totalPlayersNeeded?: number;
  approvedCount?: number;
  availableSpots?: number;
  description?: string;
  autoApprove?: boolean;
  paymentPolicy?: string;
  teamMode?: MatchingTeamMode;
  hostTeamCode?: string;
  hostRepresentedCount?: number;
  teamSize?: number;
  teamAOccupancy?: number;
  teamBOccupancy?: number;
  teamA?: Record<string, any> | null;
  teamB?: Record<string, any> | null;
  teams?: MatchingTeam[];
  members?: MatchingMember[];
  payments?: any[];
  payment?: any;
  status?: MatchingStatus;
  createdAt?: string | null;
  updatedAt?: string | null;
  [key: string]: any;
}

export interface MatchingListResult {
  items: MatchingSession[];
  total: number;
}
