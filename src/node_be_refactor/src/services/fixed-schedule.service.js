const fixedScheduleRepository = require('../repositories/fixed-schedule.repository');
const paymentRepository = require('../repositories/payment.repository');
const mongoose = require('mongoose');
const FixedSchedule = require('../models/fixed-schedule.model');
const Court = require('../models/court.model');
const Booking = require('../models/booking.model');
const MatchingSession = require('../models/matching.model');
const User = require('../models/user.model');
const notificationHelper = require('./notification.helper');
const paymentService = require('./payment.service');
const courtAvailabilityService = require('./court-availability.service');
const bookingPriceService = require('./booking-price.service');
const userScheduleConflictService = require('./user-schedule-conflict.service');
const {
  BOOKING_STATUSES,
  CANCEL_REASONS,
  CANCELLED_BY,
  getDayOfWeekFromDateString,
  getBookingStartAt,
  isWithinHoursBeforeStart,
  toLocalDateString
} = require('../utils/booking-time.util');

const VALID_FIXED_SCHEDULE_TYPES = ['COURT_BOOKING', 'MATCHING'];
const VALID_FIXED_SCHEDULE_FREQUENCIES = ['DAILY', 'WEEKLY'];
const TEAM_MODES = ['INDIVIDUAL', 'TEAM_FILL', 'TEAM_VS_TEAM'];
const TEAM_CODES = ['A', 'B'];
const PAYMENT_POLICIES = ['HOST_PAY_ALL', 'SPLIT_EQUALLY', 'TEAM_REPRESENTATIVES_SPLIT'];
const MATCHING_READINESS = {
  RECRUITING: 'RECRUITING',
  READY: 'READY'
};
const FIXED_MATCHING_GENERATION_DAYS = 30;

class FixedScheduleService {
  _businessError(message, statusCode = 400, code = 'BUSINESS_RULE_VIOLATION') {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  _isValidDateString(value) {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const [year, month, day] = value.split('-').map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));
    return date.getUTCFullYear() === year &&
      date.getUTCMonth() === month - 1 &&
      date.getUTCDate() === day;
  }

  _normalizeOptionalId(value) {
    if (value === undefined || value === null || value === '') return null;
    return value.toString();
  }

  _sameObjectId(a, b) {
    return a?.toString() === b?.toString();
  }

  _isTransactionUnsupported(error) {
    const message = `${error?.message || ''} ${error?.errmsg || ''}`;
    return message.includes('Transaction numbers are only allowed')
      || message.includes('ReplicaSetNoPrimary')
      || message.includes('not a replica set member')
      || message.includes('This MongoDB deployment does not support retryable writes');
  }

  _scheduleId(schedule) {
    return schedule?._id?.toString() || schedule?.toString();
  }

  _objectIdValue(value) {
    return value?._id || value;
  }

  _fixedScheduleRecurrencePayload(schedule) {
    return {
      startDate: schedule.start_date,
      endDate: schedule.end_date || null,
      startMinutes: schedule.start_minutes,
      endMinutes: schedule.end_minutes,
      frequency: schedule.frequency,
      daysOfWeek: schedule.days_of_week || []
    };
  }

  _fixedScheduleParticipantIds(schedule) {
    const ids = new Set();
    const hostId = schedule.user_id?._id?.toString() || schedule.user_id?.toString();
    if (hostId) ids.add(hostId);

    for (const member of schedule.matching_config?.members || []) {
      const memberStatus = member.status || 'APPROVED';
      const memberId = member.user_id?._id?.toString() || member.user_id?.toString();
      if (memberId && ['INVITED', 'APPROVED'].includes(memberStatus)) {
        ids.add(memberId);
      }
    }
    return [...ids];
  }

  async _assertFixedScheduleParticipantsAvailable(schedule, options = {}) {
    const recurrence = this._fixedScheduleRecurrencePayload(schedule);
    for (const userId of this._fixedScheduleParticipantIds(schedule)) {
      await userScheduleConflictService.assertNoUserFixedScheduleConflict(
        userId,
        recurrence,
        {
          ...options,
          excludeFixedScheduleId: options.excludeFixedScheduleId || schedule._id
        }
      );
    }
  }

  _dateStringAddDays(dateStr, days) {
    const [year, month, day] = dateStr.split('-').map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));
    date.setUTCDate(date.getUTCDate() + days);
    return date.toISOString().split('T')[0];
  }

  _normalizeMatchingConfigInput(config, hostUserId) {
    if (!config || typeof config !== 'object') {
      throw this._businessError('matching_config is required for MATCHING fixed schedule', 400, 'MISSING_MATCHING_CONFIG');
    }

    const teamMode = config.team_mode || config.teamMode;
    const teamSize = Number(config.team_size ?? config.teamSize);
    const paymentPolicy = config.payment_policy || config.paymentPolicy;
    const hostTeamCode = config.host_team_code || config.hostTeamCode || 'A';
    const hostRepresentedCount = Number(config.host_represented_count ?? config.hostRepresentedCount ?? 1);

    if (!TEAM_MODES.includes(teamMode)) {
      throw this._businessError('team_mode không hợp lệ', 400, 'INVALID_TEAM_MODE');
    }
    if (!Number.isInteger(teamSize) || teamSize < 1) {
      throw this._businessError('team_size phải lớn hơn hoặc bằng 1', 400, 'INVALID_TEAM_SIZE');
    }
    if (!PAYMENT_POLICIES.includes(paymentPolicy)) {
      throw this._businessError('payment_policy không hợp lệ', 400, 'INVALID_PAYMENT_POLICY');
    }
    if (teamMode === 'INDIVIDUAL' && paymentPolicy === 'TEAM_REPRESENTATIVES_SPLIT') {
      throw this._businessError('TEAM_REPRESENTATIVES_SPLIT chỉ hỗ trợ lịch ghép theo đội', 400, 'INVALID_PAYMENT_POLICY_FOR_TEAM_MODE');
    }
    if (!TEAM_CODES.includes(hostTeamCode)) {
      throw this._businessError('host_team_code chỉ được là A hoặc B', 400, 'INVALID_HOST_TEAM_CODE');
    }
    if (!Number.isInteger(hostRepresentedCount) || hostRepresentedCount < 1 || hostRepresentedCount > teamSize) {
      throw this._businessError('host_represented_count không hợp lệ', 400, 'INVALID_HOST_REPRESENTED_COUNT');
    }

    const inputTeams = Array.isArray(config.teams) ? config.teams : [];
    const teams = TEAM_CODES.map(teamCode => {
      const existing = inputTeams.find(team => (team.team_code || team.teamCode) === teamCode);
      return {
        team_code: teamCode,
        max_players: teamSize,
        representative_user_id: teamCode === hostTeamCode
          ? hostUserId
          : this._normalizeOptionalId(existing?.representative_user_id || existing?.representativeUserId)
      };
    });

    const members = (Array.isArray(config.members) ? config.members : []).map(member => {
      const userId = member.user_id || member.userId;
      const teamCode = member.team_code || member.teamCode;
      const representedCount = Number(member.represented_count ?? member.representedCount ?? 1);
      const status = member.status || 'APPROVED';

      if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
        throw this._businessError('member user_id không hợp lệ', 400, 'INVALID_MATCHING_MEMBER');
      }
      if (!TEAM_CODES.includes(teamCode)) {
        throw this._businessError('member team_code chỉ được là A hoặc B', 400, 'INVALID_MATCHING_MEMBER');
      }
      if (!Number.isInteger(representedCount) || representedCount < 1 || representedCount > teamSize) {
        throw this._businessError('member represented_count không hợp lệ', 400, 'INVALID_MATCHING_MEMBER');
      }
      if (!['INVITED', 'APPROVED', 'LEFT'].includes(status)) {
        throw this._businessError('member status không hợp lệ', 400, 'INVALID_MATCHING_MEMBER');
      }

      return {
        user_id: userId,
        team_code: teamCode,
        represented_count: representedCount,
        status,
        joined_at: member.joined_at || member.joinedAt || new Date()
      };
    });

    const normalized = {
      team_mode: teamMode,
      team_size: teamSize,
      payment_policy: paymentPolicy,
      host_team_code: hostTeamCode,
      host_represented_count: hostRepresentedCount,
      readiness: MATCHING_READINESS.RECRUITING,
      teams,
      members
    };
    const occupancy = this._syncMatchingReadiness(normalized);
    if (occupancy.teamAOccupancy > teamSize || occupancy.teamBOccupancy > teamSize) {
      throw this._businessError('Số lượng người trong đội vượt quá team_size', 409, 'TEAM_CAPACITY_EXCEEDED');
    }
    return normalized;
  }

  calculateFixedMatchingOccupancy(matchingConfig) {
    const teamSize = Number(matchingConfig?.team_size || 0);
    const occupancy = { A: 0, B: 0 };

    if (TEAM_CODES.includes(matchingConfig?.host_team_code)) {
      occupancy[matchingConfig.host_team_code] += Number(matchingConfig.host_represented_count || 1);
    }

    for (const member of matchingConfig?.members || []) {
      if (member.status === 'APPROVED' && TEAM_CODES.includes(member.team_code)) {
        occupancy[member.team_code] += Number(member.represented_count || 1);
      }
    }

    const isReady = ['TEAM_FILL', 'TEAM_VS_TEAM'].includes(matchingConfig?.team_mode)
      && teamSize > 0
      && occupancy.A === teamSize
      && occupancy.B === teamSize;

    return {
      teamAOccupancy: occupancy.A,
      teamBOccupancy: occupancy.B,
      isReady
    };
  }

  _syncMatchingReadiness(matchingConfig) {
    const occupancy = this.calculateFixedMatchingOccupancy(matchingConfig);
    matchingConfig.readiness = occupancy.isReady
      ? MATCHING_READINESS.READY
      : MATCHING_READINESS.RECRUITING;
    return occupancy;
  }

  _formatMatchingConfigResponse(config) {
    if (!config) return null;
    const occupancy = this.calculateFixedMatchingOccupancy(config);
    const teamSize = Number(config.team_size || 0);
    const readiness = occupancy.isReady
      ? MATCHING_READINESS.READY
      : MATCHING_READINESS.RECRUITING;
    const teamAFull = teamSize > 0 && occupancy.teamAOccupancy >= teamSize;
    const teamBFull = teamSize > 0 && occupancy.teamBOccupancy >= teamSize;
    const isFull = teamAFull && teamBFull;
    const canJoin = !isFull && (!teamAFull || !teamBFull);
    return {
      teamMode: config.team_mode,
      teamSize: config.team_size,
      paymentPolicy: config.payment_policy,
      hostTeamCode: config.host_team_code,
      hostRepresentedCount: config.host_represented_count,
      readiness,
      teamAOccupancy: occupancy.teamAOccupancy,
      teamBOccupancy: occupancy.teamBOccupancy,
      teamAFull,
      teamBFull,
      canJoin,
      isJoinable: canJoin,
      teams: (config.teams || []).map(team => ({
        teamCode: team.team_code,
        maxPlayers: team.max_players,
        representativeUserId: team.representative_user_id?.toString() || null
      })),
      members: (config.members || []).map(member => ({
        userId: member.user_id?._id?.toString() || member.user_id?.toString(),
        teamCode: member.team_code,
        representedCount: member.represented_count,
        status: member.status,
        joinedAt: member.joined_at ? new Date(member.joined_at).toISOString() : null
      }))
    };
  }

  _cancelledByForRole(userRole) {
    if (userRole === CANCELLED_BY.ADMIN) return CANCELLED_BY.ADMIN;
    if (userRole === CANCELLED_BY.STAFF) return CANCELLED_BY.STAFF;
    if (userRole === CANCELLED_BY.CUSTOMER) return CANCELLED_BY.CUSTOMER;
    return CANCELLED_BY.SYSTEM;
  }

  _formatScheduleResponse(schedule) {
    const matchingConfig = this._formatMatchingConfigResponse(schedule.matching_config);
    const isMatchingJoinable = schedule.type === 'MATCHING'
      && schedule.status === 'ACTIVE'
      && Boolean(matchingConfig?.canJoin);
    return {
      id: schedule._id.toString(),
      user: schedule.user_id ? {
        id: schedule.user_id._id?.toString() || schedule.user_id.toString(),
        name: schedule.user_id.profile?.name || '',
        phone: schedule.user_id.profile?.phone || '',
        email: schedule.user_id.email || ''
      } : null,
      type: schedule.type,
      sport: schedule.sport_id ? {
        id: schedule.sport_id._id?.toString() || schedule.sport_id.toString(),
        name: schedule.sport_id.name || ''
      } : null,
      facility: schedule.facility_id ? {
        id: schedule.facility_id._id?.toString() || schedule.facility_id.toString(),
        name: schedule.facility_id.name || ''
      } : null,
      court: schedule.court_id ? {
        id: schedule.court_id._id?.toString() || schedule.court_id.toString(),
        name: schedule.court_id.name || '',
        pricePerHour: schedule.court_id.price_per_hour || 0
      } : null,
      startMinutes: schedule.start_minutes,
      endMinutes: schedule.end_minutes,
      frequency: schedule.frequency,
      daysOfWeek: schedule.days_of_week || [],
      startDate: schedule.start_date,
      endDate: schedule.end_date,
      status: schedule.status,
      exceptionDates: (schedule.exception_dates || []).map(exception => ({
        date: exception.date,
        type: exception.type,
        reason: exception.reason || ''
      })),
      pausedAt: schedule.paused_at ? new Date(schedule.paused_at).toISOString() : null,
      matchingConfig,
      readiness: schedule.matching_config?.readiness || null,
      canJoin: isMatchingJoinable,
      isJoinable: isMatchingJoinable,
      approvedBy: schedule.approved_by ? schedule.approved_by._id?.toString() || schedule.approved_by.toString() : null,
      approvedAt: schedule.approved_at ? new Date(schedule.approved_at).toISOString() : null,
      rejectedBy: schedule.rejected_by ? schedule.rejected_by._id?.toString() || schedule.rejected_by.toString() : null,
      rejectedAt: schedule.rejected_at ? new Date(schedule.rejected_at).toISOString() : null,
      rejectionReason: schedule.rejection_reason || null,
      createdAt: schedule.created_at ? new Date(schedule.created_at).toISOString() : null
    };
  }

  _formatCancellationSummary(summary) {
    return {
      cancelledBookings: summary.cancelledBookings,
      cancelledMatchingSessions: summary.cancelledMatchingSessions || 0,
      cancelledPendingPayments: summary.cancelledPendingPayments || 0,
      successPayments: summary.successPayments || 0,
      skippedBookings: summary.skippedBookings,
      skippedCompletedBookings: summary.skippedCompletedBookings,
      skippedCancelledBookings: summary.skippedCancelledBookings,
      skippedPastBookings: summary.skippedPastBookings,
      skippedNonPendingBookings: summary.skippedNonPendingBookings || 0,
      skippedConfirmedWithinTwoHours: summary.skippedConfirmedWithinTwoHours
    };
  }

  _emptyCancellationSummary() {
    return {
      cancelledBookings: 0,
      cancelledMatchingSessions: 0,
      cancelledPendingPayments: 0,
      successPayments: 0,
      skippedBookings: 0,
      skippedCompletedBookings: 0,
      skippedCancelledBookings: 0,
      skippedPastBookings: 0,
      skippedNonPendingBookings: 0,
      skippedConfirmedWithinTwoHours: 0
    };
  }

  _emptyOccurrenceCancellationSummary() {
    return {
      bookingCancelled: false,
      matchingSessionCancelled: false,
      pendingPaymentsCancelled: 0,
      successPayments: 0,
      exceptionUpserted: false,
      occurrenceExisted: false
    };
  }

  async _assertActorCanManageSchedule(schedule, actor, allowedRoles = ['STAFF', 'ADMIN']) {
    if (!actor || !allowedRoles.includes(actor.role)) {
      throw this._businessError('Bạn không có quyền thao tác lịch cố định này', 403, 'FORBIDDEN');
    }

    if (actor.role === 'ADMIN') return;

    const staff = await User.findById(actor.id).select('facility_id');
    const staffFacilityId = staff?.facility_id?.toString();
    const scheduleFacilityId = schedule.facility_id?._id?.toString() || schedule.facility_id?.toString();

    if (!staffFacilityId || !scheduleFacilityId || staffFacilityId !== scheduleFacilityId) {
      throw this._businessError('Bạn không có quyền thao tác lịch cố định ngoài cơ sở được phân công', 403, 'FORBIDDEN');
    }
  }

  async _applyActorScopeToQuery(query, actor) {
    if (!actor) return query;

    if (actor.role === 'CUSTOMER') {
      query.user_id = actor.id;
      return query;
    }

    if (actor.role === 'STAFF') {
      const staff = await User.findById(actor.id).select('facility_id');
      query.facility_id = staff?.facility_id?.toString() || '__NO_ASSIGNED_FACILITY__';
    }

    return query;
  }

  _getAdvanceGenerationRange() {
    const fromDateStr = toLocalDateString(new Date());
    return {
      fromDateStr,
      toDateStr: this._dateStringAddDays(fromDateStr, FIXED_MATCHING_GENERATION_DAYS)
    };
  }

  getAdvanceGenerationRange() {
    return this._getAdvanceGenerationRange();
  }

  getFixedMatchingGenerationDays() {
    return FIXED_MATCHING_GENERATION_DAYS;
  }

  async _assertScheduleAvailabilityForRange(
    schedule,
    fromDateStr,
    toDateStr,
    options = {}
  ) {
    const courtId = this._objectIdValue(schedule.court_id);
    const court = await courtAvailabilityService.loadCourt(
      courtId,
      options.session || null
    );
    courtAvailabilityService.assertCourtConfiguration(
      court,
      schedule.start_minutes,
      schedule.end_minutes
    );

    const effectiveFrom = schedule.start_date > fromDateStr
      ? schedule.start_date
      : fromDateStr;
    const effectiveTo = schedule.end_date && schedule.end_date < toDateStr
      ? schedule.end_date
      : toDateStr;

    for (
      let dateStr = effectiveFrom;
      dateStr <= effectiveTo;
      dateStr = this._dateStringAddDays(dateStr, 1)
    ) {
      if (!this._scheduleAppliesOnDate(schedule, dateStr)) continue;
      if (this._isScheduleExceptionDate(schedule, dateStr)) continue;
      await courtAvailabilityService.assertAvailable({
        courtId,
        bookingDate: dateStr,
        startMinutes: schedule.start_minutes,
        endMinutes: schedule.end_minutes,
        session: options.session || null,
        court
      });
    }
  }

  /**
   * Đăng ký lịch cố định mới
   */
  async createFixedSchedule(data, userId) {
    const {
      type,
      sportId,
      facilityId,
      courtId,
      startMinutes,
      endMinutes,
      frequency,
      daysOfWeek = [],
      startDate,
      endDate = null,
      matchingConfig = null
    } = data;

    const normalizedSportId = this._normalizeOptionalId(sportId);
    const normalizedFacilityId = this._normalizeOptionalId(facilityId);
    const normalizedEndDate = this._normalizeOptionalId(endDate);

    if (!type || !courtId || startMinutes === undefined || endMinutes === undefined || !frequency || !startDate) {
      throw this._businessError('Thiếu thông tin đăng ký bắt buộc', 400, 'MISSING_FIELDS');
    }

    if (!VALID_FIXED_SCHEDULE_TYPES.includes(type)) {
      throw this._businessError('Loại lịch cố định không hợp lệ', 400, 'INVALID_FIXED_SCHEDULE_TYPE');
    }

    if (!VALID_FIXED_SCHEDULE_FREQUENCIES.includes(frequency)) {
      throw this._businessError('Tần suất lịch cố định không hợp lệ', 400, 'INVALID_FIXED_SCHEDULE_FREQUENCY');
    }

    if (
      !Number.isInteger(startMinutes) ||
      !Number.isInteger(endMinutes) ||
      startMinutes < 0 ||
      endMinutes > 1440 ||
      startMinutes >= endMinutes
    ) {
      throw this._businessError('Khung giờ lịch cố định không hợp lệ', 400, 'INVALID_FIXED_SCHEDULE_TIME');
    }

    if (!this._isValidDateString(startDate) || (normalizedEndDate && !this._isValidDateString(normalizedEndDate))) {
      throw this._businessError('Ngày hiệu lực lịch cố định không hợp lệ', 400, 'INVALID_FIXED_SCHEDULE_DATE');
    }

    if (normalizedEndDate && startDate > normalizedEndDate) {
      throw this._businessError('Ngày bắt đầu không được sau ngày kết thúc', 400, 'INVALID_FIXED_SCHEDULE_DATE_RANGE');
    }

    const todayStr = toLocalDateString(new Date());
    if (todayStr && startDate < todayStr) {
      throw this._businessError('Ngày bắt đầu không được nằm trong quá khứ', 400, 'FIXED_SCHEDULE_START_DATE_IN_PAST');
    }

    if (frequency === 'WEEKLY' && (!daysOfWeek || daysOfWeek.length === 0)) {
      throw this._businessError('Lịch hàng tuần yêu cầu chỉ định thứ trong tuần (daysOfWeek)', 400, 'MISSING_DAYS_OF_WEEK');
    }

    if (
      !Array.isArray(daysOfWeek) ||
      daysOfWeek.some(day => !Number.isInteger(day) || day < 0 || day > 6)
    ) {
      throw this._businessError('daysOfWeek chỉ được chứa số từ 0 đến 6', 400, 'INVALID_DAYS_OF_WEEK');
    }

    const court = await courtAvailabilityService.loadCourt(courtId);
    const initialAvailabilityEnd = normalizedEndDate
      && normalizedEndDate < this._dateStringAddDays(startDate, 7)
      ? normalizedEndDate
      : this._dateStringAddDays(startDate, 7);
    await this._assertScheduleAvailabilityForRange({
      court_id: courtId,
      start_minutes: startMinutes,
      end_minutes: endMinutes,
      frequency,
      days_of_week: daysOfWeek,
      start_date: startDate,
      end_date: normalizedEndDate,
      exception_dates: []
    }, startDate, initialAvailabilityEnd);

    if (normalizedSportId && !this._sameObjectId(normalizedSportId, court.sport_id)) {
      throw this._businessError('Môn thể thao không khớp với sân đã chọn', 400, 'SPORT_MISMATCH');
    }

    if (normalizedFacilityId && !this._sameObjectId(normalizedFacilityId, court.facility_id)) {
      throw this._businessError('Cơ sở không khớp với sân đã chọn', 400, 'FACILITY_MISMATCH');
    }

    // 2. Kiểm tra trùng lặp với các Đăng ký lịch cố định khác đang có hiệu lực
    const scheduleOverlap = await this.checkScheduleConflict(
      courtId,
      startMinutes,
      endMinutes,
      frequency,
      daysOfWeek,
      startDate,
      normalizedEndDate
    );

    if (scheduleOverlap) {
      throw this._businessError(
        `Khung giờ này đã bị đăng ký lịch cố định bởi một người dùng khác (Lịch ID: ${scheduleOverlap._id})`,
        409,
        'FIXED_SCHEDULE_CONFLICT'
      );
    }

    // 3. Kiểm tra trùng lặp với các Booking đơn lẻ đã có sẵn trong tương lai
    const bookingOverlap = await this.checkBookingConflictForNewSchedule(
      courtId,
      startMinutes,
      endMinutes,
      frequency,
      daysOfWeek,
      startDate,
      normalizedEndDate
    );

    if (bookingOverlap) {
      throw this._businessError(
        `Không thể đăng ký do trùng với lịch đặt sân đơn lẻ đã có vào ngày ${bookingOverlap.booking_date}`,
        409,
        'BOOKING_CONFLICT'
      );
    }

    const normalizedMatchingConfig = type === 'MATCHING'
      ? this._normalizeMatchingConfigInput(matchingConfig, userId)
      : null;

    await this._assertFixedScheduleParticipantsAvailable({
      user_id: userId,
      start_minutes: startMinutes,
      end_minutes: endMinutes,
      frequency,
      days_of_week: daysOfWeek,
      start_date: startDate,
      end_date: normalizedEndDate,
      matching_config: normalizedMatchingConfig
    });

    // 4. Tạo bản ghi
    const scheduleData = {
      user_id: userId,
      type,
      sport_id: normalizedSportId || court.sport_id,
      facility_id: normalizedFacilityId || court.facility_id,
      court_id: courtId,
      start_minutes: startMinutes,
      end_minutes: endMinutes,
      frequency,
      days_of_week: daysOfWeek,
      start_date: startDate,
      end_date: normalizedEndDate,
      status: 'PENDING_APPROVAL',
      matching_config: normalizedMatchingConfig
    };

    let newSchedule = await fixedScheduleRepository.create(scheduleData);
    newSchedule = await fixedScheduleRepository.findById(newSchedule._id);

    try {
      const facilityIdForNotification = newSchedule.facility_id?._id?.toString()
        || newSchedule.facility_id?.toString();
      const customerName = newSchedule.user_id?.profile?.name || 'Khách hàng';
      const courtName = newSchedule.court_id?.name || 'sân';
      const timeLabel = `${Math.floor(startMinutes / 60).toString().padStart(2, '0')}:${(startMinutes % 60).toString().padStart(2, '0')} - ${Math.floor(endMinutes / 60).toString().padStart(2, '0')}:${(endMinutes % 60).toString().padStart(2, '0')}`;
      const notificationPayload = {
        title: 'Có lịch cố định chờ duyệt',
        content: `${customerName} vừa đăng ký lịch cố định tại ${courtName} (${timeLabel}). Vui lòng kiểm tra và duyệt lịch.`,
        type: 'SYSTEM',
        metadata: {
          fixedScheduleId: newSchedule._id.toString(),
          facilityId: facilityIdForNotification
        }
      };

      await Promise.all([
        notificationHelper.notifyFacilityStaff({
          facilityId: facilityIdForNotification,
          ...notificationPayload
        }),
        notificationHelper.notifyAdmin(notificationPayload)
      ]);
    } catch (err) {
      console.error('Error notifying staff/admin for pending fixed schedule:', err.message);
    }

    return { schedule: this._formatScheduleResponse(newSchedule) };
  }

  /**
   * Truy vấn danh sách lịch cố định
   */
  async queryFixedSchedules(filters, skip = 0, limit = 20, actor = null) {
    const query = {};
    if (filters.userId) query.user_id = filters.userId;
    if (filters.courtId) query.court_id = filters.courtId;
    if (filters.status) query.status = filters.status;
    if (filters.type) query.type = filters.type;
    await this._applyActorScopeToQuery(query, actor);

    const [schedules, total] = await Promise.all([
      fixedScheduleRepository.findMany(query, parseInt(skip), parseInt(limit)),
      fixedScheduleRepository.count(query)
    ]);

    return {
      items: schedules.map(s => this._formatScheduleResponse(s)),
      total
    };
  }

  _assertMatchingTemplateJoinable(schedule) {
    if (!schedule) {
      throw this._businessError('Không tìm thấy lịch cố định', 404, 'FIXED_SCHEDULE_NOT_FOUND');
    }
    if (schedule.type !== 'MATCHING' || !schedule.matching_config) {
      throw this._businessError('Lịch cố định này không phải template ghép trận', 400, 'NOT_FIXED_MATCHING_SCHEDULE');
    }
    if (schedule.status !== 'ACTIVE') {
      throw this._businessError('Chỉ có thể tham gia lịch ghép cố định đang ACTIVE', 400, 'FIXED_MATCHING_NOT_JOINABLE');
    }
  }

  _resolveFixedMatchingTeam(matchingConfig, preferredTeam, memberCount) {
    const requestedTeam = preferredTeam || 'AUTO';
    if (!['A', 'B', 'AUTO'].includes(requestedTeam)) {
      throw this._businessError('preferredTeam không hợp lệ', 400, 'INVALID_PREFERRED_TEAM');
    }

    const teamSize = Number(matchingConfig.team_size || 0);
    const occupancy = this.calculateFixedMatchingOccupancy(matchingConfig);
    const current = {
      A: occupancy.teamAOccupancy,
      B: occupancy.teamBOccupancy
    };

    let teamCode = requestedTeam;
    if (requestedTeam === 'AUTO') {
      const missingA = teamSize - current.A;
      const missingB = teamSize - current.B;
      teamCode = missingA >= missingB ? 'A' : 'B';
    }

    if (current[teamCode] + memberCount > teamSize) {
      throw this._businessError(
        `Team ${teamCode} đã đủ chỗ.`,
        409,
        'TEAM_CAPACITY_FULL'
      );
    }

    return teamCode;
  }

  async joinFixedMatchingSchedule(id, actor, body = {}) {
    const schedule = await fixedScheduleRepository.findById(id);
    this._assertMatchingTemplateJoinable(schedule);

    const actorId = actor?.id?.toString();
    if (!actorId) {
      throw this._businessError('Bạn cần đăng nhập để tham gia lịch ghép cố định', 401, 'UNAUTHORIZED');
    }
    if (this._sameObjectId(schedule.user_id?._id || schedule.user_id, actorId)) {
      throw this._businessError('Chủ lịch đã được tính trong template ghép trận', 400, 'HOST_ALREADY_INCLUDED');
    }

    const memberCount = Number(body.memberCount ?? body.member_count ?? 1);
    if (!Number.isInteger(memberCount) || memberCount < 1) {
      throw this._businessError('memberCount phải lớn hơn hoặc bằng 1', 400, 'INVALID_MEMBER_COUNT');
    }

    const matchingConfig = schedule.matching_config.toObject
      ? schedule.matching_config.toObject()
      : schedule.matching_config;
    const previousReadiness = matchingConfig.readiness || MATCHING_READINESS.RECRUITING;
    const activeMember = (matchingConfig.members || []).find(member =>
      this._sameObjectId(member.user_id, actorId) && member.status !== 'LEFT'
    );
    if (activeMember) {
      throw this._businessError('Bạn đã tham gia lịch ghép cố định này', 409, 'FIXED_MATCHING_MEMBER_EXISTS');
    }

    const occupancy = this.calculateFixedMatchingOccupancy(matchingConfig);
    const teamSize = Number(matchingConfig.team_size || 0);
    const isFull = teamSize > 0
      && occupancy.teamAOccupancy >= teamSize
      && occupancy.teamBOccupancy >= teamSize;
    if (isFull) {
      throw this._businessError(
        'Lịch ghép này đã đủ đội, không thể đăng ký thêm.',
        409,
        'FIXED_MATCHING_FULL'
      );
    }

    await userScheduleConflictService.assertNoUserFixedScheduleConflict(
      actorId,
      this._fixedScheduleRecurrencePayload(schedule)
    );

    const teamCode = this._resolveFixedMatchingTeam(matchingConfig, body.preferredTeam || body.preferred_team, memberCount);
    matchingConfig.members = matchingConfig.members || [];
    matchingConfig.members.push({
      user_id: actorId,
      team_code: teamCode,
      represented_count: memberCount,
      status: 'APPROVED',
      joined_at: new Date()
    });

    const team = (matchingConfig.teams || []).find(item => item.team_code === teamCode);
    if (team && !team.representative_user_id) {
      team.representative_user_id = actorId;
    }

    this._syncMatchingReadiness(matchingConfig);
    const updated = await fixedScheduleRepository.updateById(id, { matching_config: matchingConfig });
    if (
      previousReadiness !== MATCHING_READINESS.READY
      && matchingConfig.readiness === MATCHING_READINESS.READY
    ) {
      const { fromDateStr, toDateStr } = this._getAdvanceGenerationRange();
      await this.generateBookingsForRange(updated, fromDateStr, toDateStr);
    }
    return { schedule: this._formatScheduleResponse(updated) };
  }

  async leaveFixedMatchingSchedule(id, actor) {
    const schedule = await fixedScheduleRepository.findById(id);
    this._assertMatchingTemplateJoinable(schedule);

    const actorId = actor?.id?.toString();
    if (this._sameObjectId(schedule.user_id?._id || schedule.user_id, actorId)) {
      throw this._businessError('Chủ lịch không thể rời bằng endpoint member; hãy pause hoặc hủy chuỗi', 400, 'HOST_MUST_PAUSE_OR_CANCEL_FIXED_SCHEDULE');
    }

    const matchingConfig = schedule.matching_config.toObject
      ? schedule.matching_config.toObject()
      : schedule.matching_config;
    const member = (matchingConfig.members || []).find(item =>
      this._sameObjectId(item.user_id, actorId) && item.status !== 'LEFT'
    );
    if (!member) {
      throw this._businessError('Bạn chưa tham gia lịch ghép cố định này', 404, 'FIXED_MATCHING_MEMBER_NOT_FOUND');
    }

    const previousReadiness = matchingConfig.readiness || MATCHING_READINESS.RECRUITING;
    member.status = 'LEFT';
    const team = (matchingConfig.teams || []).find(item =>
      item.team_code === member.team_code
      && this._sameObjectId(item.representative_user_id, actorId)
    );
    if (team) {
      team.representative_user_id = null;
    }
    this._syncMatchingReadiness(matchingConfig);

    const updated = await fixedScheduleRepository.updateById(id, { matching_config: matchingConfig });
    let cancellationSummary = this._emptyCancellationSummary();
    if (
      previousReadiness === MATCHING_READINESS.READY
      && matchingConfig.readiness === MATCHING_READINESS.RECRUITING
    ) {
      cancellationSummary = await this._cancelPendingFutureMatchingOccurrencesForReadinessRollback(
        updated,
        actor?.role || CANCELLED_BY.SYSTEM
      );
    }

    return {
      schedule: this._formatScheduleResponse(updated),
      cancellationSummary: this._formatCancellationSummary(cancellationSummary),
      readinessChanged:
        previousReadiness !== (matchingConfig.readiness || MATCHING_READINESS.RECRUITING)
    };
  }

  async pauseFixedSchedule(id, actor) {
    const schedule = await fixedScheduleRepository.findById(id);
    if (!schedule) {
      throw this._businessError('Không tìm thấy lịch cố định', 404, 'FIXED_SCHEDULE_NOT_FOUND');
    }
    if (!actor || !['CUSTOMER', 'STAFF', 'ADMIN'].includes(actor.role)) {
      throw this._businessError('Bạn không có quyền pause lịch cố định này', 403, 'FORBIDDEN');
    }
    if (actor.role === 'CUSTOMER' && schedule.user_id._id.toString() !== actor.id) {
      throw this._businessError('Bạn không có quyền pause lịch cố định này', 403, 'FORBIDDEN');
    }
    if (actor.role === 'STAFF' || actor.role === 'ADMIN') {
      await this._assertActorCanManageSchedule(schedule, actor);
    }
    if (schedule.status !== 'ACTIVE') {
      throw this._businessError('Chỉ có thể pause lịch cố định đang ACTIVE', 400, 'INVALID_FIXED_SCHEDULE_STATUS');
    }

    const updated = await fixedScheduleRepository.updateById(id, {
      status: 'PAUSED',
      paused_at: new Date()
    });
    return { schedule: this._formatScheduleResponse(updated) };
  }

  async resumeFixedSchedule(id, actor) {
    const schedule = await fixedScheduleRepository.findById(id);
    if (!schedule) {
      throw this._businessError('Không tìm thấy lịch cố định', 404, 'FIXED_SCHEDULE_NOT_FOUND');
    }
    if (!actor || !['CUSTOMER', 'STAFF', 'ADMIN'].includes(actor.role)) {
      throw this._businessError('Bạn không có quyền resume lịch cố định này', 403, 'FORBIDDEN');
    }
    if (actor.role === 'CUSTOMER' && schedule.user_id._id.toString() !== actor.id) {
      throw this._businessError('Bạn không có quyền resume lịch cố định này', 403, 'FORBIDDEN');
    }
    if (actor.role === 'STAFF' || actor.role === 'ADMIN') {
      await this._assertActorCanManageSchedule(schedule, actor);
    }
    if (schedule.status === 'CANCELLED') {
      throw this._businessError('Không thể resume lịch cố định đã hủy', 400, 'FIXED_SCHEDULE_CANCELLED');
    }
    if (schedule.status !== 'PAUSED') {
      throw this._businessError('Chỉ có thể resume lịch cố định đang PAUSED', 400, 'INVALID_FIXED_SCHEDULE_STATUS');
    }

    const courtId = schedule.court_id._id?.toString() || schedule.court_id.toString();
    const scheduleOverlap = await this.checkScheduleConflict(
      courtId,
      schedule.start_minutes,
      schedule.end_minutes,
      schedule.frequency,
      schedule.days_of_week || [],
      schedule.start_date,
      schedule.end_date,
      schedule._id
    );
    const bookingOverlap = await this.checkBookingConflictForNewSchedule(
      courtId,
      schedule.start_minutes,
      schedule.end_minutes,
      schedule.frequency,
      schedule.days_of_week || [],
      schedule.start_date,
      schedule.end_date
    );
    if (scheduleOverlap || bookingOverlap) {
      throw this._businessError(
        'Không thể resume lịch cố định vì khung giờ đã có lịch đặt.',
        409,
        'FIXED_SCHEDULE_RESUME_CONFLICT'
      );
    }

    await this._assertFixedScheduleParticipantsAvailable(schedule, {
      excludeFixedScheduleId: schedule._id
    });

    const updated = await fixedScheduleRepository.updateById(id, {
      status: 'ACTIVE',
      paused_at: null
    });
    return { schedule: this._formatScheduleResponse(updated) };
  }

  /**
   * Hủy lịch cố định
   */
  async cancelFixedSchedule(id, userId, userRole) {
    const schedule = await fixedScheduleRepository.findById(id);
    if (!schedule) {
      throw this._businessError('Không tìm thấy lịch cố định', 404, 'FIXED_SCHEDULE_NOT_FOUND');
    }

    // Bảo mật: CUSTOMER chỉ được hủy lịch của mình
    if (userRole === 'CUSTOMER' && schedule.user_id._id.toString() !== userId) {
      throw this._businessError('Bạn không có quyền hủy lịch cố định này', 403, 'FORBIDDEN');
    }

    if (userRole === 'STAFF' || userRole === 'ADMIN') {
      await this._assertActorCanManageSchedule(schedule, { id: userId, role: userRole });
    }

    if (!['PENDING_APPROVAL', 'ACTIVE'].includes(schedule.status)) {
      throw this._businessError('Không thể hủy lịch cố định ở trạng thái hiện tại', 400, 'INVALID_FIXED_SCHEDULE_STATUS');
    }

    const cancellationSummary = schedule.status === 'ACTIVE'
      ? await this.cancelFutureBookingsForSchedule(schedule, userRole)
      : this._emptyCancellationSummary();
    const updated = await fixedScheduleRepository.updateById(id, { status: 'CANCELLED' });
    
    // Gửi thông báo cho người dùng
    try {
      await notificationHelper.notifyUser({
        userId: schedule.user_id._id,
        title: '🚫 Lịch cố định đã hủy',
        content: `Đăng ký lịch cố định sân ${schedule.court_id.name} (${Math.floor(schedule.start_minutes/60)}:00 - ${Math.floor(schedule.end_minutes/60)}:00) đã được hủy thành công.`,
        type: 'SYSTEM',
        audience: 'CUSTOMER',
        metadata: { fixedScheduleId: id }
      });
    } catch (err) {
      console.error('Error sending cancellation notification:', err.message);
    }

    return {
      schedule: this._formatScheduleResponse(updated),
      cancellationSummary: this._formatCancellationSummary(cancellationSummary)
    };
  }

  async _assertActorCanCancelScheduleOccurrence(schedule, actor) {
    if (!actor || !['CUSTOMER', 'STAFF', 'ADMIN'].includes(actor.role)) {
      throw this._businessError('Bạn không có quyền hủy buổi này', 403, 'FORBIDDEN');
    }

    if (actor.role === 'CUSTOMER') {
      const ownerId = schedule.user_id?._id?.toString() || schedule.user_id?.toString();
      if (ownerId !== actor.id) {
        throw this._businessError('Bạn không có quyền hủy buổi này', 403, 'FORBIDDEN');
      }
      return;
    }

    await this._assertActorCanManageSchedule(schedule, actor);
  }

  async _upsertScheduleException(scheduleId, dateStr, reason, options = {}) {
    const schedule = await FixedSchedule.findById(scheduleId).session(options.session || null);
    if (!schedule) {
      throw this._businessError('Không tìm thấy lịch cố định', 404, 'FIXED_SCHEDULE_NOT_FOUND');
    }

    const normalizedReason = typeof reason === 'string' && reason.trim().length > 0
      ? reason.trim()
      : 'Hủy một buổi fixed matching';
    const exceptions = schedule.exception_dates || [];
    const existing = exceptions.find(exception =>
      exception.date === dateStr && exception.type === 'CANCELLED'
    );

    if (existing) {
      existing.reason = normalizedReason;
    } else {
      exceptions.push({
        date: dateStr,
        type: 'CANCELLED',
        reason: normalizedReason
      });
      schedule.exception_dates = exceptions;
    }

    await schedule.save({ session: options.session || null });
    return true;
  }

  async _findFixedMatchingOccurrence(schedule, dateStr, options = {}) {
    const scheduleId = this._scheduleId(schedule);
    const booking = await Booking.findOne({
      fixed_schedule_id: scheduleId,
      booking_date: dateStr,
      start_minutes: schedule.start_minutes,
      end_minutes: schedule.end_minutes
    }).session(options.session || null);

    const sessionQuery = {
      fixed_schedule_id: scheduleId,
      booking_date: dateStr,
      start_minutes: schedule.start_minutes
    };
    if (booking?._id) {
      sessionQuery.$or = [
        { booking_id: booking._id },
        { booking_id: { $exists: false } },
        { booking_id: null }
      ];
    }

    let matchingSession = await MatchingSession.findOne(sessionQuery).session(options.session || null);
    if (!matchingSession && booking?._id) {
      matchingSession = await MatchingSession.findOne({
        fixed_schedule_id: scheduleId,
        booking_id: booking._id
      }).session(options.session || null);
    }

    return { booking, matchingSession };
  }

  async _cancelFixedMatchingOccurrenceCore(schedule, dateStr, reason, actor, options = {}) {
    const now = new Date();
    const summary = this._emptyOccurrenceCancellationSummary();

    const { booking, matchingSession } = await this._findFixedMatchingOccurrence(schedule, dateStr, options);
    summary.occurrenceExisted = Boolean(booking || matchingSession);

    if (booking?.status === BOOKING_STATUSES.COMPLETED || matchingSession?.status === 'COMPLETED') {
      throw this._businessError(
        'Không thể hủy buổi fixed matching đã hoàn thành',
        409,
        'FIXED_MATCHING_OCCURRENCE_COMPLETED'
      );
    }
    if (
      booking
      && ![BOOKING_STATUSES.PENDING, BOOKING_STATUSES.CANCELLED].includes(booking.status)
    ) {
      throw this._businessError(
        'Chỉ có thể hủy buổi fixed matching khi booking còn PENDING',
        409,
        'FIXED_MATCHING_OCCURRENCE_BOOKING_NOT_CANCELLABLE'
      );
    }

    await this._upsertScheduleException(schedule._id, dateStr, reason, options);
    summary.exceptionUpserted = true;

    if (booking?._id) {
      const payments = await paymentRepository.findManyRaw({ booking_id: booking._id }, options);
      const successPayments = payments.filter(payment => payment.status === 'SUCCESS');
      summary.successPayments = successPayments.length;
      if (successPayments.length > 0) {
        console.warn(
          `[Fixed Matching Occurrence Cancel] Booking ${booking._id} has SUCCESS payments; refund is not automated.`
        );
      }

      const pendingPayments = payments.filter(payment => payment.status === 'PENDING');
      if (pendingPayments.length > 0) {
        const result = await paymentService.cancelPendingPaymentsForBooking(booking._id, options);
        summary.pendingPaymentsCancelled = result.modifiedCount || result.nModified || pendingPayments.length;
      }

      if (booking.status === BOOKING_STATUSES.PENDING) {
        const updatedBooking = await Booking.findOneAndUpdate(
          { _id: booking._id, status: BOOKING_STATUSES.PENDING },
          {
            status: BOOKING_STATUSES.CANCELLED,
            cancel_reason: CANCEL_REASONS.FIXED_SCHEDULE_CANCELLED,
            cancelled_by: this._cancelledByForRole(actor.role),
            cancelled_at: now
          },
          { new: true, session: options.session || null }
        );
        summary.bookingCancelled = Boolean(updatedBooking);
      }
    }

    if (matchingSession?._id && ['OPEN', 'FULL'].includes(matchingSession.status)) {
      const updatedSession = await MatchingSession.findOneAndUpdate(
        { _id: matchingSession._id, status: { $in: ['OPEN', 'FULL'] } },
        { status: 'CANCELLED' },
        { new: true, session: options.session || null }
      );
      summary.matchingSessionCancelled = Boolean(updatedSession);
    }

    return summary;
  }

  async cancelFixedMatchingOccurrence(id, dateStr, actor, body = {}) {
    const schedule = await fixedScheduleRepository.findById(id);
    if (!schedule) {
      throw this._businessError('Không tìm thấy lịch cố định', 404, 'FIXED_SCHEDULE_NOT_FOUND');
    }
    await this._assertActorCanCancelScheduleOccurrence(schedule, actor);

    if (schedule.type !== 'MATCHING') {
      throw this._businessError('Chỉ có thể hủy buổi cho lịch ghép cố định', 400, 'NOT_FIXED_MATCHING_SCHEDULE');
    }
    if (schedule.status === 'CANCELLED') {
      throw this._businessError('Không thể hủy buổi của lịch cố định đã hủy', 400, 'FIXED_SCHEDULE_CANCELLED');
    }
    if (!this._isValidDateString(dateStr)) {
      throw this._businessError('Ngày hủy không hợp lệ', 400, 'INVALID_OCCURRENCE_DATE');
    }
    if (!this._scheduleAppliesOnDate(schedule, dateStr)) {
      throw this._businessError(
        'Ngày hủy không thuộc khoảng hoặc tần suất của lịch cố định',
        400,
        'FIXED_SCHEDULE_DATE_NOT_IN_RECURRENCE'
      );
    }

    const reason = body.reason;
    const dbSession = await mongoose.startSession();
    try {
      let summary;
      await dbSession.withTransaction(async () => {
        const scheduleInTx = await fixedScheduleRepository.findById(id, { session: dbSession });
        if (!scheduleInTx) {
          throw this._businessError('Không tìm thấy lịch cố định', 404, 'FIXED_SCHEDULE_NOT_FOUND');
        }
        summary = await this._cancelFixedMatchingOccurrenceCore(
          scheduleInTx,
          dateStr,
          reason,
          actor,
          { session: dbSession }
        );
      });

      const updatedSchedule = await fixedScheduleRepository.findById(id);
      return {
        schedule: this._formatScheduleResponse(updatedSchedule),
        occurrenceDate: dateStr,
        cancellationSummary: summary
      };
    } catch (error) {
      if (!this._isTransactionUnsupported(error)) throw error;
      console.warn(
        `[Fixed Matching Occurrence Transaction Fallback] schedule ${id} on ${dateStr}: ${error.message}`
      );
      const summary = await this._cancelFixedMatchingOccurrenceCore(schedule, dateStr, reason, actor);
      const updatedSchedule = await fixedScheduleRepository.findById(id);
      return {
        schedule: this._formatScheduleResponse(updatedSchedule),
        occurrenceDate: dateStr,
        cancellationSummary: summary
      };
    } finally {
      dbSession.endSession();
    }
  }

  async _cancelFutureMatchingOccurrencesForSchedule(schedule, userRole, now = new Date()) {
    const scheduleId = this._scheduleId(schedule);
    const summary = this._emptyCancellationSummary();
    const cancelledBy = this._cancelledByForRole(userRole);
    const todayStr = toLocalDateString(now);

    const linkedBookings = await Booking.find({
      fixed_schedule_id: scheduleId,
      booking_date: { $gte: todayStr },
      status: {
        $in: [
          BOOKING_STATUSES.PENDING,
          BOOKING_STATUSES.CONFIRMED,
          BOOKING_STATUSES.CANCELLED,
          BOOKING_STATUSES.COMPLETED
        ]
      }
    });

    const cancellableBookingIds = [];
    for (const booking of linkedBookings) {
      if (booking.status === BOOKING_STATUSES.COMPLETED) {
        summary.skippedCompletedBookings += 1;
        summary.skippedBookings += 1;
        continue;
      }

      if (booking.status === BOOKING_STATUSES.CANCELLED) {
        summary.skippedCancelledBookings += 1;
        summary.skippedBookings += 1;
        continue;
      }

      const startAt = getBookingStartAt(booking);
      if (!startAt || now >= startAt) {
        summary.skippedPastBookings += 1;
        summary.skippedBookings += 1;
        continue;
      }

      if (booking.status !== BOOKING_STATUSES.PENDING) {
        summary.skippedNonPendingBookings += 1;
        summary.skippedBookings += 1;
        continue;
      }

      cancellableBookingIds.push(booking._id);
    }

    if (cancellableBookingIds.length > 0) {
      const payments = await paymentRepository.findManyRaw({
        booking_id: { $in: cancellableBookingIds }
      });
      const successPayments = payments.filter(payment => payment.status === 'SUCCESS');
      summary.successPayments = successPayments.length;
      if (successPayments.length > 0) {
        console.warn(
          `[Fixed Matching Series Cancel] Schedule ${scheduleId} has ${successPayments.length} SUCCESS payment(s); refund is not automated.`
        );
      }

      const pendingPaymentResult = await paymentRepository.updateMany(
        { booking_id: { $in: cancellableBookingIds }, status: 'PENDING' },
        { status: 'CANCELLED' }
      );
      summary.cancelledPendingPayments = pendingPaymentResult.modifiedCount || pendingPaymentResult.nModified || 0;

      const bookingResult = await Booking.updateMany(
        { _id: { $in: cancellableBookingIds }, status: BOOKING_STATUSES.PENDING },
        {
          status: BOOKING_STATUSES.CANCELLED,
          cancel_reason: CANCEL_REASONS.FIXED_SCHEDULE_CANCELLED,
          cancelled_by: cancelledBy,
          cancelled_at: now
        }
      );
      summary.cancelledBookings = bookingResult.modifiedCount || bookingResult.nModified || cancellableBookingIds.length;
    }

    const futureSessions = await MatchingSession.find({
      fixed_schedule_id: scheduleId,
      booking_date: { $gte: todayStr },
      status: { $in: ['OPEN', 'FULL'] }
    });
    const cancellableSessionIds = futureSessions
      .filter(session => {
        const startAt = getBookingStartAt(session);
        if (!startAt || now >= startAt) return false;
        return true;
      })
      .map(session => session._id);

    if (cancellableSessionIds.length > 0) {
      const sessionResult = await MatchingSession.updateMany(
        { _id: { $in: cancellableSessionIds }, status: { $in: ['OPEN', 'FULL'] } },
        { status: 'CANCELLED' }
      );
      summary.cancelledMatchingSessions = sessionResult.modifiedCount || sessionResult.nModified || cancellableSessionIds.length;
    }

    return summary;
  }

  async _cancelPendingFutureMatchingOccurrencesForReadinessRollback(schedule, userRole, now = new Date()) {
    const scheduleId = this._scheduleId(schedule);
    const summary = this._emptyCancellationSummary();
    const cancelledBy = this._cancelledByForRole(userRole);
    const todayStr = toLocalDateString(now);

    const pendingBookings = await Booking.find({
      fixed_schedule_id: scheduleId,
      booking_date: { $gte: todayStr },
      status: BOOKING_STATUSES.PENDING
    });

    const cancellableBookingIds = pendingBookings
      .filter(booking => {
        const startAt = getBookingStartAt(booking);
        if (!startAt || now >= startAt) {
          summary.skippedPastBookings += 1;
          summary.skippedBookings += 1;
          return false;
        }
        return true;
      })
      .map(booking => booking._id);

    if (cancellableBookingIds.length === 0) {
      return summary;
    }

    const payments = await paymentRepository.findManyRaw({
      booking_id: { $in: cancellableBookingIds }
    });
    const successPayments = payments.filter(payment => payment.status === 'SUCCESS');
    summary.successPayments = successPayments.length;
    if (successPayments.length > 0) {
      console.warn(
        `[Fixed Matching Readiness Rollback] Schedule ${scheduleId} has ${successPayments.length} SUCCESS payment(s); refund is not automated.`
      );
    }

    const pendingPaymentResult = await paymentRepository.updateMany(
      { booking_id: { $in: cancellableBookingIds }, status: 'PENDING' },
      { status: 'CANCELLED' }
    );
    summary.cancelledPendingPayments = pendingPaymentResult.modifiedCount || pendingPaymentResult.nModified || 0;

    const bookingResult = await Booking.updateMany(
      { _id: { $in: cancellableBookingIds }, status: BOOKING_STATUSES.PENDING },
      {
        status: BOOKING_STATUSES.CANCELLED,
        cancel_reason: CANCEL_REASONS.FIXED_SCHEDULE_CANCELLED,
        cancelled_by: cancelledBy,
        cancelled_at: now
      }
    );
    summary.cancelledBookings = bookingResult.modifiedCount || bookingResult.nModified || cancellableBookingIds.length;

    const sessionResult = await MatchingSession.updateMany(
      {
        fixed_schedule_id: scheduleId,
        booking_id: { $in: cancellableBookingIds },
        status: { $in: ['OPEN', 'FULL'] }
      },
      { status: 'CANCELLED' }
    );
    summary.cancelledMatchingSessions = sessionResult.modifiedCount || sessionResult.nModified || 0;

    return summary;
  }

  async cancelFutureBookingsForSchedule(scheduleOrId, userRole, now = new Date()) {
    const schedule = typeof scheduleOrId === 'object' && scheduleOrId?._id
      ? scheduleOrId
      : null;
    const scheduleId = schedule ? this._scheduleId(schedule) : scheduleOrId;
    if (schedule?.type === 'MATCHING') {
      return await this._cancelFutureMatchingOccurrencesForSchedule(schedule, userRole, now);
    }

    const summary = this._emptyCancellationSummary();
    const cancelledBy = this._cancelledByForRole(userRole);

    const linkedBookings = await Booking.find({
      fixed_schedule_id: scheduleId,
      status: {
        $in: [
          BOOKING_STATUSES.PENDING,
          BOOKING_STATUSES.CONFIRMED,
          BOOKING_STATUSES.CANCELLED,
          BOOKING_STATUSES.COMPLETED
        ]
      }
    });

    for (const booking of linkedBookings) {
      if (booking.status === BOOKING_STATUSES.COMPLETED) {
        summary.skippedCompletedBookings += 1;
        summary.skippedBookings += 1;
        continue;
      }

      if (booking.status === BOOKING_STATUSES.CANCELLED) {
        summary.skippedCancelledBookings += 1;
        summary.skippedBookings += 1;
        continue;
      }

      const startAt = getBookingStartAt(booking);
      if (!startAt || now >= startAt) {
        summary.skippedPastBookings += 1;
        summary.skippedBookings += 1;
        continue;
      }

      if (
        booking.status === BOOKING_STATUSES.CONFIRMED &&
        isWithinHoursBeforeStart(booking, 2, now)
      ) {
        summary.skippedConfirmedWithinTwoHours += 1;
        summary.skippedBookings += 1;
        continue;
      }

      const updatedBooking = await Booking.findOneAndUpdate(
        {
          _id: booking._id,
          status: { $in: [BOOKING_STATUSES.PENDING, BOOKING_STATUSES.CONFIRMED] }
        },
        {
          status: BOOKING_STATUSES.CANCELLED,
          cancel_reason: CANCEL_REASONS.FIXED_SCHEDULE_CANCELLED,
          cancelled_by: cancelledBy,
          cancelled_at: now
        },
        { new: true }
      );

      if (updatedBooking) {
        await paymentService.syncPaymentOnBookingCancelled(updatedBooking._id);
        await MatchingSession.updateMany(
          {
            fixed_schedule_id: scheduleId,
            booking_id: updatedBooking._id,
            status: { $in: ['OPEN', 'FULL'] }
          },
          { status: 'CANCELLED' }
        );
        summary.cancelledBookings += 1;
      }
    }

    return summary;
  }

  async approveFixedSchedule(id, actor) {
    const schedule = await fixedScheduleRepository.findById(id);
    if (!schedule) {
      throw this._businessError('Không tìm thấy lịch cố định', 404, 'FIXED_SCHEDULE_NOT_FOUND');
    }

    await this._assertActorCanManageSchedule(schedule, actor);

    if (schedule.status !== 'PENDING_APPROVAL') {
      throw this._businessError('Chỉ có thể duyệt lịch cố định đang chờ duyệt', 400, 'INVALID_FIXED_SCHEDULE_STATUS');
    }

    const courtId = schedule.court_id._id?.toString() || schedule.court_id.toString();
    const approvalRange = this._getAdvanceGenerationRange();
    await this._assertScheduleAvailabilityForRange(
      schedule,
      approvalRange.fromDateStr,
      approvalRange.toDateStr
    );
    const scheduleOverlap = await this.checkScheduleConflict(
      courtId,
      schedule.start_minutes,
      schedule.end_minutes,
      schedule.frequency,
      schedule.days_of_week || [],
      schedule.start_date,
      schedule.end_date,
      schedule._id
    );

    const bookingOverlap = await this.checkBookingConflictForNewSchedule(
      courtId,
      schedule.start_minutes,
      schedule.end_minutes,
      schedule.frequency,
      schedule.days_of_week || [],
      schedule.start_date,
      schedule.end_date
    );

    if (scheduleOverlap || bookingOverlap) {
      throw this._businessError(
        'Không thể duyệt lịch cố định vì khung giờ đã có lịch đặt.',
        409,
        'FIXED_SCHEDULE_APPROVAL_CONFLICT'
      );
    }

    await this._assertFixedScheduleParticipantsAvailable(schedule, {
      excludeFixedScheduleId: schedule._id
    });

    const session = await mongoose.startSession();
    let updated;
    let generatedBookings = [];

    try {
      await session.withTransaction(async () => {
        const scheduleInTx = await fixedScheduleRepository.findById(id, { session });
        if (!scheduleInTx) {
          throw this._businessError('KhÃ´ng tÃ¬m tháº¥y lá»‹ch cá»‘ Ä‘á»‹nh', 404, 'FIXED_SCHEDULE_NOT_FOUND');
        }

        if (scheduleInTx.status !== 'PENDING_APPROVAL') {
          throw this._businessError('Chá»‰ cÃ³ thá»ƒ duyá»‡t lá»‹ch cá»‘ Ä‘á»‹nh Ä‘ang chá» duyá»‡t', 400, 'INVALID_FIXED_SCHEDULE_STATUS');
        }

        const txCourtId = scheduleInTx.court_id._id?.toString() || scheduleInTx.court_id.toString();
        await this._assertScheduleAvailabilityForRange(
          scheduleInTx,
          approvalRange.fromDateStr,
          approvalRange.toDateStr,
          { session }
        );
        const txScheduleOverlap = await this.checkScheduleConflict(
          txCourtId,
          scheduleInTx.start_minutes,
          scheduleInTx.end_minutes,
          scheduleInTx.frequency,
          scheduleInTx.days_of_week || [],
          scheduleInTx.start_date,
          scheduleInTx.end_date,
          scheduleInTx._id,
          { session }
        );

        const txBookingOverlap = await this.checkBookingConflictForNewSchedule(
          txCourtId,
          scheduleInTx.start_minutes,
          scheduleInTx.end_minutes,
          scheduleInTx.frequency,
          scheduleInTx.days_of_week || [],
          scheduleInTx.start_date,
          scheduleInTx.end_date,
          { session }
        );

        if (txScheduleOverlap || txBookingOverlap) {
          throw this._businessError(
            'KhÃ´ng thá»ƒ duyá»‡t lá»‹ch cá»‘ Ä‘á»‹nh vÃ¬ khung giá» Ä‘Ã£ cÃ³ lá»‹ch Ä‘áº·t.',
            409,
            'FIXED_SCHEDULE_APPROVAL_CONFLICT'
          );
        }

        await this._assertFixedScheduleParticipantsAvailable(scheduleInTx, {
          excludeFixedScheduleId: scheduleInTx._id,
          session
        });

        updated = await fixedScheduleRepository.updatePendingApprovalById(id, {
          status: 'ACTIVE',
          approved_by: actor.id,
          approved_at: new Date()
        }, { session });

        if (!updated) {
          throw this._businessError('Chá»‰ cÃ³ thá»ƒ duyá»‡t lá»‹ch cá»‘ Ä‘á»‹nh Ä‘ang chá» duyá»‡t', 400, 'INVALID_FIXED_SCHEDULE_STATUS');
        }

        if (['COURT_BOOKING', 'MATCHING'].includes(updated.type)) {
          const { fromDateStr, toDateStr } = this._getAdvanceGenerationRange();
          generatedBookings = await this.generateBookingsForRange(updated, fromDateStr, toDateStr, {
            session,
            sendNotification: false
          });
        }
      });
    } finally {
      session.endSession();
    }

    updated = await fixedScheduleRepository.findById(id);

    try {
      await notificationHelper.notifyUser({
        userId: updated.user_id._id,
        title: 'Lịch cố định đã được duyệt',
        content: 'Lịch cố định của bạn đã được nhân viên duyệt và bắt đầu có hiệu lực.',
        type: 'SYSTEM',
        audience: 'CUSTOMER',
        metadata: { fixedScheduleId: id }
      });
    } catch (err) {
      console.error('Error sending fixed schedule approval notification:', err.message);
    }

    return {
      schedule: this._formatScheduleResponse(updated),
      generatedBookings
    };
  }

  async rejectFixedSchedule(id, actor, reason = null) {
    const schedule = await fixedScheduleRepository.findById(id);
    if (!schedule) {
      throw this._businessError('Không tìm thấy lịch cố định', 404, 'FIXED_SCHEDULE_NOT_FOUND');
    }

    await this._assertActorCanManageSchedule(schedule, actor);

    if (schedule.status !== 'PENDING_APPROVAL') {
      throw this._businessError('Chỉ có thể từ chối lịch cố định đang chờ duyệt', 400, 'INVALID_FIXED_SCHEDULE_STATUS');
    }

    const normalizedReason = typeof reason === 'string' && reason.trim().length > 0
      ? reason.trim()
      : null;

    const updated = await fixedScheduleRepository.updatePendingApprovalById(id, {
      status: 'REJECTED',
      rejected_by: actor.id,
      rejected_at: new Date(),
      rejection_reason: normalizedReason
    });

    if (!updated) {
      throw this._businessError('Chá»‰ cÃ³ thá»ƒ tá»« chá»‘i lá»‹ch cá»‘ Ä‘á»‹nh Ä‘ang chá» duyá»‡t', 400, 'INVALID_FIXED_SCHEDULE_STATUS');
    }

    try {
      await notificationHelper.notifyUser({
        userId: updated.user_id._id,
        title: 'Lịch cố định đã bị từ chối',
        content: normalizedReason
          ? `Lịch cố định của bạn đã bị từ chối. Lý do: ${normalizedReason}`
          : 'Lịch cố định của bạn đã bị từ chối. Vui lòng chọn khung giờ khác.',
        type: 'SYSTEM',
        audience: 'CUSTOMER',
        metadata: { fixedScheduleId: id }
      });
    } catch (err) {
      console.error('Error sending fixed schedule rejection notification:', err.message);
    }

    return { schedule: this._formatScheduleResponse(updated) };
  }

  /**
   * Kiểm tra trùng với các FixedSchedule ACTIVE khác
   */
  async checkScheduleConflict(courtId, startMinutes, endMinutes, frequency, daysOfWeek, startDate, endDate, excludeScheduleId = null, options = {}) {
    const query = {
      court_id: courtId,
      status: 'ACTIVE'
    };
    if (excludeScheduleId) {
      query._id = { $ne: excludeScheduleId };
    }

    const activeSchedules = await fixedScheduleRepository.findMany(query, 0, 1000, options);

    for (const s of activeSchedules) {
      // 1. Kiểm tra đè thời gian trong ngày
      const timeOverlap = Math.max(startMinutes, s.start_minutes) < Math.min(endMinutes, s.end_minutes);
      if (!timeOverlap) continue;

      // 2. Kiểm tra chồng chéo thời gian hiệu lực (khoảng ngày)
      const dateOverlap = (!s.end_date || startDate <= s.end_date) && (!endDate || s.start_date <= endDate);
      if (!dateOverlap) continue;

      // 3. Kiểm tra tần suất lặp
      let recurrenceOverlap = false;
      if (frequency === 'DAILY' || s.frequency === 'DAILY') {
        recurrenceOverlap = true;
      } else if (frequency === 'WEEKLY' && s.frequency === 'WEEKLY') {
        // Có chung ngày lặp trong tuần không
        const intersection = daysOfWeek.filter(day => s.days_of_week.includes(day));
        if (intersection.length > 0) {
          recurrenceOverlap = true;
        }
      }

      if (recurrenceOverlap) {
        return s;
      }
    }

    return null;
  }

  /**
   * Kiểm tra xem một Booking cụ thể có bị trùng lịch với Đăng ký cố định nào đang ACTIVE không
   */
  async checkBookingConflict(courtId, bookingDate, startMinutes, endMinutes) {
    if (
      !this._isValidDateString(bookingDate) ||
      !Number.isFinite(startMinutes) ||
      !Number.isFinite(endMinutes) ||
      startMinutes >= endMinutes
    ) {
      return null;
    }

    const court = await Court.findById(courtId).select('facility_id');
    if (!court) return null;

    const activeSchedules = await fixedScheduleRepository.findActiveConflictsForBooking({
      facilityId: court.facility_id,
      courtId,
      bookingDate,
      startMinutes,
      endMinutes
    });

    for (const s of activeSchedules) {
      let dayMatch = false;
      if (s.frequency === 'DAILY') {
        dayMatch = true;
      } else if (s.frequency === 'WEEKLY') {
        const dayOfWeek = getDayOfWeekFromDateString(bookingDate);
        if (s.days_of_week.includes(dayOfWeek)) {
          dayMatch = true;
        }
      }

      if (dayMatch) {
        return s;
      }
    }

    return null;
  }

  /**
   * Kiểm tra chéo xem Đăng ký lịch cố định mới có trùng với một Booking đơn lẻ đã có sẵn trong DB hay không
   */
  async checkBookingConflictForNewSchedule(courtId, startMinutes, endMinutes, frequency, daysOfWeek, startDate, endDate, options = {}) {
    const query = {
      court_id: courtId,
      booking_date: { $gte: startDate },
      status: { $in: ['PENDING', 'CONFIRMED'] },
      $nor: [
        { start_minutes: { $gte: endMinutes } },
        { end_minutes: { $lte: startMinutes } }
      ]
    };
    if (endDate) {
      query.booking_date.$lte = endDate;
    }

    const bookings = await Booking.find(query).session(options.session || null);

    for (const b of bookings) {
      let dayMatch = false;
      if (frequency === 'DAILY') {
        dayMatch = true;
      } else if (frequency === 'WEEKLY') {
        const dayOfWeek = getDayOfWeekFromDateString(b.booking_date);
        if (daysOfWeek.includes(dayOfWeek)) {
          dayMatch = true;
        }
      }

      if (dayMatch) {
        return b;
      }
    }

    return null;
  }

  /**
   * Tự động sinh lịch chơi cho một khoảng ngày
   */
  _scheduleAppliesOnDate(schedule, dateStr) {
    if (dateStr < schedule.start_date) return false;
    if (schedule.end_date && dateStr > schedule.end_date) return false;

    if (schedule.frequency === 'DAILY') return true;
    if (schedule.frequency === 'WEEKLY') {
      const dayOfWeek = getDayOfWeekFromDateString(dateStr);
      return (schedule.days_of_week || []).includes(dayOfWeek);
    }
    return false;
  }

  _isScheduleExceptionDate(schedule, dateStr) {
    return (schedule.exception_dates || []).some(exception =>
      exception.date === dateStr && ['CANCELLED', 'TEAM_UNAVAILABLE'].includes(exception.type)
    );
  }

  _isFixedMatchingReady(schedule) {
    const config = schedule.matching_config;
    return schedule.status === 'ACTIVE'
      && schedule.type === 'MATCHING'
      && config?.readiness === MATCHING_READINESS.READY
      && ['TEAM_FILL', 'TEAM_VS_TEAM'].includes(config?.team_mode);
  }

  async _occurrenceExists(schedule, dateStr, options = {}) {
    const scheduleId = this._scheduleId(schedule);
    const [existingBooking, existingSession] = await Promise.all([
      Booking.findOne({
        fixed_schedule_id: scheduleId,
        court_id: this._objectIdValue(schedule.court_id),
        booking_date: dateStr,
        start_minutes: schedule.start_minutes,
        end_minutes: schedule.end_minutes,
        status: { $ne: BOOKING_STATUSES.CANCELLED }
      }).session(options.session || null),
      MatchingSession.findOne({
        fixed_schedule_id: scheduleId,
        booking_date: dateStr,
        start_minutes: schedule.start_minutes
      }).session(options.session || null)
    ]);

    return Boolean(existingBooking || existingSession);
  }

  _buildFixedMatchingSessionData(schedule, booking, dateStr) {
    const config = schedule.matching_config;
    const occupancy = this.calculateFixedMatchingOccupancy(config);
    const approvedMembers = (config.members || [])
      .filter(member => member.status === 'APPROVED')
      .map(member => ({
        user_id: this._objectIdValue(member.user_id),
        status: 'APPROVED',
        team_code: member.team_code,
        represented_count: Number(member.represented_count || 1),
        joined_at: member.joined_at || new Date()
      }));
    const teams = (config.teams || []).map(team => ({
      team_code: team.team_code,
      name: team.name || '',
      max_players: Number(team.max_players || config.team_size),
      representative_user_id: this._objectIdValue(team.representative_user_id) || null
    }));
    const teamMode = config.team_mode;
    const teamBasedNeeded = ['TEAM_FILL', 'TEAM_VS_TEAM'].includes(teamMode)
      ? Number(config.team_size || 0) * 2 - Number(config.host_represented_count || 1)
      : approvedMembers.length;

    return {
      fixed_schedule_id: schedule._id,
      host_id: this._objectIdValue(schedule.user_id),
      sport_id: this._objectIdValue(schedule.sport_id),
      facility_id: this._objectIdValue(schedule.facility_id),
      court_id: this._objectIdValue(schedule.court_id),
      booking_id: booking._id,
      booking_date: dateStr,
      start_minutes: schedule.start_minutes,
      end_minutes: schedule.end_minutes,
      total_players_needed: Math.max(1, teamBasedNeeded),
      team_mode: teamMode,
      host_team_code: config.host_team_code || 'A',
      host_represented_count: Number(config.host_represented_count || 1),
      teams,
      description: '',
      auto_approve: true,
      payment_policy: config.payment_policy,
      members: approvedMembers,
      status: occupancy.teamAOccupancy === Number(config.team_size || 0)
        && occupancy.teamBOccupancy === Number(config.team_size || 0)
        ? 'FULL'
        : 'OPEN'
    };
  }

  async _syncFixedMatchingPayments(booking, matchingSession, options = {}) {
    const paymentPolicy = matchingSession.payment_policy || 'HOST_PAY_ALL';
    if (paymentPolicy === 'TEAM_REPRESENTATIVES_SPLIT') {
      return await paymentService.syncTeamRepresentativePaymentsForSession({
        session: matchingSession,
        booking
      }, options);
    }

    const memberUserIds = (matchingSession.members || [])
      .filter(member => member.status === 'APPROVED')
      .map(member => this._objectIdValue(member.user_id))
      .filter(Boolean);

    return await paymentService.createPendingPaymentsForMatching({
      booking,
      hostUserId: this._objectIdValue(matchingSession.host_id),
      memberUserIds,
      paymentPolicy
    }, options);
  }

  async _generateFixedMatchingOccurrenceCore(schedule, dateStr, options = {}) {
    if (!this._isFixedMatchingReady(schedule)) return null;
    if (this._isScheduleExceptionDate(schedule, dateStr)) return null;
    if (await this._occurrenceExists(schedule, dateStr, options)) return null;

    const conflictingBooking = await Booking.findOne({
      court_id: this._objectIdValue(schedule.court_id),
      booking_date: dateStr,
      status: { $in: [BOOKING_STATUSES.PENDING, BOOKING_STATUSES.CONFIRMED] },
      start_minutes: { $lt: schedule.end_minutes },
      end_minutes: { $gt: schedule.start_minutes }
    }).session(options.session || null);

    if (conflictingBooking) {
      console.warn(
        `[Fixed Matching Conflict] Skip schedule ${schedule._id} on ${dateStr}: `
        + `booking ${conflictingBooking._id} overlaps the reserved slot.`
      );
      return null;
    }

    const court = await Court.findById(this._objectIdValue(schedule.court_id)).session(options.session || null);
    const price = bookingPriceService.calculateBookingPrice(
      court,
      schedule.start_minutes,
      schedule.end_minutes
    );

    const booking = new Booking({
      user_id: this._objectIdValue(schedule.user_id),
      court_id: this._objectIdValue(schedule.court_id),
      booking_date: dateStr,
      start_minutes: schedule.start_minutes,
      end_minutes: schedule.end_minutes,
      total_price: price,
      fixed_schedule_id: schedule._id,
      is_fixed_schedule: true,
      status: BOOKING_STATUSES.PENDING
    });
    await booking.save({ session: options.session || null });

    let matchingSession = null;
    try {
      matchingSession = new MatchingSession(this._buildFixedMatchingSessionData(schedule, booking, dateStr));
      await matchingSession.save({ session: options.session || null });
      if (matchingSession.status === 'FULL') {
        await this._syncFixedMatchingPayments(booking, matchingSession, options);
      }
      return dateStr;
    } catch (error) {
      if (matchingSession?._id) {
        await MatchingSession.findByIdAndUpdate(
          matchingSession._id,
          { status: 'CANCELLED' },
          { session: options.session || null }
        );
      }
      await Booking.findByIdAndUpdate(
        booking._id,
        {
          status: BOOKING_STATUSES.CANCELLED,
          cancel_reason: CANCEL_REASONS.FIXED_SCHEDULE_CANCELLED,
          cancelled_by: CANCELLED_BY.SYSTEM,
          cancelled_at: new Date()
        },
        { session: options.session || null }
      );
      await paymentService.cancelPendingPaymentsForBooking(booking._id, options);
      throw error;
    }
  }

  async _generateFixedMatchingOccurrence(schedule, dateStr, options = {}) {
    if (options.session) {
      return await this._generateFixedMatchingOccurrenceCore(schedule, dateStr, options);
    }

    const dbSession = await mongoose.startSession();
    try {
      let generatedDate = null;
      await dbSession.withTransaction(async () => {
        generatedDate = await this._generateFixedMatchingOccurrenceCore(schedule, dateStr, {
          session: dbSession
        });
      });
      return generatedDate;
    } catch (error) {
      if (!this._isTransactionUnsupported(error)) throw error;
      console.warn(
        `[Fixed Matching Transaction Fallback] schedule ${schedule._id} on ${dateStr}: ${error.message}`
      );
      return await this._generateFixedMatchingOccurrenceCore(schedule, dateStr);
    } finally {
      dbSession.endSession();
    }
  }

  async generateBookingsForRange(schedule, fromDateStr, toDateStr, options = {}) {
    const { session = null, sendNotification = true } = options;
    const generated = [];

    // Lặp qua từng ngày trong khoảng
    for (let dateStr = fromDateStr; dateStr <= toDateStr; dateStr = this._dateStringAddDays(dateStr, 1)) {

      if (!this._scheduleAppliesOnDate(schedule, dateStr)) continue;
      if (this._isScheduleExceptionDate(schedule, dateStr)) continue;

      try {
        await courtAvailabilityService.assertAvailable({
          courtId: this._objectIdValue(schedule.court_id),
          bookingDate: dateStr,
          startMinutes: schedule.start_minutes,
          endMinutes: schedule.end_minutes,
          session
        });
      } catch (error) {
        if (!courtAvailabilityService.isAvailabilityError(error)) throw error;
        console.warn(
          `[Fixed Schedule Availability] Skip schedule ${schedule._id} `
          + `on ${dateStr}: ${error.code}`
        );
        continue;
      }

      if (schedule.type === 'MATCHING') {
        const generatedDate = await this._generateFixedMatchingOccurrence(schedule, dateStr, { session });
        if (generatedDate) generated.push(generatedDate);
        continue;
      }

      const existingScheduleBooking = await Booking.findOne({
        fixed_schedule_id: schedule._id,
        court_id: schedule.court_id,
        booking_date: dateStr,
        start_minutes: schedule.start_minutes,
        end_minutes: schedule.end_minutes
      }).session(session);

      if (existingScheduleBooking) continue;

      const conflictingBooking = await Booking.findOne({
        court_id: schedule.court_id,
        booking_date: dateStr,
        status: { $in: ['PENDING', 'CONFIRMED'] },
        start_minutes: { $lt: schedule.end_minutes },
        end_minutes: { $gt: schedule.start_minutes }
      }).session(session);

      if (conflictingBooking) {
        console.warn(
          `[Fixed Schedule Conflict] Skip schedule ${schedule._id} on ${dateStr}: `
          + `booking ${conflictingBooking._id} overlaps the reserved slot.`
        );
        continue;
      }

      // Lấy giá sân để tính tổng tiền cho mỗi buổi
      const court = await Court.findById(schedule.court_id).session(session);
      const price = bookingPriceService.calculateBookingPrice(
        court,
        schedule.start_minutes,
        schedule.end_minutes
      );

      // 1. Tạo Booking
      const booking = new Booking({
        user_id: schedule.user_id,
        court_id: schedule.court_id,
        booking_date: dateStr,
        start_minutes: schedule.start_minutes,
        end_minutes: schedule.end_minutes,
        total_price: price,
        fixed_schedule_id: schedule._id,
        is_fixed_schedule: true,
        status: 'PENDING' // Chờ thanh toán từng buổi
      });
      await booking.save({ session });

      const existingPayment = await paymentRepository.findOne(
        { booking_id: booking._id },
        { session }
      );
      if (!existingPayment) {
        await paymentRepository.create({
          booking_id: booking._id,
          user_id: schedule.user_id,
          amount: price,
          method: 'BANK_TRANSFER',
          status: 'PENDING',
          transaction_id: ''
        }, { session });
      }

      generated.push(dateStr);
    }

    if (sendNotification && generated.length > 0) {
      try {
        await notificationHelper.notifyUser({
          userId: schedule.user_id._id,
          title: '📅 Sinh lịch chơi cố định tự động',
          content: `Hệ thống đã tự động lên lịch chơi tại sân ${schedule.court_id?.name || ''} vào các ngày: ${generated.join(', ')}.`,
          type: 'SYSTEM',
          audience: 'CUSTOMER',
          metadata: { fixedScheduleId: schedule._id.toString() }
        });
      } catch (err) {
        console.error('Error sending auto-generation notification:', err.message);
      }
    }

    return generated;
  }
}

module.exports = new FixedScheduleService();
