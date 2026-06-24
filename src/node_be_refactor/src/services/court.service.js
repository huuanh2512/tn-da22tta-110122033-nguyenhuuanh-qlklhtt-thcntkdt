const crypto = require('crypto');
const mongoose = require('mongoose');
const courtRepository = require('../repositories/court.repository');
const bookingRepository = require('../repositories/booking.repository');
const fixedScheduleRepository = require('../repositories/fixed-schedule.repository');
const CourtBlock = require('../models/court-block.model');
const { getDayOfWeekFromDateString } = require('../utils/booking-time.util');
const { toLocalDateString } = require('../utils/booking-time.util');

class CourtService {
  _businessError(message, statusCode = 400, code = 'COURT_ERROR') {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  _objectId(value, name, required = false) {
    if (value === undefined || value === null || value === '') {
      if (required) {
        throw this._businessError(`${name} is required`, 400, 'MISSING_FIELDS');
      }
      return null;
    }

    if (typeof value !== 'string') {
      throw this._businessError(`Invalid ${name}`, 400, 'INVALID_ID');
    }

    const normalized = value.trim();
    if (!mongoose.isValidObjectId(normalized)) {
      throw this._businessError(`Invalid ${name}`, 400, 'INVALID_ID');
    }

    return normalized;
  }

  _generateCourtCode() {
    const timestamp = Date.now().toString(36).toUpperCase();
    const suffix = crypto.randomBytes(2).toString('hex').toUpperCase();
    return `COURT-${timestamp}-${suffix}`;
  }

  _formatCourtResponse(court) {
    return {
      id: court._id.toString(),
      name: court.name,
      code: court.code || '',
      status: court.status,
      pricePerHour: court.price_per_hour || 0,
      facility: court.facility_id ? {
        id: court.facility_id._id?.toString() || court.facility_id.toString(),
        name: court.facility_id.name || ''
      } : null,
      sport: court.sport_id ? {
        id: court.sport_id._id?.toString() || court.sport_id.toString(),
        name: court.sport_id.name || ''
      } : null,
      createdAt: court.created_at ? new Date(court.created_at).toISOString() : null
    };
  }

  _isValidDateString(value) {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return false;
    }
    const [year, month, day] = value.split('-').map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));
    return date.getUTCFullYear() === year
      && date.getUTCMonth() === month - 1
      && date.getUTCDate() === day;
  }

  _hasTimeOverlap(slot, block) {
    return slot.start_minutes < block.end_minutes
      && slot.end_minutes > block.start_minutes;
  }

  _fixedScheduleAppliesOnDate(schedule, bookingDate) {
    if (schedule.frequency === 'DAILY') return true;
    if (schedule.frequency !== 'WEEKLY') return false;
    const dayOfWeek = getDayOfWeekFromDateString(bookingDate);
    return dayOfWeek !== null && schedule.days_of_week.includes(dayOfWeek);
  }

  _dateAtMinutes(dateString, minutes) {
    const date = new Date(`${dateString}T00:00:00`);
    date.setMinutes(minutes);
    return date;
  }

  _slotOverlapsBlock(slot, block, bookingDate) {
    const slotStart = this._dateAtMinutes(bookingDate, slot.start_minutes);
    const slotEnd = this._dateAtMinutes(bookingDate, slot.end_minutes);
    return slotStart < block.end_time && slotEnd > block.start_time;
  }

  _formatSlotConfigResponse(court, availability = null) {
    const bookings = availability?.bookings || [];
    const fixedSchedules = availability?.fixedSchedules || [];
    const courtBlocks = availability?.courtBlocks || [];
    const bookingDate = availability?.bookingDate || null;

    return {
      courtId: court._id.toString(),
      bookingDate,
      openingMinutes: court.slot_config?.opening_minutes || 0,
      closingMinutes: court.slot_config?.closing_minutes || 0,
      slotDurationMinutes: court.slot_config?.slot_duration_minutes || 0,
      slots: (court.slot_config?.slots || []).map((slot, index) => {
        const configuredAvailable = typeof slot.is_available === 'boolean'
          ? slot.is_available
          : slot.mode === 'AVAILABLE';
        const hasBooking = bookingDate
          ? bookings.some(booking => this._hasTimeOverlap(slot, booking))
          : false;
        const hasFixedSchedule = bookingDate
          ? fixedSchedules.some(schedule =>
            this._fixedScheduleAppliesOnDate(schedule, bookingDate)
            && this._hasTimeOverlap(slot, schedule)
          )
          : false;
        const hasCourtBlock = bookingDate
          ? courtBlocks.some(block => this._slotOverlapsBlock(slot, block, bookingDate))
          : false;

        let status = configuredAvailable ? 'AVAILABLE' : 'UNAVAILABLE';
        let reason = configuredAvailable ? null : 'Khung giờ này hiện không khả dụng';
        let blockType = configuredAvailable ? null : 'COURT_CONFIG';

        if (court.status === 'MAINTENANCE') {
          status = 'UNAVAILABLE';
          reason = 'Sân đang bảo trì';
          blockType = 'COURT_MAINTENANCE';
        } else if (court.status !== 'ACTIVE') {
          status = 'UNAVAILABLE';
          reason = 'Sân đang tạm ngưng';
          blockType = 'COURT_INACTIVE';
        } else if (configuredAvailable && hasCourtBlock) {
          status = 'BLOCKED';
          reason = 'Khung giờ này đã bị khóa';
          blockType = 'COURT_BLOCK';
        } else if (configuredAvailable && hasBooking) {
          status = 'BOOKED';
          reason = 'Khung giờ này đã có người đặt';
          blockType = 'BOOKING';
        } else if (configuredAvailable && hasFixedSchedule) {
          status = 'FIXED_SCHEDULE_RESERVED';
          reason = 'Khung giờ này đã được giữ bởi lịch cố định';
          blockType = 'FIXED_SCHEDULE';
        }

        return {
          slotIndex: slot.slot_index || index + 1,
          startMinutes: slot.start_minutes,
          endMinutes: slot.end_minutes,
          isAvailable: status === 'AVAILABLE',
          mode: slot.mode,
          status,
          reason,
          blockType
        };
      }),
      updatedAt: court.slot_config?.updated_at ? new Date(court.slot_config.updated_at).toISOString() : null
    };
  }

  async queryCourts(filters, skip = 0, limit = 20) {
    const query = {};
    const facilityId = this._objectId(filters.facilityId, 'facilityId');
    const sportId = this._objectId(filters.sportId, 'sportId');
    
    if (facilityId) query.facility_id = facilityId;
    if (sportId) query.sport_id = sportId;
    if (filters.status) query.status = filters.status;

    const [courts, total] = await Promise.all([
      courtRepository.findMany(query, parseInt(skip), parseInt(limit)),
      courtRepository.count(query)
    ]);

    return {
      items: courts.map(c => this._formatCourtResponse(c)),
      total: total
    };
  }

  async createCourt(data) {
    const facilityId = this._objectId(data.facilityId, 'facilityId', true);
    const sportId = this._objectId(data.sportId, 'sportId', true);
    const courtData = {
      name: data.name,
      facility_id: facilityId,
      sport_id: sportId,
      code: data.code || this._generateCourtCode(),
      status: data.status || 'ACTIVE',
      price_per_hour: data.pricePerHour || 0
    };

    let newCourt = await courtRepository.create(courtData);
    newCourt = await courtRepository.findById(newCourt._id); // Lấy lại để có populate
    return { court: this._formatCourtResponse(newCourt) };
  }

  async updateCourt(id, data) {
    const updateData = {};
    const existingCourt = await courtRepository.findById(id);
    if (!existingCourt) throw new Error('Court not found');
    let warning = null;
    
    if (data.name !== undefined) updateData.name = data.name;
    if (data.code !== undefined) updateData.code = data.code;
    if (data.facilityId !== undefined) {
      updateData.facility_id = this._objectId(data.facilityId, 'facilityId');
    }
    if (data.sportId !== undefined) {
      updateData.sport_id = this._objectId(data.sportId, 'sportId');
    }
    if (data.status !== undefined) updateData.status = data.status;
    if (data.pricePerHour !== undefined) updateData.price_per_hour = data.pricePerHour;

    if (
      existingCourt.status === 'ACTIVE'
      && ['INACTIVE', 'MAINTENANCE'].includes(data.status)
    ) {
      const now = new Date();
      const bookingSummary =
        await bookingRepository.findFutureBlockingBookingSummary(
          id,
          toLocalDateString(now),
          now.getHours() * 60 + now.getMinutes()
        );
      if (bookingSummary.futureBookingCount > 0) {
        warning = {
          code: 'COURT_STATUS_AFFECTS_FUTURE_BOOKINGS',
          message:
            'Sân có booking tương lai đang chờ hoặc đã xác nhận. '
            + 'Các booking này không bị tự động hủy.',
          ...bookingSummary
        };
      }
    }

    const updatedCourt = await courtRepository.updateById(id, updateData);
    
    return {
      court: this._formatCourtResponse(updatedCourt),
      warning
    };
  }

  async deleteCourt(id) {
    const deleted = await courtRepository.deleteById(id);
    if (!deleted) throw new Error('Court not found');
    return true;
  }

  async getCourtSlotConfig(id, bookingDate = null) {
    const court = await courtRepository.findById(id);
    if (!court) throw new Error('Court not found');

    if (!bookingDate) {
      return { config: this._formatSlotConfigResponse(court) };
    }

    if (!this._isValidDateString(bookingDate)) {
      const error = new Error('Booking date must use YYYY-MM-DD format');
      error.statusCode = 400;
      error.code = 'INVALID_BOOKING_DATE';
      throw error;
    }

    const facilityId = court.facility_id?._id || court.facility_id;
    const dayStart = this._dateAtMinutes(bookingDate, 0);
    const dayEnd = this._dateAtMinutes(bookingDate, 1440);
    const [bookings, fixedSchedules, courtBlocks] = await Promise.all([
      bookingRepository.findBlockingBookingsForCourtDate(id, bookingDate),
      fixedScheduleRepository.findActiveForCourtDate({
        facilityId,
        courtId: id,
        bookingDate
      }),
      CourtBlock.find({
        facility_id: facilityId,
        status: 'ACTIVE',
        start_time: { $lt: dayEnd },
        end_time: { $gt: dayStart },
        $or: [
          { court_id: null },
          { court_id: id }
        ]
      })
    ]);

    return {
      config: this._formatSlotConfigResponse(court, {
        bookingDate,
        bookings,
        fixedSchedules,
        courtBlocks
      })
    };
  }

  async upsertCourtSlotConfig(id, data) {
    const updateData = {
      slot_config: {
        opening_minutes: data.openingMinutes,
        closing_minutes: data.closingMinutes,
        slot_duration_minutes: data.slotDurationMinutes,
        slots: (data.slots || []).map(slot => ({
          slot_index: slot.slotIndex,
          start_minutes: slot.startMinutes,
          end_minutes: slot.endMinutes,
          is_available: slot.isAvailable !== false,
          mode: slot.isAvailable === false ? 'UNAVAILABLE' : 'AVAILABLE'
        }))
      }
    };

    const updatedCourt = await courtRepository.updateById(id, updateData);
    if (!updatedCourt) throw new Error('Court not found');
    
    return { config: this._formatSlotConfigResponse(updatedCourt) };
  }
}

module.exports = new CourtService();
