const Court = require('../models/court.model');
const CourtBlock = require('../models/court-block.model');

const AVAILABILITY_ERROR_CODES = new Set([
  'COURT_NOT_FOUND',
  'COURT_INACTIVE',
  'COURT_MAINTENANCE',
  'SLOT_NOT_AVAILABLE',
  'COURT_BLOCKED',
  'OUTSIDE_OPERATING_HOURS',
  'INVALID_BOOKING_TIME'
]);

class CourtAvailabilityService {
  _businessError(message, statusCode, code) {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  _withSession(query, session) {
    return session ? query.session(session) : query;
  }

  _dateAtMinutes(dateString, minutes) {
    const date = new Date(`${dateString}T00:00:00`);
    date.setMinutes(minutes);
    return date;
  }

  _mergeIntervals(intervals) {
    const sorted = intervals
      .filter(interval => interval.end > interval.start)
      .sort((a, b) => a.start - b.start);
    const merged = [];

    for (const interval of sorted) {
      const last = merged[merged.length - 1];
      if (!last || interval.start > last.end) {
        merged.push({ ...interval });
      } else {
        last.end = Math.max(last.end, interval.end);
      }
    }
    return merged;
  }

  _isFullyCovered(startMinutes, endMinutes, intervals) {
    const merged = this._mergeIntervals(intervals);
    return merged.some(interval => (
      startMinutes >= interval.start && endMinutes <= interval.end
    ));
  }

  async loadCourt(courtId, session = null) {
    return await this._withSession(Court.findById(courtId), session);
  }

  assertCourtConfiguration(court, startMinutes, endMinutes) {
    if (!court) {
      throw this._businessError(
        'Không tìm thấy sân.',
        404,
        'COURT_NOT_FOUND'
      );
    }
    if (court.status === 'MAINTENANCE') {
      throw this._businessError(
        'Sân đang bảo trì.',
        409,
        'COURT_MAINTENANCE'
      );
    }
    if (court.status !== 'ACTIVE') {
      throw this._businessError(
        'Sân đang tạm ngưng.',
        409,
        'COURT_INACTIVE'
      );
    }
    if (
      !Number.isInteger(startMinutes)
      || !Number.isInteger(endMinutes)
      || startMinutes < 0
      || endMinutes > 1440
      || startMinutes >= endMinutes
    ) {
      throw this._businessError(
        'Khung giờ đặt sân không hợp lệ.',
        400,
        'INVALID_BOOKING_TIME'
      );
    }

    const opening = court.slot_config?.opening_minutes;
    const closing = court.slot_config?.closing_minutes;
    if (
      Number.isFinite(opening)
      && Number.isFinite(closing)
      && (startMinutes < opening || endMinutes > closing)
    ) {
      throw this._businessError(
        'Khung giờ nằm ngoài giờ hoạt động của sân.',
        409,
        'OUTSIDE_OPERATING_HOURS'
      );
    }

    const configuredSlots = (court.slot_config?.slots || []).filter(slot => (
      Number.isFinite(slot.start_minutes)
      && Number.isFinite(slot.end_minutes)
      && slot.end_minutes > slot.start_minutes
    ));
    if (configuredSlots.length === 0) return;

    const availableSlots = configuredSlots
      .filter(slot => (
        slot.is_available !== false && slot.mode !== 'UNAVAILABLE'
      ))
      .map(slot => ({
        start: slot.start_minutes,
        end: slot.end_minutes
      }));
    if (!this._isFullyCovered(startMinutes, endMinutes, availableSlots)) {
      throw this._businessError(
        'Khung giờ này không khả dụng.',
        409,
        'SLOT_NOT_AVAILABLE'
      );
    }
  }

  async assertAvailable({
    courtId,
    bookingDate,
    startMinutes,
    endMinutes,
    session = null,
    court = null
  }) {
    const resolvedCourt = court || await this.loadCourt(courtId, session);
    this.assertCourtConfiguration(
      resolvedCourt,
      startMinutes,
      endMinutes
    );

    const bookingStart = this._dateAtMinutes(bookingDate, startMinutes);
    const bookingEnd = this._dateAtMinutes(bookingDate, endMinutes);
    if (
      Number.isNaN(bookingStart.getTime())
      || Number.isNaN(bookingEnd.getTime())
    ) {
      throw this._businessError(
        'Ngày đặt sân không hợp lệ.',
        400,
        'INVALID_BOOKING_TIME'
      );
    }

    const facilityId = resolvedCourt.facility_id?._id
      || resolvedCourt.facility_id;
    const blockQuery = CourtBlock.findOne({
      facility_id: facilityId,
      status: 'ACTIVE',
      start_time: { $lt: bookingEnd },
      end_time: { $gt: bookingStart },
      $or: [
        { court_id: null },
        { court_id: resolvedCourt._id }
      ]
    });
    const block = await this._withSession(blockQuery, session);
    if (block) {
      throw this._businessError(
        'Khung giờ này đã bị khóa.',
        409,
        'COURT_BLOCKED'
      );
    }

    return resolvedCourt;
  }

  isAvailabilityError(error) {
    return AVAILABILITY_ERROR_CODES.has(error?.code);
  }
}

module.exports = new CourtAvailabilityService();
