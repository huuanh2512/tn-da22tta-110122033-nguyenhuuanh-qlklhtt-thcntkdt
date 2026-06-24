const crypto = require('crypto');
const Booking = require('../models/booking.model');
const Payment = require('../models/payment.model');
const CourtBlock = require('../models/court-block.model');
const Court = require('../models/court.model');
const User = require('../models/user.model');
const bookingService = require('./booking.service');

const ACTIVE_BOOKING_STATUSES = ['CONFIRMED', 'COMPLETED'];
const ALL_BOOKING_STATUSES = ['PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED'];
const MAX_REPORT_DAYS = 366;
const ADVANCED_REPORT_SECTIONS = [
  'summary',
  'sportStats',
  'courtStats',
  'facilityStats',
  'dailyStats',
  'weekdayStats',
  'peakHours',
  'customerStats'
];

class ReportService {
  _businessError(message, statusCode = 400, code = 'INVALID_REPORT_FILTER') {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  _formatDate(date) {
    return [
      date.getFullYear(),
      String(date.getMonth() + 1).padStart(2, '0'),
      String(date.getDate()).padStart(2, '0')
    ].join('-');
  }

  _parseDate(value, name) {
    if (!value) return null;
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw this._businessError(`Invalid ${name}`, 400, 'INVALID_DATE_RANGE');
    }
    const date = new Date(`${value}T00:00:00`);
    if (Number.isNaN(date.getTime()) || this._formatDate(date) !== value) {
      throw this._businessError(`Invalid ${name}`, 400, 'INVALID_DATE_RANGE');
    }
    return date;
  }

  _resolveDateRange(dateFromValue, dateToValue) {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const dateTo = this._parseDate(dateToValue, 'dateTo') || today;
    const dateFrom = this._parseDate(dateFromValue, 'dateFrom')
      || new Date(dateTo.getFullYear(), dateTo.getMonth(), dateTo.getDate() - 29);

    if (dateFrom > dateTo) {
      throw this._businessError(
        'dateFrom must be before or equal to dateTo',
        400,
        'INVALID_DATE_RANGE'
      );
    }

    const dayCount = Math.floor((dateTo - dateFrom) / 86400000) + 1;
    if (dayCount > MAX_REPORT_DAYS) {
      throw this._businessError(
        `Report date range cannot exceed ${MAX_REPORT_DAYS} days`,
        400,
        'REPORT_RANGE_TOO_LARGE'
      );
    }

    return {
      dateFrom: this._formatDate(dateFrom),
      dateTo: this._formatDate(dateTo),
      dayCount
    };
  }

  _maskName(name) {
    if (!name) return 'Guest';
    const value = String(name).trim();
    if (!value) return 'Guest';
    return `${value.slice(0, Math.min(3, value.length))}***`;
  }

  _maskPhone(phone) {
    const normalized = this._normalizePhone(phone);
    if (!normalized) return '';
    if (normalized.length <= 6) return `${normalized.slice(0, 2)}***`;
    return `${normalized.slice(0, 3)}****${normalized.slice(-3)}`;
  }

  _maskEmail(email) {
    const normalized = this._normalizeEmail(email);
    if (!normalized) return '';
    const [local, domain] = normalized.split('@');
    if (!domain) return this._maskName(normalized);
    return `${local.slice(0, Math.min(4, local.length))}***@${domain}`;
  }

  _normalizePhone(phone) {
    if (!phone) return '';
    let value = String(phone).trim().replace(/[\s.\-()]/g, '');
    if (!value) return '';
    if (value.startsWith('+84')) value = `0${value.slice(3)}`;
    if (value.startsWith('84') && value.length >= 10) value = `0${value.slice(2)}`;
    return value;
  }

  _normalizeEmail(email) {
    return email ? String(email).trim().toLowerCase() : '';
  }

  _normalizeName(name) {
    return name ? String(name).trim().toLowerCase().replace(/\s+/g, ' ') : '';
  }

  _hashCustomerKey(rawKey) {
    return crypto.createHash('sha256').update(rawKey).digest('hex').slice(0, 16);
  }

  _isAdminRole(role) {
    return role === 'ADMIN' || role === 'SUPER_ADMIN';
  }

  _normalizeId(value) {
    return value?._id?.toString() || value?.toString() || null;
  }

  _parseObjectId(value, name) {
    if (value === undefined || value === null || value === '') return null;
    const normalized = String(value).trim();
    if (!/^[a-fA-F0-9]{24}$/.test(normalized)) {
      throw this._businessError(`Invalid ${name}`, 400, 'INVALID_REPORT_FILTER');
    }
    return normalized;
  }

  _parseObjectIdList(value, name) {
    if (value === undefined || value === null || value === '') return [];
    const values = Array.isArray(value)
      ? value
      : String(value).split(',');
    const ids = values
      .map(item => this._parseObjectId(item, name))
      .filter(Boolean);
    return [...new Set(ids)];
  }

  _parseIncludes(value) {
    if (!value) return new Set(ADVANCED_REPORT_SECTIONS);
    const requested = String(value)
      .split(',')
      .map(item => item.trim())
      .filter(Boolean);
    for (const section of requested) {
      if (!ADVANCED_REPORT_SECTIONS.includes(section)) {
        throw this._businessError(
          `Invalid include section: ${section}`,
          400,
          'INVALID_REPORT_FILTER'
        );
      }
    }
    return new Set(requested);
  }

  _parseStatusFilter(value) {
    if (!value) return null;
    const normalized = String(value).trim().toUpperCase();
    if (!ALL_BOOKING_STATUSES.includes(normalized)) {
      throw this._businessError(
        'Invalid status filter',
        400,
        'INVALID_REPORT_FILTER'
      );
    }
    return normalized;
  }

  _customerIdentity(booking) {
    if (booking.user_id) {
      const userName = booking.user_id?.profile?.name;
      return {
        customerKey: this._hashCustomerKey(
          `user:${this._normalizeId(booking.user_id)}`
        ),
        customerType: 'USER',
        displayName: userName ? String(userName).trim() : 'Khách hàng'
      };
    }

    const normalizedPhone = this._normalizePhone(booking.guest_phone);
    if (normalizedPhone) {
      return {
        customerKey: this._hashCustomerKey(`guest-phone:${normalizedPhone}`),
        customerType: 'GUEST',
        displayName: booking.guest_name
          ? this._maskName(booking.guest_name)
          : this._maskPhone(normalizedPhone)
      };
    }

    const normalizedEmail = this._normalizeEmail(booking.guest_email);
    if (normalizedEmail) {
      return {
        customerKey: this._hashCustomerKey(`guest-email:${normalizedEmail}`),
        customerType: 'GUEST',
        displayName: booking.guest_name
          ? this._maskName(booking.guest_name)
          : this._maskEmail(normalizedEmail)
      };
    }

    const normalizedName = this._normalizeName(booking.guest_name);
    if (normalizedName) {
      return {
        customerKey: this._hashCustomerKey(`guest-name:${normalizedName}`),
        customerType: 'GUEST',
        displayName: this._maskName(booking.guest_name)
      };
    }

    return {
      customerKey: this._hashCustomerKey(`guest-booking:${booking._id}`),
      customerType: 'GUEST',
      displayName: 'Guest'
    };
  }

  _availableMinutesPerDay(court) {
    const slots = court.slot_config?.slots || [];
    const availableSlots = slots.filter(slot => (
      slot.is_available !== false && slot.mode !== 'UNAVAILABLE'
    ));
    if (availableSlots.length > 0) {
      return availableSlots.reduce(
        (total, slot) => total + Math.max(
          0,
          (slot.end_minutes || 0) - (slot.start_minutes || 0)
        ),
        0
      );
    }

    const opening = court.slot_config?.opening_minutes;
    const closing = court.slot_config?.closing_minutes;
    if (Number.isFinite(opening) && Number.isFinite(closing) && closing > opening) {
      return closing - opening;
    }
    return 0;
  }

  _mergeIntervals(intervals) {
    const sorted = intervals
      .filter(interval => interval.end > interval.start)
      .sort((a, b) => a.start - b.start);
    const merged = [];

    for (const interval of sorted) {
      const last = merged[merged.length - 1];
      if (!last || interval.start > last.end) {
        merged.push({ start: interval.start, end: interval.end });
      } else if (interval.end > last.end) {
        last.end = interval.end;
      }
    }
    return merged;
  }

  _intervalMinutes(intervals) {
    return intervals.reduce(
      (total, interval) => total + (interval.end - interval.start) / 60000,
      0
    );
  }

  _dateAtMinutes(date, minutes) {
    return new Date(
      date.getFullYear(),
      date.getMonth(),
      date.getDate(),
      Math.floor(minutes / 60),
      minutes % 60
    );
  }

  _operatingIntervals(court, dateRange) {
    const intervals = [];
    const cursor = new Date(`${dateRange.dateFrom}T00:00:00`);
    const lastDate = new Date(`${dateRange.dateTo}T00:00:00`);
    const configuredSlots = (court.slot_config?.slots || []).filter(slot => (
      slot.is_available !== false
      && slot.mode !== 'UNAVAILABLE'
      && Number.isFinite(slot.start_minutes)
      && Number.isFinite(slot.end_minutes)
      && slot.end_minutes > slot.start_minutes
    ));

    while (cursor <= lastDate) {
      if (configuredSlots.length > 0) {
        for (const slot of configuredSlots) {
          intervals.push({
            start: this._dateAtMinutes(cursor, slot.start_minutes).getTime(),
            end: this._dateAtMinutes(cursor, slot.end_minutes).getTime()
          });
        }
      } else {
        const opening = court.slot_config?.opening_minutes;
        const closing = court.slot_config?.closing_minutes;
        if (
          Number.isFinite(opening)
          && Number.isFinite(closing)
          && closing > opening
        ) {
          intervals.push({
            start: this._dateAtMinutes(cursor, opening).getTime(),
            end: this._dateAtMinutes(cursor, closing).getTime()
          });
        }
      }
      cursor.setDate(cursor.getDate() + 1);
    }
    return this._mergeIntervals(intervals);
  }

  _reportBounds(dateRange) {
    const start = new Date(`${dateRange.dateFrom}T00:00:00`);
    const end = new Date(`${dateRange.dateTo}T00:00:00`);
    end.setDate(end.getDate() + 1);
    return { start, end };
  }

  async _loadCourtBlocks(facilityIds, courtIds, bounds) {
    if (facilityIds.length === 0 || courtIds.length === 0) return [];
    return await CourtBlock.find({
      facility_id: { $in: facilityIds },
      status: 'ACTIVE',
      start_time: { $lt: bounds.end },
      end_time: { $gt: bounds.start },
      $or: [
        { court_id: null },
        { court_id: { $in: courtIds } }
      ]
    })
      .select('_id facility_id court_id start_time end_time type')
      .lean();
  }

  _unavailableSummary(court, operatingIntervals, blocks) {
    const courtId = court._id.toString();
    const facilityId = this._normalizeId(court.facility_id);
    const applicableBlocks = blocks.filter(block => (
      this._normalizeId(block.facility_id) === facilityId
      && (!block.court_id || this._normalizeId(block.court_id) === courtId)
    ));
    const intersections = [];
    const intersectingBlockIds = new Set();

    for (const block of applicableBlocks) {
      const blockStart = new Date(block.start_time).getTime();
      const blockEnd = new Date(block.end_time).getTime();
      for (const operating of operatingIntervals) {
        const start = Math.max(blockStart, operating.start);
        const end = Math.min(blockEnd, operating.end);
        if (start < end) {
          intersections.push({ start, end });
          intersectingBlockIds.add(block._id.toString());
        }
      }
    }

    const mergedUnavailable = this._mergeIntervals(intersections);
    return {
      unavailableIntervals: mergedUnavailable,
      unavailableMinutes: this._intervalMinutes(mergedUnavailable),
      blockCount: intersectingBlockIds.size,
      blockIds: [...intersectingBlockIds]
    };
  }

  _bookingInterval(booking) {
    const date = new Date(`${booking.booking_date}T00:00:00`);
    return {
      start: this._dateAtMinutes(date, booking.start_minutes || 0).getTime(),
      end: this._dateAtMinutes(date, booking.end_minutes || 0).getTime()
    };
  }

  _overlapsAny(interval, intervals) {
    return intervals.some(other => (
      interval.start < other.end && interval.end > other.start
    ));
  }

  _peakBucket(startMinutes) {
    if (startMinutes < 720) return 'morning';
    if (startMinutes < 1020) return 'afternoon';
    return 'evening';
  }

  async _loadBookings(query) {
    return await Booking.find(query)
      .select(
        '_id user_id guest_name guest_phone court_id booking_date start_minutes '
        + 'end_minutes status'
      )
      .populate('user_id', 'profile.name')
      .lean();
  }

  async _loadPayments(bookingIds) {
    if (bookingIds.length === 0) return [];
    return await Payment.find({ booking_id: { $in: bookingIds } })
      .select('booking_id amount status updated_at')
      .lean();
  }

  async _resolveAdvancedScope(actor, filters) {
    if (!actor?.id || !actor?.role) {
      throw this._businessError('Unauthorized', 401, 'UNAUTHORIZED');
    }
    if (actor.role === 'CUSTOMER') {
      throw this._businessError(
        'Forbidden: Advanced performance reports are not available to customers',
        403,
        'FORBIDDEN'
      );
    }

    const facilityId = this._parseObjectId(filters.facilityId, 'facilityId');
    const facilityIds = this._parseObjectIdList(filters.facilityIds, 'facilityIds');
    const courtId = this._parseObjectId(filters.courtId, 'courtId');
    const sportId = this._parseObjectId(filters.sportId, 'sportId');

    if (actor.role === 'STAFF' && facilityIds.length > 0) {
      throw this._businessError(
        'Forbidden: Staff cannot request multi-facility reports',
        403,
        'FORBIDDEN'
      );
    }

    let scopeType = 'ADMIN';
    let allowedFacilityIds = [];
    if (actor.role === 'STAFF') {
      const staff = await User.findById(actor.id).select('facility_id');
      const staffFacilityId = this._normalizeId(staff?.facility_id);
      if (!staffFacilityId) {
        throw this._businessError(
          'Forbidden: Staff account has no assigned facility',
          403,
          'STAFF_FACILITY_SCOPE_REQUIRED'
        );
      }
      if (facilityId && facilityId !== staffFacilityId) {
        throw this._businessError(
          'Forbidden: Facility is outside your assigned scope',
          403,
          'FORBIDDEN'
        );
      }
      scopeType = 'STAFF';
      allowedFacilityIds = [staffFacilityId];
    } else if (!this._isAdminRole(actor.role)) {
      throw this._businessError(
        'Forbidden: Unsupported report access role',
        403,
        'FORBIDDEN'
      );
    } else {
      allowedFacilityIds = [...new Set([
        ...facilityIds,
        ...(facilityId ? [facilityId] : [])
      ])];
    }

    const courtQuery = {};
    if (allowedFacilityIds.length > 0) {
      courtQuery.facility_id = { $in: allowedFacilityIds };
    }
    if (courtId) courtQuery._id = courtId;
    if (sportId) courtQuery.sport_id = sportId;

    const courts = await Court.find(courtQuery)
      .select('name facility_id sport_id status slot_config')
      .populate('facility_id', 'name')
      .populate('sport_id', 'name')
      .lean();

    if (courtId && courts.length === 0) {
      if (scopeType === 'STAFF') {
        throw this._businessError(
          'Forbidden: Court is outside your assigned facility',
          403,
          'FORBIDDEN'
        );
      }
      throw this._businessError('Court not found', 404, 'COURT_NOT_FOUND');
    }

    return {
      type: scopeType,
      filters: { facilityId, facilityIds, courtId, sportId },
      facilityIds: [...new Set(courts.map(court => this._normalizeId(court.facility_id)))],
      courts
    };
  }

  _buildPaymentSummaries(bookings, payments) {
    const bookingById = new Map(
      bookings.map(booking => [booking._id.toString(), booking])
    );
    const paymentSummaryByBooking = new Map();
    const revenue = {
      paidRevenue: 0,
      pendingRevenue: 0,
      paidCancelledAmount: 0,
      refundPendingAmount: 0,
      refundedAmount: 0
    };

    for (const payment of payments) {
      const booking = bookingById.get(payment.booking_id.toString());
      if (!booking) continue;
      const amount = Number(payment.amount) || 0;
      const summary = paymentSummaryByBooking.get(booking._id.toString())
        || {
          paidRevenue: 0,
          pendingRevenue: 0,
          paidCancelledAmount: 0,
          refundPendingAmount: 0,
          refundedAmount: 0
        };

      if (payment.status === 'SUCCESS') {
        if (ACTIVE_BOOKING_STATUSES.includes(booking.status)) {
          revenue.paidRevenue += amount;
          summary.paidRevenue += amount;
        } else if (booking.status === 'CANCELLED') {
          revenue.paidCancelledAmount += amount;
          summary.paidCancelledAmount += amount;
        }
      } else if (
        payment.status === 'PENDING'
        && ACTIVE_BOOKING_STATUSES.includes(booking.status)
      ) {
        revenue.pendingRevenue += amount;
        summary.pendingRevenue += amount;
      } else if (payment.status === 'REFUND_PENDING') {
        revenue.refundPendingAmount += amount;
        summary.refundPendingAmount += amount;
      } else if (payment.status === 'REFUNDED') {
        revenue.refundedAmount += amount;
        summary.refundedAmount += amount;
      }
      paymentSummaryByBooking.set(booking._id.toString(), summary);
    }

    return { paymentSummaryByBooking, revenue };
  }

  _dateKeys(dateRange) {
    const keys = [];
    const cursor = new Date(`${dateRange.dateFrom}T00:00:00`);
    const lastDate = new Date(`${dateRange.dateTo}T00:00:00`);
    while (cursor <= lastDate) {
      keys.push(this._formatDate(cursor));
      cursor.setDate(cursor.getDate() + 1);
    }
    return keys;
  }

  _incrementStatus(target, status) {
    if (status === 'PENDING') target.pendingBookings += 1;
    if (status === 'CONFIRMED') target.confirmedBookings += 1;
    if (status === 'COMPLETED') target.completedBookings += 1;
    if (status === 'CANCELLED') target.cancelledBookings += 1;
  }

  _hourBucket(startMinutes) {
    const hour = Math.floor((startMinutes || 0) / 60);
    const nextHour = Math.min(hour + 1, 24);
    return {
      key: String(hour).padStart(2, '0'),
      label: `${String(hour).padStart(2, '0')}:00-${String(nextHour).padStart(2, '0')}:00`
    };
  }

  _emptyGroupStats(base) {
    return {
      ...base,
      totalBookings: 0,
      activeBookings: 0,
      pendingBookings: 0,
      confirmedBookings: 0,
      completedBookings: 0,
      cancelledBookings: 0,
      bookedMinutes: 0,
      baseAvailableMinutes: 0,
      availableMinutes: 0,
      unavailableMinutes: 0,
      paidRevenue: 0,
      pendingRevenue: 0,
      utilizationRate: 0,
      averagePaidRevenuePerActiveBooking: 0
    };
  }

  _finalizeGroupStats(stats) {
    return {
      ...stats,
      utilizationRate: stats.availableMinutes > 0
        ? stats.bookedMinutes / stats.availableMinutes
        : 0,
      averagePaidRevenuePerActiveBooking: stats.activeBookings > 0
        ? stats.paidRevenue / stats.activeBookings
        : 0
    };
  }

  async getAdvancedPerformance(filters, actor) {
    const dateRange = this._resolveDateRange(filters.dateFrom, filters.dateTo);
    const include = this._parseIncludes(filters.include);
    const statusFilter = this._parseStatusFilter(filters.status);
    const scope = await this._resolveAdvancedScope(actor, filters);
    const courtIds = scope.courts.map(court => court._id);
    const courtIdStrings = new Set(courtIds.map(String));
    const facilityIds = [...new Set(
      scope.courts
        .map(court => this._normalizeId(court.facility_id))
        .filter(Boolean)
    )];
    const reportBounds = this._reportBounds(dateRange);

    const bookingQuery = {
      court_id: { $in: courtIds },
      booking_date: {
        $gte: dateRange.dateFrom,
        $lte: dateRange.dateTo
      }
    };
    if (statusFilter) bookingQuery.status = statusFilter;

    const bookings = courtIds.length > 0
      ? await this._loadBookings(bookingQuery)
      : [];
    const payments = await this._loadPayments(
      bookings.map(booking => booking._id)
    );
    const courtBlocks = await this._loadCourtBlocks(
      facilityIds,
      courtIds,
      reportBounds
    );
    const { paymentSummaryByBooking, revenue } = this._buildPaymentSummaries(
      bookings,
      payments
    );

    const courtStatsById = new Map();
    const sportStatsById = new Map();
    const facilityStatsById = new Map();
    const dailyStatsByDate = new Map();
    const weekdayStatsByKey = new Map();
    const peakHoursByKey = new Map();
    const customerStatsByKey = new Map();
    const dateKeys = this._dateKeys(dateRange);
    const summary = {
      totalBookings: bookings.length,
      activeBookings: 0,
      pendingBookings: 0,
      confirmedBookings: 0,
      completedBookings: 0,
      cancelledBookings: 0,
      bookedMinutes: 0,
      baseAvailableMinutes: 0,
      availableMinutes: 0,
      unavailableMinutes: 0,
      blockCount: 0,
      ...revenue,
      utilizationRate: 0,
      averagePaidRevenuePerActiveBooking: 0,
      averageBookedMinutesPerActiveBooking: 0
    };

    for (const key of dateKeys) {
      const day = new Date(`${key}T00:00:00`);
      dailyStatsByDate.set(key, this._emptyGroupStats({
        date: key,
        weekday: day.getDay()
      }));
    }
    for (let weekday = 0; weekday < 7; weekday += 1) {
      weekdayStatsByKey.set(String(weekday), this._emptyGroupStats({ weekday }));
    }
    for (let hour = 0; hour < 24; hour += 1) {
      const label = `${String(hour).padStart(2, '0')}:00-${String(Math.min(hour + 1, 24)).padStart(2, '0')}:00`;
      peakHoursByKey.set(String(hour).padStart(2, '0'), {
        hour,
        label,
        bookingCount: 0,
        bookedMinutes: 0,
        paidRevenue: 0
      });
    }

    for (const court of scope.courts) {
      const courtId = court._id.toString();
      const facilityId = this._normalizeId(court.facility_id);
      const sportId = this._normalizeId(court.sport_id);
      const facilityName = court.facility_id?.name || '';
      const sportName = court.sport_id?.name || '';
      const operatingIntervals = this._operatingIntervals(court, dateRange);
      const baseAvailableMinutes = this._intervalMinutes(operatingIntervals);
      const blockUnavailable = this._unavailableSummary(
        court,
        operatingIntervals,
        courtBlocks
      );
      const isCourtUnavailable = (
        court.status === 'INACTIVE' || court.status === 'MAINTENANCE'
      );
      const unavailableIntervals = isCourtUnavailable
        ? operatingIntervals
        : blockUnavailable.unavailableIntervals;
      const unavailableMinutes = isCourtUnavailable
        ? baseAvailableMinutes
        : blockUnavailable.unavailableMinutes;
      const availableMinutes = Math.max(
        0,
        baseAvailableMinutes - unavailableMinutes
      );

      courtStatsById.set(courtId, this._emptyGroupStats({
        courtId,
        courtName: court.name || '',
        facilityId,
        facilityName,
        sportId,
        sportName,
        status: court.status || '',
        blockCount: blockUnavailable.blockCount,
        blockedBookingCount: 0,
        unavailableIntervals,
        isCourtUnavailable
      }));
      const courtStats = courtStatsById.get(courtId);
      courtStats.baseAvailableMinutes = baseAvailableMinutes;
      courtStats.availableMinutes = availableMinutes;
      courtStats.unavailableMinutes = unavailableMinutes;

      if (sportId && !sportStatsById.has(sportId)) {
        sportStatsById.set(sportId, this._emptyGroupStats({ sportId, sportName }));
      }
      if (facilityId && !facilityStatsById.has(facilityId)) {
        facilityStatsById.set(
          facilityId,
          this._emptyGroupStats({ facilityId, facilityName })
        );
      }
      const sportStats = sportStatsById.get(sportId);
      const facilityStats = facilityStatsById.get(facilityId);
      for (const target of [summary, sportStats, facilityStats].filter(Boolean)) {
        target.baseAvailableMinutes += baseAvailableMinutes;
        target.availableMinutes += availableMinutes;
        target.unavailableMinutes += unavailableMinutes;
      }
      summary.blockCount += blockUnavailable.blockCount;

      for (const dateKey of dateKeys) {
        const dayRange = { dateFrom: dateKey, dateTo: dateKey };
        const dayOperating = this._operatingIntervals(court, dayRange);
        const dayBase = this._intervalMinutes(dayOperating);
        const dayUnavailableSummary = this._unavailableSummary(
          court,
          dayOperating,
          courtBlocks
        );
        const dayUnavailable = isCourtUnavailable
          ? dayBase
          : dayUnavailableSummary.unavailableMinutes;
        const dayStats = dailyStatsByDate.get(dateKey);
        const weekdayStats = weekdayStatsByKey.get(
          String(new Date(`${dateKey}T00:00:00`).getDay())
        );
        for (const target of [dayStats, weekdayStats]) {
          target.baseAvailableMinutes += dayBase;
          target.availableMinutes += Math.max(0, dayBase - dayUnavailable);
          target.unavailableMinutes += dayUnavailable;
        }
      }
    }

    for (const booking of bookings) {
      const courtId = booking.court_id.toString();
      if (!courtIdStrings.has(courtId)) continue;
      const courtStats = courtStatsById.get(courtId);
      if (!courtStats) continue;
      const sportStats = sportStatsById.get(courtStats.sportId);
      const facilityStats = facilityStatsById.get(courtStats.facilityId);
      const bookingDate = booking.booking_date;
      const dailyStats = dailyStatsByDate.get(bookingDate);
      const weekday = new Date(`${bookingDate}T00:00:00`).getDay();
      const weekdayStats = weekdayStatsByKey.get(String(weekday));
      const paymentSummary = paymentSummaryByBooking.get(booking._id.toString())
        || { paidRevenue: 0, pendingRevenue: 0 };
      const active = ACTIVE_BOOKING_STATUSES.includes(booking.status);
      const duration = Math.max(
        0,
        (booking.end_minutes || 0) - (booking.start_minutes || 0)
      );
      const groupTargets = [
        summary,
        courtStats,
        sportStats,
        facilityStats,
        dailyStats,
        weekdayStats
      ].filter(Boolean);

      for (const target of groupTargets) {
        target.totalBookings += target === summary ? 0 : 1;
        this._incrementStatus(target, booking.status);
      }

      if (!active) continue;

      summary.activeBookings += 1;
      for (const target of groupTargets.filter(target => target !== summary)) {
        target.activeBookings += 1;
      }
      for (const target of groupTargets) {
        target.bookedMinutes += duration;
        if (target !== summary) {
          target.paidRevenue += paymentSummary.paidRevenue || 0;
          target.pendingRevenue += paymentSummary.pendingRevenue || 0;
        }
      }
      if (
        this._overlapsAny(
          this._bookingInterval(booking),
          courtStats.unavailableIntervals
        )
      ) {
        courtStats.blockedBookingCount += 1;
      }

      const peak = this._hourBucket(booking.start_minutes || 0);
      const peakStats = peakHoursByKey.get(peak.key);
      if (peakStats) {
        peakStats.bookingCount += 1;
        peakStats.bookedMinutes += duration;
        peakStats.paidRevenue += paymentSummary.paidRevenue || 0;
      }

      const identity = this._customerIdentity(booking);
      const customer = customerStatsByKey.get(identity.customerKey) || {
        ...identity,
        bookingCount: 0,
        bookedMinutes: 0,
        lastBookingAt: null,
        paidRevenue: 0
      };
      customer.bookingCount += 1;
      customer.bookedMinutes += duration;
      customer.paidRevenue += paymentSummary.paidRevenue || 0;
      const bookingAt = this._dateAtMinutes(
        new Date(`${booking.booking_date}T00:00:00`),
        booking.start_minutes || 0
      ).toISOString();
      if (!customer.lastBookingAt || bookingAt > customer.lastBookingAt) {
        customer.lastBookingAt = bookingAt;
      }
      customerStatsByKey.set(identity.customerKey, customer);
    }

    Object.assign(summary, {
      utilizationRate: summary.availableMinutes > 0
        ? summary.bookedMinutes / summary.availableMinutes
        : 0,
      averagePaidRevenuePerActiveBooking: summary.activeBookings > 0
        ? summary.paidRevenue / summary.activeBookings
        : 0,
      averageBookedMinutesPerActiveBooking: summary.activeBookings > 0
        ? summary.bookedMinutes / summary.activeBookings
        : 0
    });

    const report = {
      scope: {
        type: scope.type,
        facilityIds,
        courtIds: courtIds.map(String),
        isSystemWide: scope.type === 'ADMIN'
          && scope.filters.facilityIds.length === 0
          && !scope.filters.facilityId
          && !scope.filters.courtId
          && !scope.filters.sportId
      },
      dateRange,
      appliedFilters: {
        facilityId: scope.filters.facilityId,
        facilityIds: scope.filters.facilityIds,
        sportId: scope.filters.sportId,
        courtId: scope.filters.courtId,
        status: statusFilter
      },
      utilizationBasis: {
        method: 'BOOKED_MINUTES_OVER_NET_AVAILABLE_MINUTES',
        note: ''
      }
    };

    if (include.has('summary')) report.summary = summary;
    if (include.has('sportStats')) {
      report.sportStats = [...sportStatsById.values()]
        .map(stats => this._finalizeGroupStats(stats))
        .sort((a, b) => b.paidRevenue - a.paidRevenue);
    }
    if (include.has('courtStats')) {
      report.courtStats = [...courtStatsById.values()]
        .map(stats => {
          const {
            unavailableIntervals,
            isCourtUnavailable,
            ...publicStats
          } = stats;
          return {
            ...this._finalizeGroupStats(publicStats),
            utilizationNote: isCourtUnavailable
              ? `Court status is ${stats.status}; all configured operating minutes are unavailable.`
              : publicStats.availableMinutes <= 0
                ? 'No available operating minutes remain in this range.'
                : publicStats.blockedBookingCount > 0
                  ? `${publicStats.blockedBookingCount} active booking(s) overlap blocked time from historical data.`
                  : ''
          };
        })
        .sort((a, b) => b.paidRevenue - a.paidRevenue);
    }
    if (include.has('facilityStats')) {
      report.facilityStats = [...facilityStatsById.values()]
        .map(stats => this._finalizeGroupStats(stats))
        .sort((a, b) => b.paidRevenue - a.paidRevenue);
    }
    if (include.has('dailyStats')) {
      report.dailyStats = [...dailyStatsByDate.values()]
        .map(stats => this._finalizeGroupStats(stats));
    }
    if (include.has('weekdayStats')) {
      report.weekdayStats = [...weekdayStatsByKey.values()]
        .map(stats => this._finalizeGroupStats(stats));
    }
    if (include.has('peakHours')) {
      report.peakHours = [...peakHoursByKey.values()]
        .filter(stats => stats.bookingCount > 0)
        .sort((a, b) => a.hour - b.hour);
    }
    if (include.has('customerStats')) {
      report.customerStats = [...customerStatsByKey.values()]
        .sort((a, b) => (
          b.bookingCount - a.bookingCount
          || b.paidRevenue - a.paidRevenue
        ));
    }

    return report;
  }

  async getCourtPerformance(filters, actor) {
    const dateRange = this._resolveDateRange(filters.dateFrom, filters.dateTo);
    const scope = await bookingService.resolveCourtReportScope(actor, filters);
    const courtIds = scope.courts.map(court => court._id);
    const courtIdStrings = new Set(courtIds.map(String));
    const facilityIds = [...new Set(
      scope.courts.map(court => court.facility_id.toString())
    )];
    const reportBounds = this._reportBounds(dateRange);

    const bookingQuery = {
      court_id: { $in: courtIds },
      booking_date: {
        $gte: dateRange.dateFrom,
        $lte: dateRange.dateTo
      }
    };
    if (filters.status) {
      if (!['PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED'].includes(filters.status)) {
        throw this._businessError(
          'Invalid status filter',
          400,
          'INVALID_REPORT_FILTER'
        );
      }
      bookingQuery.status = filters.status;
    }

    const bookings = courtIds.length > 0
      ? await this._loadBookings(bookingQuery)
      : [];
    const payments = await this._loadPayments(
      bookings.map(booking => booking._id)
    );
    const courtBlocks = await this._loadCourtBlocks(
      facilityIds,
      courtIds,
      reportBounds
    );

    const bookingById = new Map(
      bookings.map(booking => [booking._id.toString(), booking])
    );
    const paymentSummaryByBooking = new Map();
    const revenue = {
      paidRevenue: 0,
      pendingRevenue: 0,
      paidCancelledAmount: 0,
      refundPendingAmount: 0,
      refundedAmount: 0
    };

    for (const payment of payments) {
      const booking = bookingById.get(payment.booking_id.toString());
      if (!booking) continue;
      const amount = Number(payment.amount) || 0;
      const summary = paymentSummaryByBooking.get(booking._id.toString())
        || { paidRevenue: 0 };

      if (payment.status === 'SUCCESS') {
        if (ACTIVE_BOOKING_STATUSES.includes(booking.status)) {
          revenue.paidRevenue += amount;
          summary.paidRevenue += amount;
        } else if (booking.status === 'CANCELLED') {
          revenue.paidCancelledAmount += amount;
        }
      } else if (
        payment.status === 'PENDING'
        && ACTIVE_BOOKING_STATUSES.includes(booking.status)
      ) {
        revenue.pendingRevenue += amount;
      } else if (payment.status === 'REFUND_PENDING') {
        revenue.refundPendingAmount += amount;
      } else if (payment.status === 'REFUNDED') {
        revenue.refundedAmount += amount;
      }

      paymentSummaryByBooking.set(booking._id.toString(), summary);
    }

    const counts = {
      totalBookings: bookings.length,
      totalActiveBookings: 0,
      pendingBookings: 0,
      confirmedBookings: 0,
      completedBookings: 0,
      cancelledBookings: 0
    };
    const peakHours = {
      morning: { label: 'Before 12:00', bookingCount: 0 },
      afternoon: { label: '12:00-17:00', bookingCount: 0 },
      evening: { label: 'After 17:00', bookingCount: 0 }
    };
    const courtStatsById = new Map();
    const customerStatsByKey = new Map();

    for (const court of scope.courts) {
      const sportId = this._normalizeId(court.sport_id);
      const sportName = court.sport_id?.name || '';
      const operatingIntervals = this._operatingIntervals(court, dateRange);
      const baseAvailableMinutes = this._intervalMinutes(operatingIntervals);
      const blockUnavailable = this._unavailableSummary(
        court,
        operatingIntervals,
        courtBlocks
      );
      const isCourtUnavailable = (
        court.status === 'INACTIVE' || court.status === 'MAINTENANCE'
      );
      const unavailableIntervals = isCourtUnavailable
        ? operatingIntervals
        : blockUnavailable.unavailableIntervals;
      const unavailableMinutes = isCourtUnavailable
        ? baseAvailableMinutes
        : blockUnavailable.unavailableMinutes;
      const availableMinutes = Math.max(
        0,
        baseAvailableMinutes - unavailableMinutes
      );
      courtStatsById.set(court._id.toString(), {
        courtId: court._id.toString(),
        courtName: court.name || '',
        sportId,
        sportName,
        status: court.status || '',
        activeBookings: 0,
        confirmedBookings: 0,
        completedBookings: 0,
        bookedMinutes: 0,
        baseAvailableMinutes,
        availableMinutes,
        unavailableMinutes,
        blockCount: blockUnavailable.blockCount,
        blockIds: blockUnavailable.blockIds,
        blockedBookingCount: 0,
        unavailableIntervals,
        isCourtUnavailable,
        utilizationRate: 0,
        bookingShareRate: 0,
        paidRevenue: 0
      });
    }

    for (const booking of bookings) {
      if (booking.status === 'PENDING') counts.pendingBookings += 1;
      if (booking.status === 'CONFIRMED') counts.confirmedBookings += 1;
      if (booking.status === 'COMPLETED') counts.completedBookings += 1;
      if (booking.status === 'CANCELLED') counts.cancelledBookings += 1;
      if (!ACTIVE_BOOKING_STATUSES.includes(booking.status)) continue;

      counts.totalActiveBookings += 1;
      const courtId = booking.court_id.toString();
      if (!courtIdStrings.has(courtId)) continue;
      const courtStats = courtStatsById.get(courtId);
      const duration = Math.max(
        0,
        (booking.end_minutes || 0) - (booking.start_minutes || 0)
      );
      courtStats.activeBookings += 1;
      courtStats.bookedMinutes += duration;
      if (
        this._overlapsAny(
          this._bookingInterval(booking),
          courtStats.unavailableIntervals
        )
      ) {
        courtStats.blockedBookingCount += 1;
      }
      courtStats.paidRevenue += (
        paymentSummaryByBooking.get(booking._id.toString())?.paidRevenue || 0
      );
      if (booking.status === 'CONFIRMED') courtStats.confirmedBookings += 1;
      if (booking.status === 'COMPLETED') courtStats.completedBookings += 1;

      peakHours[this._peakBucket(booking.start_minutes || 0)].bookingCount += 1;

      const identity = this._customerIdentity(booking);
      const customer = customerStatsByKey.get(identity.customerKey) || {
        ...identity,
        bookingCount: 0,
        bookedMinutes: 0,
        lastBookingAt: null,
        paidRevenue: 0
      };
      customer.bookingCount += 1;
      customer.bookedMinutes += duration;
      const bookingAt = this._dateAtMinutes(
        new Date(`${booking.booking_date}T00:00:00`),
        booking.start_minutes || 0
      ).toISOString();
      if (!customer.lastBookingAt || bookingAt > customer.lastBookingAt) {
        customer.lastBookingAt = bookingAt;
      }
      customer.paidRevenue += (
        paymentSummaryByBooking.get(booking._id.toString())?.paidRevenue || 0
      );
      customerStatsByKey.set(identity.customerKey, customer);
    }

    const courtStats = [...courtStatsById.values()].map(stats => {
      const {
        unavailableIntervals,
        blockIds,
        isCourtUnavailable,
        ...publicStats
      } = stats;
      return {
        ...publicStats,
        utilizationRate: stats.availableMinutes > 0
          ? stats.bookedMinutes / stats.availableMinutes
          : 0,
        bookingShareRate: counts.totalActiveBookings > 0
          ? stats.activeBookings / counts.totalActiveBookings
          : 0,
        utilizationNote: isCourtUnavailable
          ? `Court status is ${stats.status}; all configured operating minutes are unavailable.`
          : stats.availableMinutes <= 0
          ? 'No available operating minutes remain in this range.'
          : stats.blockedBookingCount > 0
            ? `${stats.blockedBookingCount} active booking(s) overlap blocked time from historical data.`
            : ''
      };
    });
    const customerStats = [...customerStatsByKey.values()]
      .sort((a, b) => (
        b.bookingCount - a.bookingCount
        || b.paidRevenue - a.paidRevenue
      ));
    const uniqueBlockIds = new Set(
      [...courtStatsById.values()].flatMap(stats => stats.blockIds)
    );
    const utilizationTotals = courtStats.reduce(
      (totals, stats) => ({
        baseAvailableMinutes:
          totals.baseAvailableMinutes + stats.baseAvailableMinutes,
        availableMinutes: totals.availableMinutes + stats.availableMinutes,
        unavailableMinutes:
          totals.unavailableMinutes + stats.unavailableMinutes,
        bookedMinutes: totals.bookedMinutes + stats.bookedMinutes
      }),
      {
        baseAvailableMinutes: 0,
        availableMinutes: 0,
        unavailableMinutes: 0,
        bookedMinutes: 0
      }
    );

    return {
      dateRange,
      appliedFilters: {
        facilityId: filters.facilityId || null,
        courtId: filters.courtId || null,
        sportId: filters.sportId || null,
        status: filters.status || null
      },
      ...counts,
      ...revenue,
      ...utilizationTotals,
      blockCount: uniqueBlockIds.size,
      utilizationRate: utilizationTotals.availableMinutes > 0
        ? utilizationTotals.bookedMinutes
          / utilizationTotals.availableMinutes
        : 0,
      courtStats,
      peakHours: Object.values(peakHours),
      customerStats,
      utilizationBasis: {
        method: 'BOOKED_MINUTES_OVER_NET_AVAILABLE_MINUTES',
        note: 'Available minutes use enabled court slots or opening/closing time, minus active facility/court blocks. INACTIVE and MAINTENANCE courts have zero net available minutes.'
      }
    };
  }
}

module.exports = new ReportService();
