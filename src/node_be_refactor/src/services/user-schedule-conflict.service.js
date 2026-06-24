const Booking = require('../models/booking.model');
const MatchingSession = require('../models/matching.model');
const MatchQueue = require('../models/match-queue.model');
const FixedSchedule = require('../models/fixed-schedule.model');

const USER_SCHEDULE_CONFLICT_CODE = 'USER_SCHEDULE_CONFLICT';
const USER_SCHEDULE_CONFLICT_MESSAGE =
  'Bạn đã có lịch trong khung giờ này. Vui lòng chọn khung giờ khác hoặc hủy lịch cũ.';

const ACTIVE_BOOKING_STATUSES = ['PENDING', 'CONFIRMED'];
const ACTIVE_MATCHING_STATUSES = ['OPEN', 'FULL'];
const ACTIVE_MATCHING_MEMBER_STATUSES = ['PENDING', 'APPROVED'];
const ACTIVE_QUEUE_STATUSES = ['SEARCHING', 'MATCHED'];
const ACTIVE_FIXED_SCHEDULE_STATUSES = ['PENDING_APPROVAL', 'ACTIVE', 'PAUSED'];
const ACTIVE_FIXED_MATCHING_MEMBER_STATUSES = ['INVITED', 'APPROVED'];
const ALL_DAYS_OF_WEEK = [0, 1, 2, 3, 4, 5, 6];
const OPEN_END_DATE = '9999-12-31';

function businessError(message, statusCode = 409, code = USER_SCHEDULE_CONFLICT_CODE) {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.code = code;
  return error;
}

function overlapsTime(startA, endA, startB, endB) {
  return Number(startA) < Number(endB) && Number(endA) > Number(startB);
}

function normalizeDateRange(startDate, endDate = null) {
  return {
    startDate,
    endDate: endDate || OPEN_END_DATE
  };
}

function rangesOverlap(startA, endA, startB, endB) {
  const a = normalizeDateRange(startA, endA);
  const b = normalizeDateRange(startB, endB);
  return a.startDate <= b.endDate && b.startDate <= a.endDate;
}

function dayOfWeekFromDateString(dateStr) {
  const [year, month, day] = String(dateStr).split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day)).getUTCDay();
}

function scheduleDays(schedule) {
  if (schedule.frequency === 'DAILY') return ALL_DAYS_OF_WEEK;
  return Array.isArray(schedule.days_of_week)
    ? [...new Set(schedule.days_of_week.map(Number))]
    : [];
}

function recurrenceDays(input) {
  if (input.frequency === 'DAILY') return ALL_DAYS_OF_WEEK;
  return Array.isArray(input.daysOfWeek || input.days_of_week)
    ? [...new Set((input.daysOfWeek || input.days_of_week).map(Number))]
    : [];
}

function hasCommonDay(daysA, daysB) {
  return daysA.some(day => daysB.includes(day));
}

function scheduleOccursOnDate(schedule, dateStr) {
  if (!rangesOverlap(schedule.start_date, schedule.end_date, dateStr, dateStr)) return false;
  if (schedule.frequency === 'DAILY') return true;
  return scheduleDays(schedule).includes(dayOfWeekFromDateString(dateStr));
}

function recurrenceOccursOnDate(recurrence, dateStr) {
  if (!rangesOverlap(recurrence.startDate, recurrence.endDate, dateStr, dateStr)) return false;
  if (recurrence.frequency === 'DAILY') return true;
  return recurrenceDays(recurrence).includes(dayOfWeekFromDateString(dateStr));
}

function fixedSchedulesConflict(a, b) {
  return rangesOverlap(a.startDate, a.endDate, b.start_date, b.end_date)
    && overlapsTime(a.startMinutes, a.endMinutes, b.start_minutes, b.end_minutes)
    && hasCommonDay(recurrenceDays(a), scheduleDays(b));
}

function notIdQuery(field, id) {
  return id ? { [field]: { $ne: id } } : {};
}

class UserScheduleConflictService {
  get conflictCode() {
    return USER_SCHEDULE_CONFLICT_CODE;
  }

  get conflictMessage() {
    return USER_SCHEDULE_CONFLICT_MESSAGE;
  }

  throwConflict() {
    throw businessError(USER_SCHEDULE_CONFLICT_MESSAGE);
  }

  async assertNoUserScheduleConflict(userId, slot, options = {}) {
    const conflict = await this.checkUserScheduleConflict(userId, slot, options);
    if (conflict) this.throwConflict();
    return null;
  }

  async assertNoUserFixedScheduleConflict(userId, recurrence, options = {}) {
    const conflict = await this.checkUserFixedScheduleConflict(userId, recurrence, options);
    if (conflict) this.throwConflict();
    return null;
  }

  async checkUserScheduleConflict(userId, slot, options = {}) {
    if (!userId) return null;
    const session = options.session || null;
    const { bookingDate, startMinutes, endMinutes } = slot;
    const overlapQuery = {
      booking_date: bookingDate,
      start_minutes: { $lt: endMinutes },
      end_minutes: { $gt: startMinutes }
    };

    const booking = await Booking.findOne({
      user_id: userId,
      status: { $in: ACTIVE_BOOKING_STATUSES },
      ...overlapQuery,
      ...notIdQuery('_id', options.excludeBookingId)
    }).session(session);
    if (booking) return { type: 'BOOKING', item: booking };

    const matching = await MatchingSession.findOne({
      status: { $in: ACTIVE_MATCHING_STATUSES },
      ...overlapQuery,
      ...notIdQuery('_id', options.excludeMatchingSessionId),
      $or: [
        { host_id: userId },
        {
          members: {
            $elemMatch: {
              user_id: userId,
              status: { $in: ACTIVE_MATCHING_MEMBER_STATUSES }
            }
          }
        }
      ]
    }).session(session);
    if (matching) return { type: 'MATCHING_SESSION', item: matching };

    const queue = await MatchQueue.findOne({
      user_id: userId,
      status: { $in: ACTIVE_QUEUE_STATUSES },
      ...overlapQuery,
      ...notIdQuery('_id', options.excludeQueueId)
    }).session(session);
    if (queue) return { type: 'MATCH_QUEUE', item: queue };

    const fixedSchedules = await FixedSchedule.find({
      status: { $in: ACTIVE_FIXED_SCHEDULE_STATUSES },
      start_date: { $lte: bookingDate },
      start_minutes: { $lt: endMinutes },
      end_minutes: { $gt: startMinutes },
      ...notIdQuery('_id', options.excludeFixedScheduleId),
      $or: [
        { end_date: null },
        { end_date: { $gte: bookingDate } }
      ],
      $and: [
        {
          $or: [
            { user_id: userId },
            {
              'matching_config.members': {
                $elemMatch: {
                  user_id: userId,
                  status: { $in: ACTIVE_FIXED_MATCHING_MEMBER_STATUSES }
                }
              }
            }
          ]
        }
      ]
    }).session(session);

    const fixedSchedule = fixedSchedules.find(schedule =>
      scheduleOccursOnDate(schedule, bookingDate)
    );
    if (fixedSchedule) return { type: 'FIXED_SCHEDULE', item: fixedSchedule };

    return null;
  }

  async checkUserFixedScheduleConflict(userId, recurrence, options = {}) {
    if (!userId) return null;
    const session = options.session || null;
    const normalized = {
      startDate: recurrence.startDate,
      endDate: recurrence.endDate || null,
      startMinutes: recurrence.startMinutes,
      endMinutes: recurrence.endMinutes,
      frequency: recurrence.frequency,
      daysOfWeek: recurrence.daysOfWeek || recurrence.days_of_week || []
    };
    const endBoundary = normalized.endDate || OPEN_END_DATE;

    const bookingQuery = {
      user_id: userId,
      status: { $in: ACTIVE_BOOKING_STATUSES },
      booking_date: { $gte: normalized.startDate, $lte: endBoundary },
      start_minutes: { $lt: normalized.endMinutes },
      end_minutes: { $gt: normalized.startMinutes },
      ...notIdQuery('_id', options.excludeBookingId)
    };
    const bookings = await Booking.find(bookingQuery).session(session);
    const booking = bookings.find(item => recurrenceOccursOnDate(normalized, item.booking_date));
    if (booking) return { type: 'BOOKING', item: booking };

    const matchingQuery = {
      status: { $in: ACTIVE_MATCHING_STATUSES },
      booking_date: { $gte: normalized.startDate, $lte: endBoundary },
      start_minutes: { $lt: normalized.endMinutes },
      end_minutes: { $gt: normalized.startMinutes },
      ...notIdQuery('_id', options.excludeMatchingSessionId),
      $or: [
        { host_id: userId },
        {
          members: {
            $elemMatch: {
              user_id: userId,
              status: { $in: ACTIVE_MATCHING_MEMBER_STATUSES }
            }
          }
        }
      ]
    };
    const matchingSessions = await MatchingSession.find(matchingQuery).session(session);
    const matching = matchingSessions.find(item => recurrenceOccursOnDate(normalized, item.booking_date));
    if (matching) return { type: 'MATCHING_SESSION', item: matching };

    const queueQuery = {
      user_id: userId,
      status: { $in: ACTIVE_QUEUE_STATUSES },
      booking_date: { $gte: normalized.startDate, $lte: endBoundary },
      start_minutes: { $lt: normalized.endMinutes },
      end_minutes: { $gt: normalized.startMinutes },
      ...notIdQuery('_id', options.excludeQueueId)
    };
    const queues = await MatchQueue.find(queueQuery).session(session);
    const queue = queues.find(item => recurrenceOccursOnDate(normalized, item.booking_date));
    if (queue) return { type: 'MATCH_QUEUE', item: queue };

    const fixedQuery = {
      status: { $in: ACTIVE_FIXED_SCHEDULE_STATUSES },
      start_minutes: { $lt: normalized.endMinutes },
      end_minutes: { $gt: normalized.startMinutes },
      start_date: normalized.endDate ? { $lte: normalized.endDate } : { $lte: OPEN_END_DATE },
      ...notIdQuery('_id', options.excludeFixedScheduleId),
      $or: [
        { end_date: null },
        { end_date: { $gte: normalized.startDate } }
      ],
      $and: [
        {
          $or: [
            { user_id: userId },
            {
              'matching_config.members': {
                $elemMatch: {
                  user_id: userId,
                  status: { $in: ACTIVE_FIXED_MATCHING_MEMBER_STATUSES }
                }
              }
            }
          ]
        }
      ]
    };
    const fixedSchedules = await FixedSchedule.find(fixedQuery).session(session);
    const fixedSchedule = fixedSchedules.find(schedule =>
      fixedSchedulesConflict(normalized, schedule)
    );
    if (fixedSchedule) return { type: 'FIXED_SCHEDULE', item: fixedSchedule };

    return null;
  }
}

module.exports = new UserScheduleConflictService();
