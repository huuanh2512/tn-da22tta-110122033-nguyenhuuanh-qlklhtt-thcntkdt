const bookingRepository = require('../repositories/booking.repository');
const mongoose = require('mongoose');
const Booking = require('../models/booking.model');
const User = require('../models/user.model');
const Facility = require('../models/facility.model');
const Court = require('../models/court.model');
const MatchingSession = require('../models/matching.model');
const fixedScheduleService = require('./fixed-schedule.service');
const courtAvailabilityService = require('./court-availability.service');
const bookingPriceService = require('./booking-price.service');
const paymentService = require('./payment.service');
const notificationHelper = require('./notification.helper');
const userScheduleConflictService = require('./user-schedule-conflict.service');
const {
  BOOKING_STATUSES,
  CANCEL_REASONS,
  CANCELLED_BY,
  AUTO_CANCEL_LEAD_MINUTES,
  CUSTOMER_CANCEL_BLOCK_MESSAGE,
  CUSTOMER_CANCEL_STARTED_MESSAGE,
  CUSTOMER_RESCHEDULE_BLOCK_MESSAGE,
  CUSTOMER_BOOKING_LEAD_TIME_MESSAGE,
  getBookingAutoCancelAt,
  getBookingEndAt,
  getBookingStartAt,
  isWithinHoursBeforeStart,
  toLocalDateString
} = require('../utils/booking-time.util');

class BookingService {
  _maskEmail(email) {
    if (!email || !email.includes('@')) return '';
    const [localPart, domain] = email.split('@');
    const visible = localPart.slice(0, Math.min(3, localPart.length));
    return `${visible}***@${domain}`;
  }

  _maskPhone(phone) {
    if (!phone) return '';
    const value = String(phone);
    if (value.length <= 6) return `${value.slice(0, 2)}***`;
    return `${value.slice(0, 3)}****${value.slice(-3)}`;
  }

  _maskName(name) {
    if (!name) return null;
    const value = String(name).trim();
    if (value.length <= 2) return `${value.slice(0, 1)}***`;
    return `${value.slice(0, 3)}***`;
  }

  _formatBookingResponse(
    booking,
    payment = null,
    matchingContext = null,
    privacyMode = 'FULL'
  ) {
    const effectiveCancelledAt =
      booking.cancel_reason === CANCEL_REASONS.AUTO_CANCEL_STAFF_NOT_APPROVED
        ? (booking.cancelled_at || getBookingAutoCancelAt(booking))
        : booking.cancelled_at;
    const isReportResponse = privacyMode === 'STAFF_REPORT';
    const userPhone = booking.user_id?.profile?.phone || '';
    const userEmail = booking.user_id?.email || '';
    const courtSport = booking.court_id?.sport_id;

    return {
      id: booking._id.toString(),
      user: booking.user_id ? {
        id: booking.user_id._id?.toString() || booking.user_id.toString(),
        name: isReportResponse
          ? this._maskName(booking.user_id.profile?.name) || ''
          : booking.user_id.profile?.name || '',
        phone: isReportResponse
          ? ''
          : userPhone,
        email: isReportResponse
          ? ''
          : userEmail
      } : null,
      guestName: isReportResponse
        ? this._maskName(booking.guest_name)
        : booking.guest_name || null,
      guestPhone: isReportResponse
        ? null
        : booking.guest_phone || null,
      court: booking.court_id ? {
        id: booking.court_id._id?.toString() || booking.court_id.toString(),
        name: booking.court_id.name || '',
        facilityName: booking.court_id.facility_id?.name || '',
        sport: courtSport ? {
          id: courtSport._id?.toString() || courtSport.toString(),
          name: courtSport.name || ''
        } : null
      } : null,
      sport: courtSport ? {
        id: courtSport._id?.toString() || courtSport.toString(),
        name: courtSport.name || ''
      } : null,
      sportName: courtSport?.name || '',
      sportId: courtSport?._id?.toString() || courtSport?.toString() || null,
      bookingDate: booking.booking_date,
      startMinutes: booking.start_minutes,
      endMinutes: booking.end_minutes,
      totalPrice: booking.total_price,
      total_price: booking.total_price,
      status: booking.status,
      fixedScheduleId: booking.fixed_schedule_id ? booking.fixed_schedule_id.toString() : null,
      fixed_schedule_id: booking.fixed_schedule_id ? booking.fixed_schedule_id.toString() : null,
      isFixedSchedule: booking.is_fixed_schedule || false,
      is_fixed_schedule: booking.is_fixed_schedule || false,
      paymentStatus: payment?.status || null,
      payment_status: payment?.status || null,
      source: matchingContext ? 'MATCHING' : 'BOOKING',
      isMatching: Boolean(matchingContext),
      matchingSessionId: matchingContext?.sessionId || null,
      isHost: matchingContext?.isHost || false,
      paymentPolicy: matchingContext?.paymentPolicy || null,
      myPaymentStatus: matchingContext?.myPaymentStatus || null,
      myPaymentAmount: matchingContext?.myPaymentAmount ?? null,
      membersCount: matchingContext?.membersCount ?? null,
      cancelReason: booking.cancel_reason || null,
      cancelledBy: booking.cancelled_by || null,
      cancelledAt: effectiveCancelledAt
        ? new Date(effectiveCancelledAt).toISOString()
        : null,
      createdAt: booking.created_at ? new Date(booking.created_at).toISOString() : null
    };
  }

  _businessError(message, statusCode = 400, code = 'BUSINESS_RULE_VIOLATION') {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  _isAdminRole(role) {
    return role === 'ADMIN' || role === 'SUPER_ADMIN';
  }

  _normalizeId(value) {
    return value?._id?.toString() || value?.toString() || null;
  }

  _optionalStringFilter(value, name) {
    if (value === undefined || value === null || value === '') return null;
    if (typeof value !== 'string') {
      throw this._businessError(
        `Invalid ${name} filter`,
        400,
        'INVALID_FILTER'
      );
    }
    return value;
  }

  _optionalObjectIdFilter(value, name) {
    const normalized = this._optionalStringFilter(value, name);
    if (!normalized) return null;
    if (!mongoose.isValidObjectId(normalized)) {
      throw this._businessError(
        `Invalid ${name} filter`,
        400,
        'INVALID_FILTER'
      );
    }
    return normalized;
  }

  _optionalDateFilter(value, name) {
    const normalized = this._optionalStringFilter(value, name);
    if (!normalized) return null;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
      throw this._businessError(
        `Invalid ${name} filter`,
        400,
        'INVALID_FILTER'
      );
    }
    return normalized;
  }

  async _resolveStaffFacilityIds(actor) {
    const [staff, assignedFacilities] = await Promise.all([
      User.findById(actor.id).select('facility_id'),
      Facility.find({ staff_ids: actor.id }).select('_id')
    ]);

    const facilityIds = new Set();
    const primaryFacilityId = this._normalizeId(staff?.facility_id);
    if (primaryFacilityId) facilityIds.add(primaryFacilityId);
    for (const facility of assignedFacilities) {
      facilityIds.add(facility._id.toString());
    }
    return [...facilityIds];
  }

  async _resolveReadScope(actor, requestedFacilityId = null) {
    if (!actor?.id || !actor?.role) {
      throw this._businessError('Unauthorized', 401, 'UNAUTHORIZED');
    }

    if (actor.role === 'CUSTOMER') {
      return {
        type: 'CUSTOMER',
        userId: actor.id,
        facilityIds: requestedFacilityId ? [requestedFacilityId] : []
      };
    }

    if (actor.role === 'STAFF') {
      const allowedFacilityIds = await this._resolveStaffFacilityIds(actor);
      if (allowedFacilityIds.length === 0) {
        throw this._businessError(
          'Forbidden: Staff account has no assigned facility',
          403,
          'STAFF_FACILITY_SCOPE_REQUIRED'
        );
      }

      if (
        requestedFacilityId &&
        !allowedFacilityIds.includes(requestedFacilityId)
      ) {
        throw this._businessError(
          'Forbidden: Facility is outside your assigned scope',
          403,
          'FORBIDDEN'
        );
      }

      return {
        type: 'STAFF',
        facilityIds: requestedFacilityId
          ? [requestedFacilityId]
          : allowedFacilityIds
      };
    }

    if (this._isAdminRole(actor.role)) {
      return {
        type: 'ADMIN',
        facilityIds: requestedFacilityId ? [requestedFacilityId] : []
      };
    }

    throw this._businessError(
      'Forbidden: Unsupported booking access role',
      403,
      'FORBIDDEN'
    );
  }

  async _courtIdsForFacilities(facilityIds) {
    if (!facilityIds || facilityIds.length === 0) return [];
    return await Court.find({
      facility_id: { $in: facilityIds }
    }).distinct('_id');
  }

  async resolveCourtReportScope(actor, filters = {}) {
    if (actor?.role === 'CUSTOMER') {
      throw this._businessError(
        'Forbidden: Court performance reports are not available to customers',
        403,
        'FORBIDDEN'
      );
    }

    const facilityId = this._optionalObjectIdFilter(
      filters.facilityId,
      'facilityId'
    );
    const courtId = this._optionalObjectIdFilter(filters.courtId, 'courtId');
    const sportId = this._optionalObjectIdFilter(filters.sportId, 'sportId');
    const scope = await this._resolveReadScope(actor, facilityId);
    const courtQuery = {};

    if (scope.facilityIds.length > 0) {
      courtQuery.facility_id = { $in: scope.facilityIds };
    }
    if (courtId) {
      courtQuery._id = courtId;
    }
    if (sportId) {
      courtQuery.sport_id = sportId;
    }

    const courts = await Court.find(courtQuery)
      .select('name facility_id sport_id status slot_config')
      .populate('sport_id', 'name')
      .lean();

    if (courtId && courts.length === 0) {
      if (scope.type === 'STAFF') {
        throw this._businessError(
          'Forbidden: Court is outside your assigned facility',
          403,
          'FORBIDDEN'
        );
      }
      throw this._businessError('Court not found', 404, 'COURT_NOT_FOUND');
    }

    return {
      type: scope.type,
      facilityIds: scope.facilityIds,
      courts
    };
  }

  _privacyMode(actor, filters = {}) {
    if (actor?.role !== 'STAFF') return 'FULL';
    return filters.view === 'report' ? 'STAFF_REPORT' : 'STAFF';
  }

  async _assertCanReadBooking(booking, actor) {
    const scope = await this._resolveReadScope(actor);
    if (scope.type === 'ADMIN') return;

    if (scope.type === 'CUSTOMER') {
      const bookingUserId = this._normalizeId(booking.user_id);
      if (bookingUserId !== scope.userId) {
        throw this._businessError(
          'Forbidden: You can only view your own bookings',
          403,
          'FORBIDDEN'
        );
      }
      return;
    }

    const bookingFacilityId = this._normalizeId(
      booking.court_id?.facility_id
    );
    if (!bookingFacilityId || !scope.facilityIds.includes(bookingFacilityId)) {
      throw this._businessError(
        'Forbidden: Booking is outside your assigned facility',
        403,
        'FORBIDDEN'
      );
    }
  }

  async _assertStaffFacilityScope(booking, actor) {
    if (!actor || actor.role !== 'STAFF') return;

    const staff = await User.findById(actor.id).select('facility_id');
    const staffFacilityId = staff?.facility_id?.toString();
    const bookingFacilityId = booking.court_id?.facility_id?._id?.toString()
      || booking.court_id?.facility_id?.toString();

    if (
      !staffFacilityId ||
      !bookingFacilityId ||
      staffFacilityId !== bookingFacilityId
    ) {
      throw this._businessError('Forbidden: Booking is outside your assigned facility', 403, 'FORBIDDEN');
    }
  }

  async _assertCreateBookingScope(court, userId, actor) {
    if (!actor?.id || !actor?.role) {
      throw this._businessError('Unauthorized', 401, 'UNAUTHORIZED');
    }

    if (actor.role === 'CUSTOMER') {
      if (this._normalizeId(userId) !== actor.id) {
        throw this._businessError(
          'Forbidden: Customers can only create bookings for themselves',
          403,
          'BOOKING_CREATE_USER_FORBIDDEN'
        );
      }
      return;
    }

    if (actor.role === 'STAFF') {
      const allowedFacilityIds = await this._resolveStaffFacilityIds(actor);
      if (allowedFacilityIds.length === 0) {
        throw this._businessError(
          'Forbidden: Staff account has no assigned facility',
          403,
          'STAFF_FACILITY_SCOPE_REQUIRED'
        );
      }

      const courtFacilityId = this._normalizeId(court?.facility_id);
      if (!courtFacilityId || !allowedFacilityIds.includes(courtFacilityId)) {
        throw this._businessError(
          'Forbidden: Court is outside your assigned facility',
          403,
          'BOOKING_CREATE_FORBIDDEN_OUT_OF_SCOPE'
        );
      }
      return;
    }

    if (this._isAdminRole(actor.role)) return;

    throw this._businessError(
      'Forbidden: Unsupported booking create role',
      403,
      'FORBIDDEN'
    );
  }

  _assertCustomerOwnsBooking(booking, actor) {
    const bookingUserId = booking.user_id?._id?.toString() || booking.user_id?.toString();
    if (!actor || actor.role !== 'CUSTOMER' || bookingUserId !== actor.id) {
      throw this._businessError('Forbidden: You can only update your own bookings', 403, 'FORBIDDEN');
    }
  }

  _assertCustomerCanCancel(booking, now = new Date()) {
    if (booking.status !== BOOKING_STATUSES.CONFIRMED) return;

    const startAt = getBookingStartAt(booking);
    if (startAt && now >= startAt) {
      throw this._businessError(CUSTOMER_CANCEL_STARTED_MESSAGE, 400, 'BOOKING_ALREADY_STARTED');
    }

    if (isWithinHoursBeforeStart(booking, 2, now)) {
      throw this._businessError(CUSTOMER_CANCEL_BLOCK_MESSAGE, 400, 'CANCEL_TOO_CLOSE_TO_START');
    }
  }

  _assertCustomerCanReschedule(booking, now = new Date()) {
    const startAt = getBookingStartAt(booking);
    if (startAt && now >= startAt) {
      throw this._businessError(
        CUSTOMER_CANCEL_STARTED_MESSAGE,
        400,
        'BOOKING_ALREADY_STARTED'
      );
    }
    if (
      booking.status === BOOKING_STATUSES.CONFIRMED &&
      isWithinHoursBeforeStart(booking, 2, now)
    ) {
      throw this._businessError(CUSTOMER_RESCHEDULE_BLOCK_MESSAGE, 400, 'RESCHEDULE_TOO_CLOSE_TO_START');
    }
  }

  async queryBookings(filters, skip = 0, limit = 20, actor = null) {
    const safeFilters = {
      facilityId: this._optionalObjectIdFilter(
        filters.facilityId,
        'facilityId'
      ),
      courtId: this._optionalObjectIdFilter(filters.courtId, 'courtId'),
      userId: this._optionalObjectIdFilter(filters.userId, 'userId'),
      status: this._optionalStringFilter(filters.status, 'status'),
      bookingDate: this._optionalDateFilter(
        filters.bookingDate,
        'bookingDate'
      ),
      dateFrom: this._optionalDateFilter(filters.dateFrom, 'dateFrom'),
      dateTo: this._optionalDateFilter(filters.dateTo, 'dateTo'),
      view: filters.view === 'report' ? 'report' : null
    };
    if (
      safeFilters.status &&
      !Object.values(BOOKING_STATUSES).includes(safeFilters.status)
    ) {
      throw this._businessError(
        'Invalid status filter',
        400,
        'INVALID_FILTER'
      );
    }
    if (
      safeFilters.dateFrom &&
      safeFilters.dateTo &&
      safeFilters.dateFrom > safeFilters.dateTo
    ) {
      throw this._businessError(
        'dateFrom must be before or equal to dateTo',
        400,
        'INVALID_FILTER'
      );
    }

    const scope = await this._resolveReadScope(actor, safeFilters.facilityId);
    const pageSkip = Math.max(parseInt(skip, 10) || 0, 0);
    const pageLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 500);

    if (scope.type === 'CUSTOMER') {
      return await this._queryCustomerBookingCalendar(
        { ...safeFilters, userId: scope.userId },
        pageSkip,
        pageLimit
      );
    }

    const query = {};
    if (scope.type === 'ADMIN' && safeFilters.userId) {
      query.user_id = safeFilters.userId;
    }
    if (safeFilters.status) query.status = safeFilters.status;
    if (safeFilters.bookingDate) query.booking_date = safeFilters.bookingDate;
    if (safeFilters.dateFrom || safeFilters.dateTo) {
      query.booking_date = {};
      if (safeFilters.dateFrom) query.booking_date.$gte = safeFilters.dateFrom;
      if (safeFilters.dateTo) query.booking_date.$lte = safeFilters.dateTo;
    }

    let allowedCourtIds = null;
    if (scope.facilityIds.length > 0) {
      allowedCourtIds = await this._courtIdsForFacilities(scope.facilityIds);
      query.court_id = { $in: allowedCourtIds };
    }

    if (safeFilters.courtId) {
      if (
        allowedCourtIds &&
        !allowedCourtIds.some(id => id.toString() === safeFilters.courtId)
      ) {
        throw this._businessError(
          'Forbidden: Court is outside your assigned facility',
          403,
          'FORBIDDEN'
        );
      }
      query.court_id = safeFilters.courtId;
    }

    const [bookings, total] = await Promise.all([
      bookingRepository.findMany(query, pageSkip, pageLimit),
      bookingRepository.count(query)
    ]);
    const privacyMode = this._privacyMode(actor, safeFilters);
    const bookingIds = bookings.map(booking => booking._id).filter(Boolean);
    const matchingSessions = bookingIds.length > 0
      ? await MatchingSession.find({ booking_id: { $in: bookingIds } })
        .select('_id booking_id host_id payment_policy fixed_schedule_id members')
      : [];
    const sessionByBookingId = new Map();
    for (const session of matchingSessions) {
      const bookingId = session.booking_id?._id?.toString()
        || session.booking_id?.toString();
      if (!bookingId) continue;
      sessionByBookingId.set(bookingId, session);
    }

    return {
      items: bookings.map(b => {
        const matchingSession = sessionByBookingId.get(b._id.toString());
        const matchingContext = matchingSession ? {
          sessionId: matchingSession._id.toString(),
          isHost: false,
          paymentPolicy: matchingSession.payment_policy || 'HOST_PAY_ALL',
          membersCount: matchingSession.members.filter(member => member.status === 'APPROVED').length
        } : null;
        return this._formatBookingResponse(b, null, matchingContext, privacyMode);
      }),
      total: total
    };
  }

  async _queryCustomerBookingCalendar(filters, skip = 0, limit = 20) {
    const pageSkip = parseInt(skip) || 0;
    const pageLimit = parseInt(limit) || 20;
    const bookingQuery = { user_id: filters.userId };
    if (filters.courtId) bookingQuery.court_id = filters.courtId;
    if (filters.status) bookingQuery.status = filters.status;
    if (filters.bookingDate) bookingQuery.booking_date = filters.bookingDate;

    const directBookings = await bookingRepository.findMany(bookingQuery, 0, 10000);

    const matchingSessions = await MatchingSession.find({
      booking_id: { $ne: null },
      $or: [
        { host_id: filters.userId },
        {
          members: {
            $elemMatch: {
              user_id: filters.userId,
              status: 'APPROVED'
            }
          }
        }
      ]
    })
      .populate('booking_id')
      .sort({ created_at: -1 });

    const matchingBookingIds = matchingSessions
      .map(session => session.booking_id?._id || session.booking_id)
      .filter(Boolean);

    const matchingBookingQuery = { _id: { $in: matchingBookingIds } };
    if (filters.courtId) matchingBookingQuery.court_id = filters.courtId;
    if (filters.status) matchingBookingQuery.status = filters.status;
    if (filters.bookingDate) matchingBookingQuery.booking_date = filters.bookingDate;

    const matchingBookings = matchingBookingIds.length > 0
      ? await bookingRepository.findMany(matchingBookingQuery, 0, 10000)
      : [];

    const sessionByBookingId = new Map();
    for (const session of matchingSessions) {
      const bookingId = session.booking_id?._id?.toString() || session.booking_id?.toString();
      if (bookingId) sessionByBookingId.set(bookingId, session);
    }

    const bookingById = new Map();
    for (const booking of [...directBookings, ...matchingBookings]) {
      bookingById.set(booking._id.toString(), booking);
    }

    const items = [];
    for (const booking of bookingById.values()) {
      const matchingSession = sessionByBookingId.get(booking._id.toString());
      const myPayment = await paymentService.queryMyPaymentForBooking(
        booking._id,
        filters.userId
      );

      let matchingContext = null;
      if (matchingSession) {
        const hostId = matchingSession.host_id?._id?.toString()
          || matchingSession.host_id?.toString();
        matchingContext = {
          sessionId: matchingSession._id.toString(),
          isHost: hostId === filters.userId,
          paymentPolicy: matchingSession.payment_policy || 'HOST_PAY_ALL',
          myPaymentStatus: myPayment?.status || null,
          myPaymentAmount: myPayment?.amount ?? null,
          membersCount: matchingSession.members.filter(member => member.status === 'APPROVED').length
        };
      }

      items.push(this._formatBookingResponse(booking, myPayment, matchingContext));
    }

    items.sort((a, b) => {
      const dateCompare = String(b.bookingDate || '').localeCompare(String(a.bookingDate || ''));
      if (dateCompare !== 0) return dateCompare;
      return (b.startMinutes || 0) - (a.startMinutes || 0);
    });

    return {
      items: items.slice(pageSkip, pageSkip + pageLimit),
      total: items.length
    };
  }

  async createBooking(data, userId, actor = null) {
    if (actor?.role === 'CUSTOMER') {
      const autoCancelAt = getBookingAutoCancelAt({
        booking_date: data.bookingDate,
        start_minutes: data.startMinutes
      });

      if (!autoCancelAt || new Date() >= autoCancelAt) {
        throw this._businessError(
          CUSTOMER_BOOKING_LEAD_TIME_MESSAGE,
          400,
          'BOOKING_TOO_CLOSE_TO_START'
        );
      }
    }

    const court = await courtAvailabilityService.loadCourt(data.courtId);
    await this._assertCreateBookingScope(court, userId, actor);

    if (userId) {
      await userScheduleConflictService.assertNoUserScheduleConflict(userId, {
        bookingDate: data.bookingDate,
        startMinutes: data.startMinutes,
        endMinutes: data.endMinutes
      });
    }

    await courtAvailabilityService.assertAvailable({
      courtId: data.courtId,
      bookingDate: data.bookingDate,
      startMinutes: data.startMinutes,
      endMinutes: data.endMinutes,
      court
    });

    // 1. Kiểm tra xem sân có đang bị đặt trùng bởi một Booking khác không
    const conflictingBooking = await Booking.findOne({
      court_id: data.courtId,
      booking_date: data.bookingDate,
      status: { $in: [BOOKING_STATUSES.PENDING, BOOKING_STATUSES.CONFIRMED] },
      $nor: [
        { start_minutes: { $gte: data.endMinutes } },
        { end_minutes: { $lte: data.startMinutes } }
      ]
    });

    if (conflictingBooking) {
      throw new Error('Sân đã bị đặt vào khung giờ này bởi một lịch chơi khác');
    }

    // 2. Kiểm tra xem có trùng với Lịch cố định (Giờ chết) nào đang ACTIVE không
    const conflictingSchedule = await fixedScheduleService.checkBookingConflict(
      data.courtId,
      data.bookingDate,
      data.startMinutes,
      data.endMinutes
    );

    if (conflictingSchedule) {
      throw this._businessError(
        'Slot này đã thuộc lịch cố định, không thể đặt',
        409,
        'ACTIVE_FIXED_SCHEDULE_CONFLICT'
      );
    }

    const totalPrice = bookingPriceService.calculateBookingPrice(
      court,
      data.startMinutes,
      data.endMinutes
    );

    const bookingData = {
      user_id: userId,
      guest_name: userId ? null : data.guestName,
      guest_phone: userId ? null : data.guestPhone,
      court_id: data.courtId,
      booking_date: data.bookingDate,
      start_minutes: data.startMinutes,
      end_minutes: data.endMinutes,
      total_price: totalPrice,
      status: BOOKING_STATUSES.PENDING
    };

    let newBooking = await bookingRepository.create(bookingData);
    newBooking = await bookingRepository.findById(newBooking._id);

    // Gửi thông báo tự động (bọc trong try/catch để tránh gián đoạn tiến trình chính)
    try {
      await notificationHelper.notifyBookingCreated(newBooking);
    } catch (err) {
      console.error('Failed to send booking created notification:', err);
    }

    return { booking: this._formatBookingResponse(newBooking) };
  }

  async getBookingDetail(id, actor = null) {
    const booking = await bookingRepository.findById(id);
    if (!booking) {
      throw this._businessError(
        'Booking not found',
        404,
        'BOOKING_NOT_FOUND'
      );
    }
    await this._assertCanReadBooking(booking, actor);
    const payment = await paymentService.queryPaymentByBookingId(booking._id);
    const matchingSession = await MatchingSession.findOne({ booking_id: booking._id })
      .select('_id host_id payment_policy fixed_schedule_id members');
    const actorId = actor?.id?.toString();
    const hostId = matchingSession?.host_id?._id?.toString()
      || matchingSession?.host_id?.toString();
    const matchingContext = matchingSession ? {
      sessionId: matchingSession._id.toString(),
      isHost: actorId ? hostId === actorId : false,
      paymentPolicy: matchingSession.payment_policy || 'HOST_PAY_ALL',
      membersCount: matchingSession.members.filter(member => member.status === 'APPROVED').length
    } : null;
    return {
      booking: this._formatBookingResponse(
        booking,
        payment,
        matchingContext,
        this._privacyMode(actor)
      )
    };
  }

  async updateBookingStatus(id, status, actor = null) {
    const validStatuses = Object.values(BOOKING_STATUSES);
    if (!validStatuses.includes(status)) {
      throw new Error('Invalid status');
    }

    const existingBooking = await bookingRepository.findById(id);
    if (!existingBooking) throw new Error('Booking not found');
    await this._assertStaffFacilityScope(existingBooking, actor);
    const linkedMatchingSession = await MatchingSession.findOne({ booking_id: existingBooking._id })
      .select('_id');

    if (status === BOOKING_STATUSES.CONFIRMED && existingBooking.user_id) {
      await userScheduleConflictService.assertNoUserScheduleConflict(
        existingBooking.user_id._id || existingBooking.user_id,
        {
          bookingDate: existingBooking.booking_date,
          startMinutes: existingBooking.start_minutes,
          endMinutes: existingBooking.end_minutes
        },
        {
          excludeBookingId: existingBooking._id,
          excludeMatchingSessionId: linkedMatchingSession?._id
        }
      );
    }

    const updates = { status };
    if (status === BOOKING_STATUSES.CANCELLED) {
      updates.cancel_reason = CANCEL_REASONS.STAFF_OR_ADMIN_REQUESTED;
      updates.cancelled_by = actor?.role === 'ADMIN' ? CANCELLED_BY.ADMIN : CANCELLED_BY.STAFF;
      updates.cancelled_at = new Date();
    }

    const updatedBooking = await bookingRepository.updateById(id, updates);
    if (!updatedBooking) throw new Error('Booking not found');

    let payment = null;
    if (
      status === BOOKING_STATUSES.CONFIRMED &&
      updatedBooking.user_id
    ) {
      payment = await paymentService.createPendingPaymentIfMissing({
        bookingId: updatedBooking._id,
        userId: updatedBooking.user_id._id || updatedBooking.user_id,
        amount: updatedBooking.total_price || 0
      });
    } else if (status === BOOKING_STATUSES.CANCELLED) {
      payment = await paymentService.syncPaymentOnBookingCancelled(
        updatedBooking._id
      );
    }

    // Gửi thông báo tự động (bọc trong try/catch để tránh gián đoạn tiến trình chính)
    try {
      if (status === BOOKING_STATUSES.CONFIRMED) {
        await notificationHelper.notifyBookingApproved(updatedBooking);
      } else if (status === BOOKING_STATUSES.CANCELLED) {
        await notificationHelper.notifyBookingCancelled(updatedBooking);
      }
    } catch (err) {
      console.error(`Failed to send booking status notification for status ${status}:`, err);
    }

    return {
      booking: this._formatBookingResponse(updatedBooking, payment)
    };
  }

  async cancelBooking(id, actor) {
    const booking = await bookingRepository.findById(id);
    if (!booking) {
      throw this._businessError('Booking not found', 404, 'BOOKING_NOT_FOUND');
    }

    if (actor?.role === 'CUSTOMER') {
      this._assertCustomerOwnsBooking(booking, actor);
      this._assertCustomerCanCancel(booking);
    } else if (actor?.role === 'STAFF' || actor?.role === 'ADMIN') {
      await this._assertStaffFacilityScope(booking, actor);
    } else {
      throw this._businessError(
        'Bạn không có quyền hủy booking này.',
        403,
        'FORBIDDEN'
      );
    }

    if (![BOOKING_STATUSES.PENDING, BOOKING_STATUSES.CONFIRMED].includes(booking.status)) {
      throw this._businessError('Không thể hủy booking ở trạng thái hiện tại.', 400, 'INVALID_BOOKING_STATUS');
    }

    const cancelledBy = actor.role === 'ADMIN'
      ? CANCELLED_BY.ADMIN
      : actor.role === 'STAFF'
        ? CANCELLED_BY.STAFF
        : CANCELLED_BY.CUSTOMER;
    const cancelReason = actor.role === 'CUSTOMER'
      ? CANCEL_REASONS.CUSTOMER_REQUESTED
      : CANCEL_REASONS.STAFF_OR_ADMIN_REQUESTED;

    const updatedBooking = await bookingRepository.cancelIfStatusMatches(
      id,
      booking.status,
      {
        status: BOOKING_STATUSES.CANCELLED,
        cancel_reason: cancelReason,
        cancelled_by: cancelledBy,
        cancelled_at: new Date()
      },
      actor.role === 'CUSTOMER' ? actor.id : null
    );

    if (!updatedBooking) {
      throw this._businessError(
        'Không thể hủy đơn đặt sân vì trạng thái đã thay đổi. Vui lòng tải lại thông tin đặt sân.',
        409,
        'BOOKING_STATUS_CHANGED'
      );
    }

    const payment = await paymentService.syncPaymentOnBookingCancelled(
      updatedBooking._id
    );

    try {
      const cancellationLabel = actor.role === 'CUSTOMER'
        ? 'Khách hàng yêu cầu hủy'
        : `${actor.role} yêu cầu hủy`;
      await notificationHelper.notifyBookingCancelled(updatedBooking, cancellationLabel);
    } catch (err) {
      console.error('Failed to send customer cancel notification:', err);
    }

    return {
      booking: this._formatBookingResponse(updatedBooking, payment),
      paymentStatus: payment?.status || null,
      occurrenceOnly: Boolean(
        updatedBooking.is_fixed_schedule && updatedBooking.fixed_schedule_id
      )
    };
  }

  async updateBooking(id, data, actor) {
    const booking = await bookingRepository.findById(id);
    if (!booking) throw new Error('Booking not found');

    const rescheduleFields = ['bookingDate', 'booking_date', 'startMinutes', 'start_minutes', 'endMinutes', 'end_minutes', 'courtId', 'court_id'];
    const isReschedule = rescheduleFields.some(field => Object.prototype.hasOwnProperty.call(data, field));
    if (!isReschedule) {
      throw this._businessError(
        'No supported booking update fields were provided',
        400,
        'NO_UPDATE_FIELDS'
      );
    }

    if (actor?.role === 'CUSTOMER') {
      this._assertCustomerOwnsBooking(booking, actor);
      if (isReschedule) {
        this._assertCustomerCanReschedule(booking);
      }
    }

    await this._assertStaffFacilityScope(booking, actor);

    if (
      booking.status === BOOKING_STATUSES.CANCELLED ||
      booking.status === BOOKING_STATUSES.COMPLETED
    ) {
      throw this._businessError(
        'Only active bookings can be rescheduled',
        400,
        'BOOKING_NOT_ACTIVE'
      );
    }

    const courtId = data.courtId || data.court_id || booking.court_id?._id || booking.court_id;
    const bookingDate = data.bookingDate || data.booking_date || booking.booking_date;
    const startMinutes = data.startMinutes ?? data.start_minutes ?? booking.start_minutes;
    const endMinutes = data.endMinutes ?? data.end_minutes ?? booking.end_minutes;
    const start = Number(startMinutes);
    const end = Number(endMinutes);

    if (!mongoose.isValidObjectId(courtId)) {
      throw this._businessError('Invalid courtId', 400, 'INVALID_COURT_ID');
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(bookingDate))) {
      throw this._businessError('Invalid bookingDate', 400, 'INVALID_BOOKING_DATE');
    }
    if (
      !Number.isInteger(start) ||
      !Number.isInteger(end) ||
      start < 0 ||
      end > 24 * 60 ||
      start >= end
    ) {
      throw this._businessError('Invalid booking time range', 400, 'INVALID_TIME_RANGE');
    }

    if (actor?.role === 'CUSTOMER') {
      const autoCancelAt = getBookingAutoCancelAt({
        booking_date: bookingDate,
        start_minutes: start
      });
      if (!autoCancelAt || new Date() >= autoCancelAt) {
        throw this._businessError(
          CUSTOMER_BOOKING_LEAD_TIME_MESSAGE,
          400,
          'BOOKING_TOO_CLOSE_TO_START'
        );
      }
    }

    const court = await courtAvailabilityService.loadCourt(courtId);
    await this._assertCreateBookingScope(court, booking.user_id, actor);

    if (booking.user_id) {
      await userScheduleConflictService.assertNoUserScheduleConflict(
        booking.user_id._id || booking.user_id,
        {
          bookingDate,
          startMinutes: start,
          endMinutes: end
        },
        { excludeBookingId: booking._id }
      );
    }

    await courtAvailabilityService.assertAvailable({
      courtId,
      bookingDate,
      startMinutes: start,
      endMinutes: end,
      court
    });

    const conflictingBooking = await Booking.findOne({
      _id: { $ne: booking._id },
      court_id: courtId,
      booking_date: bookingDate,
      status: { $in: [BOOKING_STATUSES.PENDING, BOOKING_STATUSES.CONFIRMED] },
      $nor: [
        { start_minutes: { $gte: end } },
        { end_minutes: { $lte: start } }
      ]
    });

    if (conflictingBooking) {
      throw this._businessError(
        'Sân đã bị đặt vào khung giờ này bởi một lịch chơi khác',
        409,
        'BOOKING_TIME_CONFLICT'
      );
    }

    const conflictingSchedule = await fixedScheduleService.checkBookingConflict(
      courtId,
      bookingDate,
      start,
      end
    );

    if (conflictingSchedule) {
      throw this._businessError(
        'Slot này đã thuộc lịch cố định, không thể đặt',
        409,
        'ACTIVE_FIXED_SCHEDULE_CONFLICT'
      );
    }

    const totalPrice = bookingPriceService.calculateBookingPrice(
      court,
      start,
      end
    );

    const updatedBooking = await bookingRepository.updateById(booking._id, {
      court_id: courtId,
      booking_date: bookingDate,
      start_minutes: start,
      end_minutes: end,
      total_price: totalPrice
    });

    return { booking: this._formatBookingResponse(updatedBooking) };
  }

  async autoCancelPendingBookings(now = new Date()) {
    const scanUntil = new Date(
      now.getTime() + AUTO_CANCEL_LEAD_MINUTES * 60 * 1000
    );
    const scanUntilDateStr = toLocalDateString(scanUntil);
    const pendingBookings = await Booking.find({
      status: BOOKING_STATUSES.PENDING,
      booking_date: { $lte: scanUntilDateStr }
    })
      .populate('user_id')
      .populate({
        path: 'court_id',
        populate: { path: 'facility_id' }
      });

    const matchingBookingIds = new Set(
      (
        await MatchingSession.find({
          booking_id: { $in: pendingBookings.map(booking => booking._id) },
          status: { $in: ['OPEN', 'FULL'] }
        }).distinct('booking_id')
      ).map(id => id.toString())
    );

    let cancelledCount = 0;

    for (const booking of pendingBookings) {
      if (matchingBookingIds.has(booking._id.toString())) continue;
      const autoCancelAt = getBookingAutoCancelAt(booking);
      if (!autoCancelAt || now < autoCancelAt) continue;

      const updatedBooking = await Booking.findOneAndUpdate(
        { _id: booking._id, status: BOOKING_STATUSES.PENDING },
        {
          status: BOOKING_STATUSES.CANCELLED,
          cancel_reason: CANCEL_REASONS.AUTO_CANCEL_STAFF_NOT_APPROVED,
          cancelled_by: CANCELLED_BY.SYSTEM,
          cancelled_at: now
        },
        { new: true }
      )
        .populate('user_id')
        .populate({
          path: 'court_id',
          populate: { path: 'facility_id' }
        });

      if (!updatedBooking) continue;
      cancelledCount += 1;

      await paymentService.syncPaymentOnBookingCancelled(updatedBooking._id);

      try {
        await notificationHelper.notifyBookingAutoCancelled(updatedBooking);
      } catch (err) {
        console.error(`Failed to send auto-cancel notification for booking ${booking._id}:`, err);
      }
    }

    return { scannedCount: pendingBookings.length, cancelledCount };
  }

  async autoCompleteFinishedBookings(now = new Date()) {
    const todayStr = toLocalDateString(now);
    const confirmedBookings = await Booking.find({
      status: BOOKING_STATUSES.CONFIRMED,
      booking_date: { $lte: todayStr }
    }).select('_id booking_date end_minutes');

    let completedBookingCount = 0;
    let completedMatchingSessionCount = 0;

    for (const booking of confirmedBookings) {
      const endAt = getBookingEndAt(booking);
      if (!endAt || now < endAt) continue;

      const updatedBooking = await Booking.findOneAndUpdate(
        { _id: booking._id, status: BOOKING_STATUSES.CONFIRMED },
        { status: BOOKING_STATUSES.COMPLETED },
        { new: true }
      ).select('_id');

      if (!updatedBooking) continue;
      completedBookingCount += 1;

      const matchingResult = await MatchingSession.updateMany(
        {
          booking_id: updatedBooking._id,
          status: { $in: ['OPEN', 'FULL'] }
        },
        { status: 'COMPLETED' }
      );

      completedMatchingSessionCount += matchingResult.modifiedCount || 0;
    }

    return {
      scannedCount: confirmedBookings.length,
      completedBookingCount,
      completedMatchingSessionCount
    };
  }
}

module.exports = new BookingService();
