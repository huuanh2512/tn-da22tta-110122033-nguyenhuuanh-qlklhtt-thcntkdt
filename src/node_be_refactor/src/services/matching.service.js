const mongoose = require('mongoose');
const matchingRepository = require('../repositories/matching.repository');
const matchQueueRepository = require('../repositories/match-queue.repository');
const notificationHelper = require('./notification.helper');
const socketIOService = require('./socket-io.service');
const paymentService = require('./payment.service');
const userScheduleConflictService = require('./user-schedule-conflict.service');
const paymentRepository = require('../repositories/payment.repository');
const Booking = require('../models/booking.model');
const MatchingSession = require('../models/matching.model');
const MatchQueue = require('../models/match-queue.model');
const Court = require('../models/court.model');
const Facility = require('../models/facility.model');
const Sport = require('../models/sport.model');
const {
  AUTO_CANCEL_LEAD_MINUTES,
  getBookingAutoCancelAt,
  toLocalDateString
} = require('../utils/booking-time.util');

const ACTIVE_BOOKING_STATUSES = ['PENDING', 'CONFIRMED'];
const PAYMENT_POLICIES = Object.freeze({
  HOST_PAY_ALL: 'HOST_PAY_ALL',
  SPLIT_EQUALLY: 'SPLIT_EQUALLY',
  TEAM_REPRESENTATIVES_SPLIT: 'TEAM_REPRESENTATIVES_SPLIT'
});
const TEAM_MODES = Object.freeze({
  INDIVIDUAL: 'INDIVIDUAL',
  TEAM_FILL: 'TEAM_FILL',
  TEAM_VS_TEAM: 'TEAM_VS_TEAM'
});
const TEAM_CODES = ['A', 'B'];
const OCCURRENCE_JOIN_MODES = Object.freeze({
  INDIVIDUAL: 'INDIVIDUAL',
  TEAM_REPRESENTATIVE: 'TEAM_REPRESENTATIVE'
});
const MIN_MATCH_DURATION_MINUTES = 60;
const VIETNAM_TIME_ZONE = 'Asia/Ho_Chi_Minh';

class MatchingService {
  _businessError(message, statusCode = 400, code = 'MATCHING_ERROR') {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  _isTransactionUnsupported(error) {
    const message = `${error?.message || ''} ${error?.errmsg || ''}`;
    return message.includes('Transaction numbers are only allowed')
      || message.includes('ReplicaSetNoPrimary')
      || message.includes('not a replica set member')
      || message.includes('This MongoDB deployment does not support retryable writes');
  }

  async _runWithTransactionOrFallback(operation, fallback, label) {
    const dbSession = await mongoose.startSession();
    try {
      return await dbSession.withTransaction(async () => operation({ session: dbSession }));
    } catch (error) {
      if (!this._isTransactionUnsupported(error)) throw error;
      console.warn(`[Matching Transaction Fallback] ${label}: MongoDB transaction is unavailable. Running compensating fallback. Configure MongoDB as a replica set to enable transactions. Original error: ${error.message}`);
      return await fallback();
    } finally {
      dbSession.endSession();
    }
  }

  _formatMinutes(minutes) {
    const value = Number(minutes || 0);
    const hour = Math.floor(value / 60).toString().padStart(2, '0');
    const minute = (value % 60).toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  _toInt(value, fieldName) {
    const parsed = Number(value);
    if (!Number.isInteger(parsed)) {
      throw this._businessError(`${fieldName} must be a valid integer`, 400, 'INVALID_NUMBER');
    }
    return parsed;
  }

  _assertObjectId(value, fieldName) {
    if (!mongoose.Types.ObjectId.isValid(value)) {
      throw this._businessError(`${fieldName} is invalid`, 400, 'INVALID_OBJECT_ID');
    }
  }

  _normalizePaymentPolicy(value, defaultPolicy = PAYMENT_POLICIES.HOST_PAY_ALL) {
    const policy = value || defaultPolicy;
    if (!Object.values(PAYMENT_POLICIES).includes(policy)) {
      throw this._businessError('paymentPolicy is invalid', 400, 'INVALID_PAYMENT_POLICY');
    }
    return policy;
  }

  _normalizeTeamMode(value) {
    const mode = value || TEAM_MODES.INDIVIDUAL;
    if (!Object.values(TEAM_MODES).includes(mode)) {
      throw this._businessError('teamMode is invalid', 400, 'INVALID_TEAM_MODE');
    }
    return mode;
  }

  _isTeamMode(sessionOrMode) {
    const mode = typeof sessionOrMode === 'string'
      ? sessionOrMode
      : sessionOrMode.team_mode;
    return mode === TEAM_MODES.TEAM_FILL || mode === TEAM_MODES.TEAM_VS_TEAM;
  }

  _getTeamSize(session) {
    const configuredTeam = session.teams?.find(team => TEAM_CODES.includes(team.team_code));
    return Number(configuredTeam?.max_players || 0);
  }

  _getTeamOccupancy(session, teamCode, statuses = ['APPROVED']) {
    let occupancy = session.host_team_code === teamCode
      ? Number(session.host_represented_count || 1)
      : 0;

    for (const member of session.members) {
      if (member.team_code === teamCode && statuses.includes(member.status)) {
        occupancy += Number(member.represented_count || 1);
      }
    }
    return occupancy;
  }

  _getTeamSummary(session) {
    const teamSize = this._getTeamSize(session);
    const teamAOccupancy = this._getTeamOccupancy(session, 'A');
    const teamBOccupancy = this._getTeamOccupancy(session, 'B');
    return {
      teamSize,
      teamAOccupancy,
      teamBOccupancy,
      isFull: teamSize > 0
        && teamAOccupancy === teamSize
        && teamBOccupancy === teamSize
    };
  }

  _syncSessionStatus(session) {
    if (this._isTeamMode(session)) {
      session.status = this._getTeamSummary(session).isFull ? 'FULL' : 'OPEN';
      return;
    }

    const approvedCount = session.members.filter(member => member.status === 'APPROVED').length;
    session.status = approvedCount >= session.total_players_needed ? 'FULL' : 'OPEN';
  }

  _resolvePreferredTeam(session, preferredTeam, memberCount) {
    const requestedTeam = preferredTeam || 'AUTO';
    if (!['A', 'B', 'AUTO'].includes(requestedTeam)) {
      throw this._businessError('preferredTeam is invalid', 400, 'INVALID_PREFERRED_TEAM');
    }

    const teamSize = this._getTeamSize(session);
    const occupancy = {
      A: this._getTeamOccupancy(session, 'A', ['APPROVED', 'PENDING']),
      B: this._getTeamOccupancy(session, 'B', ['APPROVED', 'PENDING'])
    };

    let teamCode = requestedTeam;
    if (requestedTeam === 'AUTO') {
      const missingA = teamSize - occupancy.A;
      const missingB = teamSize - occupancy.B;
      teamCode = missingA === missingB
        ? (TEAM_CODES.includes(session.host_team_code) ? session.host_team_code : 'A')
        : (missingA > missingB ? 'A' : 'B');
    }

    if (occupancy[teamCode] + memberCount > teamSize) {
      throw this._businessError(
        `Team ${teamCode} does not have enough available slots`,
        409,
        'TEAM_CAPACITY_EXCEEDED'
      );
    }
    return teamCode;
  }

  _getVietnamNow(date = new Date()) {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: VIETNAM_TIME_ZONE,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
      hourCycle: 'h23'
    });
    const parts = Object.fromEntries(formatter.formatToParts(date).map(part => [part.type, part.value]));
    return {
      date: `${parts.year}-${parts.month}-${parts.day}`,
      minutes: Number(parts.hour) * 60 + Number(parts.minute)
    };
  }

  _assertDateAndTime({ bookingDate, startMinutes, endMinutes }) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(bookingDate || ''))) {
      throw this._businessError('bookingDate must use YYYY-MM-DD format', 400, 'INVALID_DATE');
    }
    if (startMinutes < 0 || endMinutes > 24 * 60) {
      throw this._businessError('Time range must stay within one day', 400, 'INVALID_TIME_RANGE');
    }
    if (endMinutes <= startMinutes) {
      throw this._businessError('endMinutes must be greater than startMinutes', 400, 'INVALID_TIME_RANGE');
    }
    if (endMinutes - startMinutes < MIN_MATCH_DURATION_MINUTES) {
      throw this._businessError('Match duration must be at least 60 minutes', 400, 'INVALID_DURATION');
    }

    const now = this._getVietnamNow();
    if (bookingDate < now.date) {
      throw this._businessError('bookingDate must not be in the past', 400, 'PAST_DATE');
    }
    if (bookingDate === now.date && startMinutes < now.minutes) {
      throw this._businessError('startMinutes must not be earlier than the current time', 400, 'PAST_TIME');
    }
  }

  _calculateCommonWindow(queues) {
    const startMinutes = Math.max(...queues.map(q => q.start_minutes));
    const endMinutes = Math.min(...queues.map(q => q.end_minutes));
    return {
      startMinutes,
      endMinutes,
      isValid: endMinutes - startMinutes >= MIN_MATCH_DURATION_MINUTES
    };
  }

  _formatQueueResponse(queue, matchingSessionId = null) {
    return {
      id: queue._id.toString(),
      userId: queue.user_id?._id?.toString() || queue.user_id?.toString() || '',
      sportId: queue.sport_id?._id?.toString() || queue.sport_id?.toString() || '',
      sportName: queue.sport_id?.name || '',
      sportIconUrl: queue.sport_id?.icon_url || '',
      facilityId:
        queue.facility_id?._id?.toString()
        || queue.facility_id?.toString()
        || '',
      facilityName: queue.facility_id?.name || '',
      bookingDate: queue.booking_date,
      timeRange: `${Math.floor(queue.start_minutes / 60)}h - ${Math.floor(queue.end_minutes / 60)}h`,
      groupSize: queue.group_size,
      teamMode: queue.team_mode || TEAM_MODES.INDIVIDUAL,
      preferredTeam: queue.preferred_team || 'AUTO',
      memberCount: Number(queue.member_count || 1),
      teamSize: queue.team_size == null ? null : Number(queue.team_size),
      paymentPolicy: queue.payment_policy || PAYMENT_POLICIES.SPLIT_EQUALLY,
      status: queue.status,
      matchingSessionId:
        queue.matching_session_id?._id?.toString()
        || queue.matching_session_id?.toString()
        || matchingSessionId
    };
  }

  async _validateSportAndFacility(sportId, facilityId, options = {}) {
    this._assertObjectId(sportId, 'sportId');
    this._assertObjectId(facilityId, 'facilityId');

    const [sport, facility] = await Promise.all([
      Sport.findOne({ _id: sportId, active: true }).session(options.session || null),
      Facility.findOne({ _id: facilityId, active: true }).session(options.session || null)
    ]);

    if (!sport) {
      throw this._businessError('Sport does not exist or is inactive', 400, 'INVALID_SPORT');
    }
    if (!facility) {
      throw this._businessError('Facility does not exist or is inactive', 400, 'INVALID_FACILITY');
    }
    return { sport, facility };
  }

  async _validateCourt(courtId, sportId, facilityId, options = {}) {
    this._assertObjectId(courtId, 'courtId');

    const court = await Court.findOne({
      _id: courtId,
      sport_id: sportId,
      facility_id: facilityId,
      status: 'ACTIVE'
    }).session(options.session || null);

    if (!court) {
      throw this._businessError('Court does not exist, is inactive, or does not belong to the selected sport/facility', 400, 'INVALID_COURT');
    }
    return court;
  }

  async _findBlockingBooking(courtId, bookingDate, startMinutes, endMinutes, options = {}) {
    return await Booking.findOne({
      court_id: courtId,
      booking_date: bookingDate,
      status: { $in: ACTIVE_BOOKING_STATUSES },
      start_minutes: { $lt: endMinutes },
      end_minutes: { $gt: startMinutes }
    }).session(options.session || null);
  }

  async _syncFullSessionPayments(session, options = {}) {
    if (session.status !== 'FULL' || !session.booking_id) return;

    const bookingId = session.booking_id?._id || session.booking_id;
    const booking = await Booking.findById(bookingId).session(options.session || null);
    if (!booking || booking.status === 'CANCELLED') return;

    const hostUserId = session.host_id?._id || session.host_id;
    const memberUserIds = session.members
      .filter(member => member.status === 'APPROVED')
      .map(member => member.user_id?._id || member.user_id);
    const paymentPolicy = session.payment_policy || PAYMENT_POLICIES.HOST_PAY_ALL;

    if (paymentPolicy === PAYMENT_POLICIES.TEAM_REPRESENTATIVES_SPLIT) {
      await paymentService.syncTeamRepresentativePaymentsForSession({
        session,
        booking
      }, options);
      return;
    }

    await paymentService.createPendingPaymentsForMatching({
      booking,
      hostUserId,
      memberUserIds,
      paymentPolicy
    }, options);
  }

  _buildBookingData({ userId, court, bookingDate, startMinutes, endMinutes }) {
    const hours = (endMinutes - startMinutes) / 60;
    return {
      user_id: userId,
      court_id: court._id || court,
      booking_date: bookingDate,
      start_minutes: startMinutes,
      end_minutes: endMinutes,
      total_price: (court.price_per_hour || 0) * hours,
      status: 'PENDING'
    };
  }

  _getOccurrenceJoinSummary(session, viewerUserId = null) {
    const teamSize = this._getTeamSize(session);
    const teamA = (session.teams || []).find(team => team.team_code === 'A');
    const teamB = (session.teams || []).find(team => team.team_code === 'B');
    const activeMembers = (session.members || []).filter(
      member => ['APPROVED', 'PENDING'].includes(member.status)
    );
    const teamAMembers = activeMembers.filter(member => member.team_code === 'A');
    const teamBMembers = activeMembers.filter(member => member.team_code === 'B');
    const teamBRepresentative = teamBMembers.find(
      member => member.join_mode === OCCURRENCE_JOIN_MODES.TEAM_REPRESENTATIVE
    );
    const viewerId = viewerUserId?.toString();
    const hostId = session.host_id?._id?.toString() || session.host_id?.toString();
    const viewerMember = viewerId
      ? activeMembers.find(member =>
          (member.user_id?._id?.toString() || member.user_id?.toString()) === viewerId
        )
      : null;
    const teamBOccupancy = this._getTeamOccupancy(
      session,
      'B',
      ['APPROVED', 'PENDING']
    );

    let userJoinStatus = 'CAN_JOIN';
    if (viewerId && hostId === viewerId) {
      userJoinStatus = 'NOT_ALLOWED';
    } else if (viewerMember) {
      userJoinStatus = 'ALREADY_JOINED';
    } else if (!['OPEN'].includes(session.status)) {
      userJoinStatus = session.status === 'FULL' ? 'FULL' : 'NOT_ALLOWED';
    } else if (teamBOccupancy >= teamSize) {
      userJoinStatus = 'FULL';
    } else if (teamBRepresentative) {
      userJoinStatus = 'TEAM_REPRESENTATIVE_EXISTS';
    }

    const mapMember = member => ({
      userId: member.user_id?._id?.toString() || member.user_id?.toString() || '',
      name: member.user_id?.profile?.name || '',
      status: member.status,
      representedCount: Number(member.represented_count || 1),
      joinMode: member.join_mode || OCCURRENCE_JOIN_MODES.INDIVIDUAL,
      teamName: member.team_name || ''
    });

    const teamAResponseMembers = teamAMembers.map(mapMember);
    if (session.host_team_code === 'A') {
      teamAResponseMembers.unshift({
        userId: hostId || '',
        name: session.host_id?.profile?.name || '',
        status: 'APPROVED',
        representedCount: Number(session.host_represented_count || 1),
        joinMode: OCCURRENCE_JOIN_MODES.TEAM_REPRESENTATIVE,
        teamName: teamA?.name || 'Team A'
      });
    }

    return {
      readiness: this._getTeamSummary(session).isFull ? 'READY' : 'RECRUITING',
      userJoinStatus,
      teamA: {
        name: teamA?.name || 'Team A',
        currentCount: this._getTeamOccupancy(session, 'A', ['APPROVED', 'PENDING']),
        maxCount: teamSize,
        members: teamAResponseMembers
      },
      teamB: {
        name: teamBRepresentative?.team_name || teamB?.name || 'Team B',
        currentCount: teamBOccupancy,
        maxCount: teamSize,
        joinType: teamBRepresentative
          ? 'TEAM_REPRESENTATIVE'
          : (teamBMembers.length > 0 ? 'INDIVIDUALS' : 'EMPTY'),
        representativeName: teamBRepresentative?.user_id?.profile?.name || null,
        teamName: teamBRepresentative?.team_name || null,
        memberCount: teamBRepresentative
          ? Number(teamBRepresentative.represented_count || 1)
          : null,
        members: teamBMembers.map(mapMember)
      }
    };
  }

  _formatSessionResponse(session, viewerUserId = null) {
    const approvedCount = session.members.filter(m => m.status === 'APPROVED').length;
    const isTeamMode = this._isTeamMode(session);
    const teamSummary = isTeamMode
      ? this._getTeamSummary(session)
      : {
          teamSize: 0,
          teamAOccupancy: 0,
          teamBOccupancy: 0
        };
    const hostRepCount = Number(session.host_represented_count || 1);
    const approvedPlayerCount = isTeamMode
      ? teamSummary.teamAOccupancy + teamSummary.teamBOccupancy - hostRepCount
      : approvedCount;
    const availableSpots = isTeamMode
      ? Math.max(0, session.total_players_needed - approvedPlayerCount)
      : Math.max(0, session.total_players_needed - approvedCount);
    const fixedScheduleId =
      session.fixed_schedule_id?._id?.toString()
      || session.fixed_schedule_id?.toString()
      || null;
    let individualUserJoinStatus = 'CAN_JOIN';
    if (viewerUserId) {
      const viewerId = viewerUserId.toString();
      const hostId = session.host_id?._id?.toString() || session.host_id?.toString();
      const viewerIsMember = (session.members || []).some(member =>
        (member.user_id?._id?.toString() || member.user_id?.toString()) === viewerId
        && ['APPROVED', 'PENDING'].includes(member.status)
      );
      if (hostId === viewerId) individualUserJoinStatus = 'NOT_ALLOWED';
      else if (viewerIsMember) individualUserJoinStatus = 'ALREADY_JOINED';
      else if (session.status === 'FULL') individualUserJoinStatus = 'FULL';
      else if (session.status !== 'OPEN') individualUserJoinStatus = 'NOT_ALLOWED';
    } else if (session.status !== 'OPEN') {
      individualUserJoinStatus = session.status === 'FULL' ? 'FULL' : 'NOT_ALLOWED';
    }
    const occurrenceSummary = isTeamMode
      ? this._getOccurrenceJoinSummary(session, viewerUserId)
      : {
          readiness: session.status === 'FULL' ? 'READY' : 'RECRUITING',
          userJoinStatus: individualUserJoinStatus,
          teamA: null,
          teamB: null
        };
    return {
      id: session._id.toString(),
      matchingSessionId: session._id.toString(),
      host: session.host_id ? {
        id: session.host_id._id?.toString() || session.host_id.toString(),
        name: session.host_id.profile?.name || '',
        avatarUrl: session.host_id.profile?.avatar_url || '',
        email: session.host_id.email || ''
      } : null,
      sport: session.sport_id ? {
        id: session.sport_id._id?.toString() || session.sport_id.toString(),
        name: session.sport_id.name || '',
        iconUrl: session.sport_id.icon_url || ''
      } : null,
      facility: session.facility_id ? {
        id: session.facility_id._id?.toString() || session.facility_id.toString(),
        name: session.facility_id.name || '',
        city: session.facility_id.city || ''
      } : null,
      courtId: session.court_id?._id?.toString() || session.court_id?.toString() || null,
      bookingId: session.booking_id?._id?.toString() || session.booking_id?.toString() || null,
      fixedScheduleId,
      isFixedSchedule: Boolean(fixedScheduleId),
      bookingDate: session.booking_date,
      occurrenceDate: session.booking_date,
      startMinutes: session.start_minutes,
      endMinutes: session.end_minutes,
      startTime: this._formatMinutes(session.start_minutes),
      endTime: this._formatMinutes(session.end_minutes),
      joinMode: fixedScheduleId ? 'ONE_DAY_ONLY' : 'SESSION_ONLY',
      readiness: occurrenceSummary.readiness,
      userJoinStatus: occurrenceSummary.userJoinStatus,
      teamA: occurrenceSummary.teamA,
      teamB: occurrenceSummary.teamB,
      totalPlayersNeeded: session.total_players_needed,
      approvedCount: approvedPlayerCount,
      approvedAccountCount: approvedCount,
      availableSpots,
      description: session.description || '',
      autoApprove: session.auto_approve,
      paymentPolicy: session.payment_policy || PAYMENT_POLICIES.HOST_PAY_ALL,
      teamMode: session.team_mode || TEAM_MODES.INDIVIDUAL,
      hostTeamCode: session.host_team_code || 'A',
      hostRepresentedCount: Number(session.host_represented_count || 1),
      teamSize: teamSummary.teamSize,
      teamAOccupancy: teamSummary.teamAOccupancy,
      teamBOccupancy: teamSummary.teamBOccupancy,
      teams: (session.teams || []).map(team => ({
        teamCode: team.team_code,
        name: team.name || `Team ${team.team_code}`,
        maxPlayers: team.max_players,
        representativeUserId:
          team.representative_user_id?._id?.toString()
          || team.representative_user_id?.toString()
          || null
      })),
      status: session.status,
      members: session.members.map(m => ({
        user: {
          id: m.user_id?._id?.toString() || m.user_id.toString(),
          name: m.user_id?.profile?.name || '',
          avatarUrl: m.user_id?.profile?.avatar_url || ''
        },
        status: m.status,
        teamCode: m.team_code || null,
        representedCount: Number(m.represented_count || 1),
        joinMode: m.join_mode || OCCURRENCE_JOIN_MODES.INDIVIDUAL,
        teamName: m.team_name || '',
        note: m.note || '',
        joinedAt: m.joined_at
      })),
      createdAt: session.created_at ? new Date(session.created_at).toISOString() : null
    };
  }

  async createSession(data, hostId) {
    if (!data.courtId) {
      throw this._businessError('Court is required when creating a matching session', 400, 'MISSING_COURT');
    }

    const startMinutes = this._toInt(data.startMinutes, 'startMinutes');
    const endMinutes = this._toInt(data.endMinutes, 'endMinutes');
    const teamMode = this._normalizeTeamMode(data.teamMode);
    const isTeamMode = this._isTeamMode(teamMode);
    const teamSize = isTeamMode
      ? this._toInt(data.teamSize, 'teamSize')
      : null;
    const hostTeamCode = data.hostTeamCode || 'A';
    const hostRepresentedCount = isTeamMode
      ? this._toInt(data.hostRepresentedCount ?? 1, 'hostRepresentedCount')
      : 1;
    const totalPlayersNeeded = isTeamMode
      ? teamSize * 2 - hostRepresentedCount
      : this._toInt(data.totalPlayersNeeded, 'totalPlayersNeeded');
    const paymentPolicy = this._normalizePaymentPolicy(data.paymentPolicy);
    this._assertDateAndTime({ bookingDate: data.bookingDate, startMinutes, endMinutes });

    if (totalPlayersNeeded < 1) {
      throw this._businessError('totalPlayersNeeded must be at least 1', 400, 'INVALID_PLAYER_COUNT');
    }
    if (isTeamMode) {
      if (teamSize < 1) {
        throw this._businessError('teamSize must be at least 1', 400, 'INVALID_TEAM_SIZE');
      }
      if (!TEAM_CODES.includes(hostTeamCode)) {
        throw this._businessError('hostTeamCode is invalid', 400, 'INVALID_HOST_TEAM');
      }
      if (hostRepresentedCount < 1 || hostRepresentedCount > teamSize) {
        throw this._businessError(
          'hostRepresentedCount must be between 1 and teamSize',
          400,
          'INVALID_HOST_REPRESENTED_COUNT'
        );
      }
    } else if (paymentPolicy === PAYMENT_POLICIES.TEAM_REPRESENTATIVES_SPLIT) {
      throw this._businessError(
        'TEAM_REPRESENTATIVES_SPLIT is only supported for team matching',
        400,
        'TEAM_PAYMENT_POLICY_REQUIRES_TEAM_MODE'
      );
    }

    const createRecords = async (options = {}) => {
      const { session: dbSession = null } = options;
      const { sport } = await this._validateSportAndFacility(data.sportId, data.facilityId, { session: dbSession });
        const maxAdditionalPlayers = Number(sport.team_size || 0) * 2 - 1;
        if (
          !isTeamMode
          && maxAdditionalPlayers > 0
          && totalPlayersNeeded > maxAdditionalPlayers
        ) {
          throw this._businessError(
            `Số chân cần tuyển thêm không được vượt quá ${maxAdditionalPlayers} người cho môn này`,
            400,
            'INVALID_PLAYER_COUNT'
          );
        }
      const court = await this._validateCourt(data.courtId, data.sportId, data.facilityId, { session: dbSession });
      const duplicate = await matchingRepository.findOne({
        host_id: hostId,
        booking_date: data.bookingDate,
        start_minutes: startMinutes,
        status: { $in: ['OPEN', 'FULL'] }
      }, { session: dbSession });
      if (duplicate) {
        throw this._businessError('You already have an active matching session at this time', 409, 'DUPLICATE_MATCHING_SESSION');
      }

      await userScheduleConflictService.assertNoUserScheduleConflict(hostId, {
        bookingDate: data.bookingDate,
        startMinutes,
        endMinutes
      }, { session: dbSession });

      const blockingBooking = await this._findBlockingBooking(court._id, data.bookingDate, startMinutes, endMinutes, { session: dbSession });
      if (blockingBooking) {
        throw this._businessError('Court already has a booking overlapping this time range', 409, 'COURT_ALREADY_BOOKED');
      }

      const booking = new Booking(this._buildBookingData({
        userId: hostId,
        court,
        bookingDate: data.bookingDate,
        startMinutes,
        endMinutes
      }));
      await booking.save(dbSession ? { session: dbSession } : {});

      try {
        const createdSession = await matchingRepository.create({
          host_id: hostId,
          sport_id: data.sportId,
          facility_id: data.facilityId,
          court_id: data.courtId,
          booking_id: booking._id,
          booking_date: data.bookingDate,
          start_minutes: startMinutes,
          end_minutes: endMinutes,
          total_players_needed: totalPlayersNeeded,
          team_mode: teamMode,
          host_team_code: hostTeamCode,
          host_represented_count: hostRepresentedCount,
          teams: isTeamMode
            ? TEAM_CODES.map(teamCode => ({
                team_code: teamCode,
                name: `Team ${teamCode}`,
                max_players: teamSize,
                representative_user_id: teamCode === hostTeamCode ? hostId : null
              }))
            : [],
          description: data.description || '',
          auto_approve: data.autoApprove !== undefined ? data.autoApprove : true,
          payment_policy: paymentPolicy,
          members: [],
          status: 'OPEN'
        }, dbSession ? { session: dbSession } : {});

        if (paymentPolicy === PAYMENT_POLICIES.HOST_PAY_ALL) {
          await paymentService.createPendingPaymentsForMatching({
            booking,
            hostUserId: hostId,
            memberUserIds: [],
            paymentPolicy
          }, dbSession ? { session: dbSession } : {});
        }

        return createdSession._id;
      } catch (error) {
        if (!dbSession) {
          await Booking.findByIdAndUpdate(booking._id, {
            status: 'CANCELLED',
            cancel_reason: 'MATCHING_SESSION_CREATE_FAILED',
            cancelled_by: 'SYSTEM',
            cancelled_at: new Date()
          });
          await paymentService.cancelPendingPaymentsForBooking(booking._id);
        }
        throw error;
      }
    };

    const createdSessionId = await this._runWithTransactionOrFallback(
      createRecords,
      () => createRecords(),
      'manual createSession'
    );

    const session = await matchingRepository.findById(createdSessionId);
    return { session: this._formatSessionResponse(session) };
  }

  async querySessions(filters, skip = 0, limit = 20, viewerUserId = null) {
    const query = { status: { $in: ['OPEN', 'FULL'] } };
    if (filters.sportId) query.sport_id = filters.sportId;
    if (filters.facilityId) query.facility_id = filters.facilityId;
    if (filters.bookingDate) {
      query.booking_date = filters.bookingDate;
    } else {
      const now = new Date();
      const seventhDay = new Date(now.getTime() + 6 * 24 * 60 * 60 * 1000);
      query.booking_date = {
        $gte: toLocalDateString(now),
        $lte: toLocalDateString(seventhDay)
      };
    }

    const [rawSessions] = await Promise.all([
      matchingRepository.findMany(query, parseInt(skip), parseInt(limit)),
      matchingRepository.count(query)
    ]);

    let sessions = rawSessions.map(s => this._formatSessionResponse(s, viewerUserId));
    if (filters.neededSpots) {
      const minSpots = parseInt(filters.neededSpots);
      sessions = sessions.filter(s => s.availableSpots >= minSpots);
    }
    sessions.sort((a, b) => {
      const dateCompare = String(a.occurrenceDate || '').localeCompare(String(b.occurrenceDate || ''));
      if (dateCompare !== 0) return dateCompare;
      return (a.startMinutes || 0) - (b.startMinutes || 0);
    });

    return { items: sessions, total: sessions.length };
  }

  async getSessionDetail(id, viewerUserId = null) {
    const session = await matchingRepository.findById(id);
    if (!session) throw this._businessError('Matching session not found', 404, 'NOT_FOUND');
    return { session: this._formatSessionResponse(session, viewerUserId) };
  }

  async joinSession(id, userId, data = {}) {
    const session = await matchingRepository.findById(id);
    if (!session) throw this._businessError('Matching session not found', 404, 'NOT_FOUND');
    if (session.status === 'FULL') {
      throw this._businessError('Phòng đã đủ người, không thể đăng ký thêm.', 409, 'MATCHING_SESSION_FULL');
    }
    if (session.status !== 'OPEN') throw this._businessError('This matching session is closed', 400, 'SESSION_NOT_OPEN');
    if (session.host_id._id.toString() === userId) throw this._businessError('Host cannot join their own matching session', 400, 'HOST_CANNOT_JOIN');
    const now = this._getVietnamNow();
    if (
      session.booking_date < now.date
      || (session.booking_date === now.date && session.start_minutes <= now.minutes)
    ) {
      throw this._businessError(
        'Không thể tham gia trận đã bắt đầu',
        409,
        'MATCHING_SESSION_ALREADY_STARTED'
      );
    }

    const isMemberExist = session.members.find(m => m.user_id._id.toString() === userId);
    if (isMemberExist) {
      throw this._businessError('You already joined this matching session', 409, 'MEMBER_EXISTS');
    }

    await userScheduleConflictService.assertNoUserScheduleConflict(userId, {
      bookingDate: session.booking_date,
      startMinutes: session.start_minutes,
      endMinutes: session.end_minutes
    });

    const memberStatus = session.auto_approve ? 'APPROVED' : 'PENDING';
    if (this._isTeamMode(session)) {
      const joinMode = data.joinMode || (
        Number(data.memberCount || 1) > 1
          ? OCCURRENCE_JOIN_MODES.TEAM_REPRESENTATIVE
          : OCCURRENCE_JOIN_MODES.INDIVIDUAL
      );
      if (!Object.values(OCCURRENCE_JOIN_MODES).includes(joinMode)) {
        throw this._businessError('joinMode không hợp lệ', 400, 'INVALID_JOIN_MODE');
      }
      const teamCode = 'B';
      const teamBMembers = session.members.filter(member =>
        member.team_code === 'B'
        && ['APPROVED', 'PENDING'].includes(member.status)
      );
      const existingRepresentative = teamBMembers.find(
        member => member.join_mode === OCCURRENCE_JOIN_MODES.TEAM_REPRESENTATIVE
      );
      const individualMembers = teamBMembers.filter(
        member => member.join_mode !== OCCURRENCE_JOIN_MODES.TEAM_REPRESENTATIVE
      );
      const teamSize = this._getTeamSize(session);
      let memberCount = 1;
      let teamName = '';
      let note = '';

      if (joinMode === OCCURRENCE_JOIN_MODES.TEAM_REPRESENTATIVE) {
        if (existingRepresentative) {
          throw this._businessError(
            'Team B đã có đội tham gia',
            409,
            'TEAM_B_ALREADY_HAS_REPRESENTATIVE'
          );
        }
        if (individualMembers.length > 0) {
          throw this._businessError(
            'Team B đã có người tham gia lẻ',
            409,
            'TEAM_B_ALREADY_HAS_MEMBERS'
          );
        }
        teamName = String(
          data.teamName || (data.joinMode ? '' : 'Team B')
        ).trim();
        note = String(data.note || '').trim();
        if (!teamName) {
          throw this._businessError('Tên đội không được để trống', 400, 'TEAM_NAME_REQUIRED');
        }
        memberCount = this._toInt(data.memberCount, 'memberCount');
        if (memberCount < 1 || memberCount > teamSize) {
          throw this._businessError(
            `Số lượng thành viên phải từ 1 đến ${teamSize}`,
            400,
            'INVALID_TEAM_REPRESENTATIVE_COUNT'
          );
        }
      } else {
        if (existingRepresentative) {
          throw this._businessError(
            'Team B đã có đội tham gia',
            409,
            'TEAM_B_ALREADY_HAS_REPRESENTATIVE'
          );
        }
        if (this._getTeamOccupancy(session, teamCode, ['APPROVED', 'PENDING']) >= teamSize) {
          throw this._businessError(
            'Team B đã đủ người',
            409,
            'MATCHING_TEAM_FULL'
          );
        }
      }

      session.members.push({
        user_id: userId,
        status: memberStatus,
        team_code: teamCode,
        represented_count: memberCount,
        join_mode: joinMode,
        team_name: teamName,
        note,
        joined_at: new Date()
      });
      const team = session.teams?.find(item => item.team_code === teamCode);
      if (team && joinMode === OCCURRENCE_JOIN_MODES.TEAM_REPRESENTATIVE) {
        team.name = teamName;
        team.representative_user_id = userId;
      } else if (team && !team.representative_user_id) {
        // Keep the existing payment representative fallback for an individuals-only Team B.
        team.representative_user_id = userId;
      }
    } else {
      if (data.memberCount !== undefined && Number(data.memberCount) !== 1) {
        throw this._businessError(
          'memberCount is only supported for team matching',
          400,
          'MEMBER_COUNT_NOT_SUPPORTED'
        );
      }
      const activeMemberCount = session.members.filter(member =>
        ['APPROVED', 'PENDING'].includes(member.status)
      ).length;
      if (activeMemberCount >= session.total_players_needed) {
        throw this._businessError('Phòng đã đủ người, không thể đăng ký thêm.', 409, 'MATCHING_SESSION_FULL');
      }
      session.members.push({ user_id: userId, status: memberStatus, joined_at: new Date() });
    }

    const wasFull = session.status === 'FULL';
    this._syncSessionStatus(session);

    const updatedSession = await session.save();
    if (session.status === 'FULL') {
      await this._syncFullSessionPayments(session);
    }
    const formatted = this._formatSessionResponse(
      await matchingRepository.findById(updatedSession._id),
      userId
    );
    socketIOService.notifyMatchingUpdate(id, formatted);

    if (memberStatus === 'APPROVED') {
      await notificationHelper.notifyUser({
        userId: session.host_id._id,
        title: 'Thành viên mới tham gia trận đấu',
        content: `Một người chơi đã tham gia trận đấu của bạn tại ${session.facility_id.name}`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: id }
      });
    } else {
      await notificationHelper.notifyUser({
        userId: session.host_id._id,
        title: 'Yêu cầu xin ghép trận mới',
        content: `Có người chơi đang chờ bạn duyệt để tham gia trận đấu ngày ${session.booking_date}`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: id }
      });
    }

    if (!wasFull && formatted.status === 'FULL') {
      await this._notifyFullSession(session, id);
    }

    return { session: formatted };
  }

  async _notifyFullSession(session, id) {
    const approvedMemberIds = session.members
      .filter(m => m.status === 'APPROVED')
      .map(m => m.user_id._id.toString());

    await notificationHelper.notifyUser({
      userId: session.host_id._id,
      title: 'Ghép trận thành công',
      content: `Trận đấu ngày ${session.booking_date} tại ${session.facility_id.name} đã đủ người.`,
      type: 'SYSTEM',
      metadata: { matchingSessionId: id }
    });

    for (const guestId of approvedMemberIds) {
      await notificationHelper.notifyUser({
        userId: guestId,
        title: 'Ghép trận thành công',
        content: `Trận đấu của bạn tại ${session.facility_id.name} ngày ${session.booking_date} đã đủ người.`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: id }
      });
    }
  }

  async updateMemberStatus(id, targetUserId, status, hostId) {
    const session = await matchingRepository.findById(id);
    if (!session) throw this._businessError('Matching session not found', 404, 'NOT_FOUND');
    if (session.host_id._id.toString() !== hostId) throw this._businessError('You do not have permission to manage this session', 403, 'FORBIDDEN');

    const member = session.members.find(m => m.user_id._id.toString() === targetUserId);
    if (!member) throw this._businessError('Member not found in this matching session', 404, 'MEMBER_NOT_FOUND');

    if (status === 'APPROVED') {
      await userScheduleConflictService.assertNoUserScheduleConflict(targetUserId, {
        bookingDate: session.booking_date,
        startMinutes: session.start_minutes,
        endMinutes: session.end_minutes
      }, { excludeMatchingSessionId: session._id });
    }

    if (status === 'APPROVED' && this._isTeamMode(session)) {
      const teamCode = member.team_code;
      if (!TEAM_CODES.includes(teamCode)) {
        throw this._businessError('Member team is invalid', 400, 'INVALID_MEMBER_TEAM');
      }
      const approvedOccupancy = this._getTeamOccupancy(session, teamCode, ['APPROVED']);
      const memberCount = Number(member.represented_count || 1);
      if (member.status !== 'APPROVED' && approvedOccupancy + memberCount > this._getTeamSize(session)) {
        throw this._businessError(
          `Team ${teamCode} does not have enough available slots`,
          409,
          'TEAM_CAPACITY_EXCEEDED'
        );
      }
    }

    const wasFull = session.status === 'FULL';
    member.status = status;
    if (
      status === 'REJECTED'
      && member.join_mode === OCCURRENCE_JOIN_MODES.TEAM_REPRESENTATIVE
      && member.team_code
    ) {
      const team = session.teams?.find(item => item.team_code === member.team_code);
      if (team) {
        team.name = `Team ${member.team_code}`;
        team.representative_user_id = null;
      }
    }
    this._syncSessionStatus(session);

    const updatedSession = await session.save();
    if (session.status === 'FULL') {
      await this._syncFullSessionPayments(session);
    }
    const formatted = this._formatSessionResponse(await matchingRepository.findById(updatedSession._id));
    socketIOService.notifyMatchingUpdate(id, formatted);

    if (status === 'APPROVED') {
      await notificationHelper.notifyUser({
        userId: targetUserId,
        title: 'Yêu cầu ghép trận được phê duyệt',
        content: `Yêu cầu gia nhập trận đấu của bạn tại ${session.facility_id.name} đã được chấp nhận.`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: id }
      });
      if (!wasFull && formatted.status === 'FULL') {
        await this._notifyFullSession(session, id);
      }
    } else if (status === 'REJECTED') {
      await notificationHelper.notifyUser({
        userId: targetUserId,
        title: 'Yêu cầu ghép trận bị từ chối',
        content: `Yêu cầu tham gia trận đấu tại ${session.facility_id.name} của bạn không được phê duyệt.`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: id }
      });
    }

    return { session: formatted };
  }

  async leaveSession(id, userId) {
    const leaveMember = async (options = {}) => {
      const session = await matchingRepository.findById(id, options);
      if (!session) throw this._businessError('Matching session not found', 404, 'NOT_FOUND');
      if (!['OPEN', 'FULL'].includes(session.status)) {
        throw this._businessError('This matching session is not active', 400, 'SESSION_NOT_ACTIVE');
      }
      if (session.host_id._id.toString() === userId) {
        throw this._businessError(
          'Host must cancel the matching session instead of leaving it',
          400,
          'HOST_MUST_CANCEL_SESSION'
        );
      }

      const member = session.members.find(m => m.user_id._id.toString() === userId);
      if (!member) {
        throw this._businessError('You have not joined this matching session', 400, 'NOT_A_MEMBER');
      }

      const wasFull = session.status === 'FULL';
      const bookingId = session.booking_id?._id || session.booking_id;
      if (
        wasFull
        && bookingId
        && await paymentService.hasSuccessfulPaymentForBooking(bookingId, options)
      ) {
        throw this._businessError(
          'Trận đã có người thanh toán, bạn không thể rời riêng lẻ. Vui lòng liên hệ chủ trận hoặc quản trị viên.',
          409,
          'MATCHING_PAYMENT_ALREADY_SUCCESS'
        );
      }

      session.members = session.members.filter(
        currentMember => currentMember.user_id._id.toString() !== userId
      );
      if (this._isTeamMode(session) && member.team_code) {
        const team = session.teams?.find(item => item.team_code === member.team_code);
        const representativeId =
          team?.representative_user_id?._id?.toString()
          || team?.representative_user_id?.toString();
        if (team && representativeId === userId) {
          if (session.host_team_code === member.team_code) {
            team.representative_user_id = session.host_id._id;
          } else {
            const nextMember = session.members.find(
              currentMember => currentMember.team_code === member.team_code
            );
            team.representative_user_id =
              nextMember?.user_id?._id || nextMember?.user_id || null;
            if (member.join_mode === OCCURRENCE_JOIN_MODES.TEAM_REPRESENTATIVE) {
              team.name = `Team ${member.team_code}`;
            }
          }
        }
      }
      if (wasFull) this._syncSessionStatus(session);

      const updatedSession = await session.save(options);

      if (wasFull && bookingId) {
        await paymentService.cancelPendingPaymentForUser(bookingId, userId, options);

        if (session.payment_policy === PAYMENT_POLICIES.SPLIT_EQUALLY) {
          const booking = await Booking.findById(bookingId).session(options.session || null);
          if (booking) {
            const approvedMemberIds = session.members
              .filter(currentMember => currentMember.status === 'APPROVED')
              .map(currentMember => currentMember.user_id?._id || currentMember.user_id);

            await paymentService.syncSplitPaymentsForSession({
              booking,
              hostUserId: session.host_id._id,
              memberUserIds: approvedMemberIds
            }, options);
          }
        } else if (
          session.payment_policy === PAYMENT_POLICIES.TEAM_REPRESENTATIVES_SPLIT
          && session.status === 'OPEN'
        ) {
          await paymentService.cancelPendingPaymentsForBooking(bookingId, options);
        }
      }

      return updatedSession._id;
    };

    const updatedSessionId = await this._runWithTransactionOrFallback(
      leaveMember,
      () => leaveMember(),
      `leave session ${id}`
    );
    const formatted = this._formatSessionResponse(
      await matchingRepository.findById(updatedSessionId)
    );
    socketIOService.notifyMatchingUpdate(id, formatted);

    await notificationHelper.notifyUser({
      userId: formatted.host.id,
      title: 'Thành viên đã rời trận',
      content: 'Một thành viên vừa rời phòng ghép của bạn.',
      type: 'SYSTEM',
      metadata: { matchingSessionId: id }
    });

    return { session: formatted };
  }

  async updateSessionStatus(id, status, hostId) {
    const session = await matchingRepository.findById(id);
    if (!session) throw this._businessError('Matching session not found', 404, 'NOT_FOUND');
    if (session.host_id._id.toString() !== hostId) throw this._businessError('You do not have permission to update this session', 403, 'FORBIDDEN');
    if (status === 'CANCELLED' && session.status === 'COMPLETED') {
      throw this._businessError('Completed matching sessions cannot be cancelled', 409, 'SESSION_ALREADY_COMPLETED');
    }

    session.status = status;
    const updatedSession = await session.save();
    const formatted = this._formatSessionResponse(await matchingRepository.findById(updatedSession._id));
    socketIOService.notifyMatchingUpdate(id, formatted);

    let cancellationSummary = null;
    if (status === 'CANCELLED') {
      cancellationSummary = await this._cancelMatchingBooking(session.booking_id, {
        reason: 'MATCHING_SESSION_CANCELLED',
        cancelledBy: 'CUSTOMER'
      });

      const memberIds = session.members
        .filter(m => m.status === 'APPROVED')
        .map(m => m.user_id._id.toString());

      for (const memberId of memberIds) {
        await notificationHelper.notifyUser({
          userId: memberId,
          title: 'Kèo đấu đã bị hủy',
          content: `Host đã hủy trận đấu ngày ${session.booking_date} tại ${session.facility_id.name}.`,
          type: 'SYSTEM',
          metadata: { matchingSessionId: id }
        });
      }
    }

    return {
      session: formatted,
      cancellationSummary,
      warning: cancellationSummary?.successPayments > 0
        ? 'Có giao dịch đã thanh toán, cần xử lý hoàn tiền thủ công.'
        : null
    };
  }

  async _cancelMatchingBooking(bookingId, {
    reason,
    cancelledBy = 'SYSTEM',
    now = new Date()
  }) {
    const summary = {
      bookingCancelled: false,
      cancelledPendingPayments: 0,
      successPayments: 0
    };
    if (!bookingId) return summary;

    const payments = await paymentRepository.findManyRaw({ booking_id: bookingId });
    const pendingPaymentIds = payments
      .filter(payment => payment.status === 'PENDING')
      .map(payment => payment._id);
    summary.successPayments = payments.filter(payment => payment.status === 'SUCCESS').length;
    if (summary.successPayments > 0) {
      console.warn(
        `[Matching Cancel] Booking ${bookingId} has ${summary.successPayments} SUCCESS payment(s); refund is not automated.`
      );
    }

    if (pendingPaymentIds.length > 0) {
      const paymentResult = await paymentRepository.updateMany(
        { _id: { $in: pendingPaymentIds }, status: 'PENDING' },
        { status: 'CANCELLED' }
      );
      summary.cancelledPendingPayments =
        paymentResult.modifiedCount || paymentResult.nModified || pendingPaymentIds.length;
    }

    const cancelledBooking = await Booking.findOneAndUpdate(
      { _id: bookingId, status: 'PENDING' },
      {
        status: 'CANCELLED',
        cancel_reason: reason,
        cancelled_by: cancelledBy,
        cancelled_at: now
      },
      { new: true }
    );

    if (cancelledBooking) {
      summary.bookingCancelled = true;
      return summary;
    }

    const linkedBooking = await Booking.findById(bookingId).select('status');
    console.warn(
      `[Matching Cancel] Booking ${bookingId} was not auto-cancelled because status is ${linkedBooking?.status || 'UNKNOWN'}. Payment/refund requires manual policy handling if already confirmed or paid.`
    );
    return summary;
  }

  async _notifyMatchingFailure(session) {
    const participantIds = new Set([
      session.host_id?._id?.toString() || session.host_id?.toString(),
      ...(session.members || []).map(member =>
        member.user_id?._id?.toString() || member.user_id?.toString()
      )
    ]);
    participantIds.delete(undefined);

    for (const userId of participantIds) {
      try {
        await notificationHelper.notifyUser({
          userId,
          title: 'Ghép trận thất bại',
          content: `Trận ngày ${session.booking_date} chưa đủ người trước giờ bắt đầu 10 phút nên hệ thống đã tự động hủy.`,
          type: 'SYSTEM',
          metadata: { matchingSessionId: session._id.toString() }
        });
      } catch (error) {
        console.error(
          `[Matching Notification] Failed to notify user ${userId} about session ${session._id}:`,
          error.message
        );
      }
    }
  }

  async autoCancelUnmatched(now = new Date()) {
    const scanUntil = new Date(
      now.getTime() + AUTO_CANCEL_LEAD_MINUTES * 60 * 1000
    );
    const scanUntilDate = toLocalDateString(scanUntil);

    const [openSessions, searchingQueues] = await Promise.all([
      MatchingSession.find({
        status: 'OPEN',
        booking_date: { $lte: scanUntilDate }
      }).select('_id'),
      MatchQueue.find({
        status: 'SEARCHING',
        booking_date: { $lte: scanUntilDate }
      }).select('_id booking_date start_minutes user_id')
    ]);

    let cancelledSessionCount = 0;
    let expiredQueueCount = 0;

    for (const item of openSessions) {
      const session = await MatchingSession.findById(item._id).select(
        'booking_date start_minutes status'
      );
      if (!session) continue;
      const autoCancelAt = getBookingAutoCancelAt(session);
      if (!autoCancelAt || now < autoCancelAt) continue;

      const cancelledSession = await MatchingSession.findOneAndUpdate(
        { _id: session._id, status: 'OPEN' },
        { status: 'CANCELLED' },
        { new: true }
      )
        .populate('host_id')
        .populate('facility_id')
        .populate('members.user_id');
      if (!cancelledSession) continue;

      await this._cancelMatchingBooking(cancelledSession.booking_id, {
        reason: 'MATCHING_NOT_FULL_10_MINUTES_BEFORE_START',
        now
      });
      await this._notifyMatchingFailure(cancelledSession);
      socketIOService.notifyMatchingUpdate(
        cancelledSession._id.toString(),
        this._formatSessionResponse(cancelledSession)
      );
      cancelledSessionCount += 1;
    }

    for (const queue of searchingQueues) {
      const autoCancelAt = getBookingAutoCancelAt(queue);
      if (!autoCancelAt || now < autoCancelAt) continue;

      const expiredQueue = await MatchQueue.findOneAndUpdate(
        { _id: queue._id, status: 'SEARCHING' },
        { status: 'EXPIRED' },
        { new: true }
      );
      if (!expiredQueue) continue;

      try {
        await notificationHelper.notifyUser({
          userId: expiredQueue.user_id,
          title: 'Ghép trận thất bại',
          content: `Không tìm được đủ người cho trận ngày ${expiredQueue.booking_date} trước giờ bắt đầu 10 phút. Yêu cầu ghép trận đã được hủy.`,
          type: 'SYSTEM'
        });
      } catch (error) {
        console.error(
          `[Matching Notification] Failed to notify user ${expiredQueue.user_id} about expired queue ${expiredQueue._id}:`,
          error.message
        );
      }
      expiredQueueCount += 1;
    }

    return {
      scannedSessionCount: openSessions.length,
      cancelledSessionCount,
      scannedQueueCount: searchingQueues.length,
      expiredQueueCount
    };
  }

  async joinQueue(data, userId) {
    const startMinutes = this._toInt(data.startMinutes, 'startMinutes');
    const endMinutes = this._toInt(data.endMinutes, 'endMinutes');
    const teamMode = this._normalizeTeamMode(data.teamMode);
    const defaultPaymentPolicy = teamMode === TEAM_MODES.TEAM_VS_TEAM
      ? PAYMENT_POLICIES.TEAM_REPRESENTATIVES_SPLIT
      : PAYMENT_POLICIES.SPLIT_EQUALLY;
    const paymentPolicy = this._normalizePaymentPolicy(
      data.paymentPolicy,
      defaultPaymentPolicy
    );
    if (
      teamMode === TEAM_MODES.INDIVIDUAL
      && paymentPolicy === PAYMENT_POLICIES.TEAM_REPRESENTATIVES_SPLIT
    ) {
      throw this._businessError(
        'TEAM_REPRESENTATIVES_SPLIT requires team matching',
        400,
        'TEAM_PAYMENT_POLICY_REQUIRES_TEAM_MODE'
      );
    }
    this._assertDateAndTime({ bookingDate: data.bookingDate, startMinutes, endMinutes });

    const { sport } = await this._validateSportAndFacility(data.sportId, data.facilityId);
    let targetGroupSize;
    let preferredTeam = 'AUTO';
    let memberCount = 1;
    let teamSize = null;

    if (teamMode === TEAM_MODES.INDIVIDUAL) {
      targetGroupSize = this._toInt(data.groupSize, 'groupSize');
      const maxGroupSize = sport.team_size || targetGroupSize;
      if (targetGroupSize < 2 || targetGroupSize > maxGroupSize) {
        throw this._businessError(
          'groupSize must be at least 2 and must not exceed the sport team size',
          400,
          'INVALID_GROUP_SIZE'
        );
      }
    } else {
      preferredTeam = data.preferredTeam || 'AUTO';
      if (!['A', 'B', 'AUTO'].includes(preferredTeam)) {
        throw this._businessError(
          'preferredTeam is invalid',
          400,
          'INVALID_PREFERRED_TEAM'
        );
      }

      memberCount = this._toInt(data.memberCount ?? 1, 'memberCount');
      teamSize = this._toInt(data.teamSize ?? sport.team_size, 'teamSize');
      if (memberCount < 1 || teamSize < 1 || memberCount > teamSize) {
        throw this._businessError(
          'memberCount must be between 1 and teamSize',
          400,
          'INVALID_TEAM_QUEUE_SIZE'
        );
      }
      targetGroupSize = teamSize * 2;
    }

    const active = await matchQueueRepository.findActiveByUserId(userId);
    if (active) {
      throw this._businessError('You are already in an active matching queue. Please leave it before joining another queue.', 409, 'ACTIVE_QUEUE_EXISTS');
    }

    await userScheduleConflictService.assertNoUserScheduleConflict(userId, {
      bookingDate: data.bookingDate,
      startMinutes,
      endMinutes
    });

    const newQueue = await matchQueueRepository.create({
      user_id: userId,
      sport_id: data.sportId,
      facility_id: data.facilityId,
      booking_date: data.bookingDate,
      start_minutes: startMinutes,
      end_minutes: endMinutes,
      // For current auto matching, one queue is one player; group_size stores the target total players.
      group_size: targetGroupSize,
      team_mode: teamMode,
      preferred_team: preferredTeam,
      member_count: memberCount,
      team_size: teamSize,
      payment_policy: paymentPolicy,
      status: 'SEARCHING'
    });

    this.runMatchmakerAlgorithm(data.sportId, data.facilityId, data.bookingDate).catch(err =>
      console.error('[Matchmaker Engine Error]:', err.message)
    );

    const populatedQueue = await matchQueueRepository.findActiveByUserId(userId);
    return { queue: this._formatQueueResponse(populatedQueue || newQueue) };
  }

  async leaveQueue(userId) {
    const active = await matchQueueRepository.findActiveByUserId(userId);
    if (!active) {
      throw this._businessError('You are not in an active matching queue', 400, 'NO_ACTIVE_QUEUE');
    }

    active.status = 'CANCELLED';
    await active.save();
    return { success: true };
  }

  async getQueueStatus(userId) {
    const active = await matchQueueRepository.findCurrentByUserId(userId);
    if (!active) return { active: null };

    let matchingSessionId = null;
    if (active.status === 'MATCHED') {
      const matchingSession = await matchingRepository.findLatestForUser(userId);
      matchingSessionId = matchingSession?._id?.toString() || null;
    }

    return { active: this._formatQueueResponse(active, matchingSessionId) };
  }

  async runMatchmakerAlgorithm(sportId, facilityId, bookingDate) {
    console.log(`[Matchmaker] Scan queue: Sport=${sportId}, Facility=${facilityId}, Date=${bookingDate}`);

    const queues = await matchQueueRepository.findActiveQueues({
      sport_id: sportId,
      facility_id: facilityId,
      booking_date: bookingDate
    });

    if (queues.length < 2) {
      console.log(`[Matchmaker] No match candidates: only ${queues.length} SEARCHING queue(s).`);
      return { scannedQueues: queues.length, matched: false, reason: 'not_enough_queues' };
    }
    queues.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));

    const individualQueues = queues.filter(
      queue => (queue.team_mode || TEAM_MODES.INDIVIDUAL) === TEAM_MODES.INDIVIDUAL
    );
    for (const seed of individualQueues) {
      const targetGroupSize = seed.group_size;
      const matchedGroup = [seed];

      for (const candidate of individualQueues) {
        if (candidate._id.toString() === seed._id.toString()) continue;
        if (candidate.group_size !== targetGroupSize) continue;
        if ((candidate.payment_policy || PAYMENT_POLICIES.SPLIT_EQUALLY)
          !== (seed.payment_policy || PAYMENT_POLICIES.SPLIT_EQUALLY)) continue;
        if (matchedGroup.some(q => q.user_id._id.toString() === candidate.user_id._id.toString())) continue;

        const proposed = [...matchedGroup, candidate];
        const commonWindow = this._calculateCommonWindow(proposed);
        if (!commonWindow.isValid) continue;

        matchedGroup.push(candidate);
        if (matchedGroup.length === targetGroupSize) {
          const matchingSessionId = await this.executeSuccessfulMatch(matchedGroup, sportId, facilityId, bookingDate, commonWindow);
          return {
            scannedQueues: queues.length,
            matched: Boolean(matchingSessionId),
            matchingSessionId: matchingSessionId?.toString() || null
          };
        }
      }
    }

    const teamQueues = queues.filter(queue => this._isTeamMode(
      queue.team_mode || TEAM_MODES.INDIVIDUAL
    ));
    const teamMatch = this._findAutoTeamMatch(teamQueues);
    if (teamMatch) {
      const matchingSessionId = await this.executeSuccessfulMatch(
        teamMatch.queues,
        sportId,
        facilityId,
        bookingDate,
        teamMatch.window,
        teamMatch
      );
      return {
        scannedQueues: queues.length,
        matched: Boolean(matchingSessionId),
        matchingSessionId: matchingSessionId?.toString() || null
      };
    }

    console.log(`[Matchmaker] No compatible match found among ${queues.length} SEARCHING queue(s).`);
    return { scannedQueues: queues.length, matched: false, reason: 'no_compatible_match' };
  }

  _findAutoTeamMatch(queues) {
    for (const seed of queues) {
      const teamMode = seed.team_mode;
      const teamSize = Number(seed.team_size || 0);
      const paymentPolicy = seed.payment_policy || (
        teamMode === TEAM_MODES.TEAM_VS_TEAM
          ? PAYMENT_POLICIES.TEAM_REPRESENTATIVES_SPLIT
          : PAYMENT_POLICIES.SPLIT_EQUALLY
      );
      if (!this._isTeamMode(teamMode) || teamSize < 1) continue;

      const compatible = queues.filter(queue => (
        queue.team_mode === teamMode
        && Number(queue.team_size || 0) === teamSize
        && (queue.payment_policy || PAYMENT_POLICIES.SPLIT_EQUALLY) === paymentPolicy
      ));
      const seedIndex = compatible.findIndex(
        queue => queue._id.toString() === seed._id.toString()
      );
      if (seedIndex < 0) continue;

      const ordered = [
        compatible[seedIndex],
        ...compatible.filter((_, index) => index !== seedIndex)
      ];
      const result = this._searchAutoTeamAssignments(
        ordered,
        0,
        [],
        { A: 0, B: 0 },
        teamSize
      );
      if (!result) continue;

      const queuesById = new Map(
        compatible.map(queue => [queue._id.toString(), queue])
      );
      const matchedQueues = result.assignments.map(
        assignment => queuesById.get(assignment.queueId)
      );
      const window = this._calculateCommonWindow(matchedQueues);
      if (!window.isValid) continue;

      const assignments = result.assignments.map(assignment => ({
        ...assignment,
        queue: queuesById.get(assignment.queueId)
      }));
      const hostAssignment = assignments
        .filter(assignment => assignment.teamCode === 'A')
        .sort((left, right) =>
          new Date(left.queue.created_at) - new Date(right.queue.created_at)
        )[0];
      const hostQueueId = hostAssignment.queueId;
      const hostFirstQueues = [
        queuesById.get(hostQueueId),
        ...matchedQueues.filter(queue => queue._id.toString() !== hostQueueId)
      ];

      return {
        queues: hostFirstQueues,
        assignments,
        teamMode,
        teamSize,
        paymentPolicy,
        hostQueueId,
        window
      };
    }
    return null;
  }

  _searchAutoTeamAssignments(queues, index, assignments, occupancy, teamSize) {
    if (occupancy.A === teamSize && occupancy.B === teamSize) {
      const selectedQueues = assignments.map(assignment =>
        queues.find(queue => queue._id.toString() === assignment.queueId)
      );
      return this._calculateCommonWindow(selectedQueues).isValid
        ? { assignments, occupancy }
        : null;
    }
    if (index >= queues.length) return null;

    const queue = queues[index];
    const memberCount = Number(queue.member_count || 1);
    const requestedTeam = queue.preferred_team || 'AUTO';
    const missing = {
      A: teamSize - occupancy.A,
      B: teamSize - occupancy.B
    };
    const candidateTeams = requestedTeam === 'AUTO'
      ? [missing.A >= missing.B ? 'A' : 'B']
      : [requestedTeam];

    for (const teamCode of candidateTeams) {
      if (occupancy[teamCode] + memberCount > teamSize) continue;

      const nextAssignments = [
        ...assignments,
        {
          queueId: queue._id.toString(),
          teamCode,
          memberCount
        }
      ];
      const selectedQueues = nextAssignments.map(assignment =>
        queues.find(item => item._id.toString() === assignment.queueId)
      );
      if (!this._calculateCommonWindow(selectedQueues).isValid) continue;

      const result = this._searchAutoTeamAssignments(
        queues,
        index + 1,
        nextAssignments,
        { ...occupancy, [teamCode]: occupancy[teamCode] + memberCount },
        teamSize
      );
      if (result) return result;
    }

    return this._searchAutoTeamAssignments(
      queues,
      index + 1,
      assignments,
      occupancy,
      teamSize
    );
  }

  async _findAvailableCourt(facilityId, sportId, bookingDate, startMinutes, endMinutes, options = {}) {
    const courts = await Court.find({ facility_id: facilityId, sport_id: sportId, status: 'ACTIVE' })
      .session(options.session || null);
    if (courts.length === 0) return null;

    const bookings = await Booking.find({
      booking_date: bookingDate,
      status: { $in: ACTIVE_BOOKING_STATUSES },
      start_minutes: { $lt: endMinutes },
      end_minutes: { $gt: startMinutes }
    }).session(options.session || null);

    const bookedCourtIds = new Set(bookings.map(b => b.court_id.toString()));
    return courts.find(court => !bookedCourtIds.has(court._id.toString())) || null;
  }

  async executeSuccessfulMatch(
    matchedQueues,
    sportId,
    facilityId,
    bookingDate,
    commonWindow = null,
    teamMatch = null
  ) {
    const window = commonWindow || this._calculateCommonWindow(matchedQueues);
    if (!window.isValid) {
      console.warn('[Matchmaker] Skip match because common time window is less than 60 minutes.');
      return;
    }

    const hostQueue = matchedQueues[0];
    const guestQueues = matchedQueues.slice(1);
    const queueIds = matchedQueues.map(q => q._id);
    const claimToken = new mongoose.Types.ObjectId().toString();
    const paymentPolicy = this._normalizePaymentPolicy(
      teamMatch?.paymentPolicy || hostQueue.payment_policy,
      PAYMENT_POLICIES.SPLIT_EQUALLY
    );

    const createAutoMatchRecords = async (options = {}) => {
      const { session: dbSession = null } = options;
        const court = await this._findAvailableCourt(
          facilityId,
          sportId,
          bookingDate,
          window.startMinutes,
          window.endMinutes,
          { session: dbSession }
        );
        if (!court) {
          console.log(`[Matchmaker] No available court for ${facilityId} ${window.startMinutes}-${window.endMinutes}.`);
        return null;
        }

        const claimResult = await matchQueueRepository.updateMany(
          { _id: { $in: queueIds }, status: 'SEARCHING' },
          { status: 'MATCHED', claim_token: claimToken },
        dbSession ? { session: dbSession } : {}
        );

        if (claimResult.modifiedCount !== queueIds.length) {
          await matchQueueRepository.updateMany(
            { claim_token: claimToken },
            { status: 'SEARCHING', claim_token: null },
            dbSession ? { session: dbSession } : {}
          );
          console.warn('[Matchmaker] Queue claim failed because at least one queue was already claimed.');
        return null;
        }

      let booking = null;
      try {
        booking = new Booking(this._buildBookingData({
          userId: hostQueue.user_id._id,
          court,
          bookingDate,
          startMinutes: window.startMinutes,
          endMinutes: window.endMinutes
        }));
        await booking.save(dbSession ? { session: dbSession } : {});

        const assignmentByQueueId = new Map(
          (teamMatch?.assignments || []).map(assignment => [
            assignment.queueId,
            assignment
          ])
        );
        const hostAssignment = assignmentByQueueId.get(hostQueue._id.toString());
        const opposingTeamRepresentative = teamMatch
          ? teamMatch.assignments.find(assignment =>
              assignment.teamCode !== hostAssignment.teamCode
            )
          : null;
        const session = await matchingRepository.create({
          host_id: hostQueue.user_id._id,
          sport_id: sportId,
          facility_id: facilityId,
          court_id: court._id,
          booking_id: booking._id,
          booking_date: bookingDate,
          start_minutes: window.startMinutes,
          end_minutes: window.endMinutes,
          total_players_needed: teamMatch
            ? teamMatch.teamSize * 2 - Number(hostAssignment.memberCount || 1)
            : guestQueues.length,
          team_mode: teamMatch?.teamMode || TEAM_MODES.INDIVIDUAL,
          host_team_code: hostAssignment?.teamCode || 'A',
          host_represented_count: Number(hostAssignment?.memberCount || 1),
          teams: teamMatch ? [
            {
              team_code: 'A',
              name: 'Team A',
              max_players: teamMatch.teamSize,
              representative_user_id: hostAssignment.teamCode === 'A'
                ? hostQueue.user_id._id
                : opposingTeamRepresentative.queue.user_id._id
            },
            {
              team_code: 'B',
              name: 'Team B',
              max_players: teamMatch.teamSize,
              representative_user_id: hostAssignment.teamCode === 'B'
                ? hostQueue.user_id._id
                : opposingTeamRepresentative.queue.user_id._id
            }
          ] : [],
          description: 'Trận đấu được ghép tự động qua hệ thống Matching.',
          auto_approve: true,
          payment_policy: paymentPolicy,
          status: 'FULL',
          members: guestQueues.map(queue => {
            const assignment = assignmentByQueueId.get(queue._id.toString());
            return {
              user_id: queue.user_id._id,
              status: 'APPROVED',
              ...(assignment ? {
                team_code: assignment.teamCode,
                represented_count: assignment.memberCount
              } : {}),
              joined_at: new Date()
            };
          })
        }, dbSession ? { session: dbSession } : {});

        if (paymentPolicy === PAYMENT_POLICIES.TEAM_REPRESENTATIVES_SPLIT) {
          await paymentService.syncTeamRepresentativePaymentsForSession({
            session,
            booking
          }, dbSession ? { session: dbSession } : {});
        } else {
          await paymentService.createPendingPaymentsForMatching({
            booking,
            hostUserId: hostQueue.user_id._id,
            memberUserIds: guestQueues.map(g => g.user_id._id),
            paymentPolicy
          }, dbSession ? { session: dbSession } : {});
        }

        await matchQueueRepository.updateMany(
          { claim_token: claimToken, status: 'MATCHED' },
          { matching_session_id: session._id, claim_token: null },
          dbSession ? { session: dbSession } : {}
        );

        return session._id;
      } catch (error) {
        if (!dbSession) {
          if (booking?._id) {
            await Booking.findByIdAndUpdate(booking._id, {
              status: 'CANCELLED',
              cancel_reason: 'MATCHING_SESSION_CREATE_FAILED',
              cancelled_by: 'SYSTEM',
              cancelled_at: new Date()
            });
            await paymentService.cancelPendingPaymentsForBooking(booking._id);
          }
          await matchQueueRepository.updateMany(
            { claim_token: claimToken, status: 'MATCHED' },
            {
              status: 'SEARCHING',
              matching_session_id: null,
              claim_token: null
            }
          );
          console.error(`[Matchmaker Fallback Rollback] Failed after queue claim; queues returned to SEARCHING. Error: ${error.message}`);
        }
        throw error;
      }
    };

    const createdSessionId = await this._runWithTransactionOrFallback(
      createAutoMatchRecords,
      () => createAutoMatchRecords(),
      'auto executeSuccessfulMatch'
    );

    if (!createdSessionId) return null;

    const allUserIds = matchedQueues.map(q => q.user_id._id.toString());
    for (const userId of allUserIds) {
      await notificationHelper.notifyUser({
        userId,
        title: 'Ghép trận tự động thành công',
        content: `Hệ thống đã tìm thấy trận và giữ sân cho bạn ngày ${bookingDate} lúc ${String(Math.floor(window.startMinutes / 60)).padStart(2, '0')}:${String(window.startMinutes % 60).padStart(2, '0')}.`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: createdSessionId.toString() }
      });
    }

    console.log(`[Matchmaker] Matched session ${createdSessionId} for users: ${allUserIds.join(', ')}`);
    return createdSessionId;
  }
}

module.exports = new MatchingService();
