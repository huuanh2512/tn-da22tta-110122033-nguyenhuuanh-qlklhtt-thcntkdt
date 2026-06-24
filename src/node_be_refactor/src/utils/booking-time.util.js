const BOOKING_STATUSES = Object.freeze({
  PENDING: 'PENDING',
  CONFIRMED: 'CONFIRMED',
  CANCELLED: 'CANCELLED',
  COMPLETED: 'COMPLETED'
});

const CANCEL_REASONS = Object.freeze({
  AUTO_CANCEL_STAFF_NOT_APPROVED: 'AUTO_CANCEL_STAFF_NOT_APPROVED',
  CUSTOMER_REQUESTED: 'CUSTOMER_REQUESTED',
  STAFF_OR_ADMIN_REQUESTED: 'STAFF_OR_ADMIN_REQUESTED',
  FIXED_SCHEDULE_CANCELLED: 'FIXED_SCHEDULE_CANCELLED'
});

const CANCELLED_BY = Object.freeze({
  SYSTEM: 'SYSTEM',
  CUSTOMER: 'CUSTOMER',
  STAFF: 'STAFF',
  ADMIN: 'ADMIN'
});

const BUSINESS_TIME_ZONE = 'Asia/Ho_Chi_Minh';
const VIETNAM_UTC_OFFSET_MINUTES = 7 * 60;
const AUTO_CANCEL_LEAD_MINUTES = 10;

const CUSTOMER_CANCEL_BLOCK_MESSAGE =
  'Không thể hủy sân trong vòng 2 tiếng trước giờ bắt đầu khi đơn đã được duyệt.';

const CUSTOMER_CANCEL_STARTED_MESSAGE =
  'Không thể hủy sân sau khi đã đến giờ bắt đầu.';

const CUSTOMER_RESCHEDULE_BLOCK_MESSAGE =
  'Không thể đổi lịch trong vòng 2 tiếng trước giờ bắt đầu khi đơn đã được duyệt.';

const CUSTOMER_BOOKING_LEAD_TIME_MESSAGE =
  'Chỉ có thể đặt sân trước giờ bắt đầu ít nhất 10 phút.';

const pad2 = (value) => value.toString().padStart(2, '0');

const vietnamDateFormatter = new Intl.DateTimeFormat('en-US', {
  timeZone: BUSINESS_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit'
});

const getVietnamDateParts = (date) => {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) return null;

  const parts = vietnamDateFormatter.formatToParts(date);
  const values = Object.fromEntries(
    parts
      .filter(part => part.type !== 'literal')
      .map(part => [part.type, Number(part.value)])
  );

  if (!values.year || !values.month || !values.day) return null;
  return { year: values.year, month: values.month, day: values.day };
};

const getBookingDateParts = (bookingDate) => {
  if (bookingDate instanceof Date) {
    return getVietnamDateParts(bookingDate);
  }

  if (typeof bookingDate === 'string') {
    const match = bookingDate.trim().match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!match) return null;

    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    const validationDate = new Date(Date.UTC(year, month - 1, day));

    if (
      validationDate.getUTCFullYear() !== year ||
      validationDate.getUTCMonth() !== month - 1 ||
      validationDate.getUTCDate() !== day
    ) {
      return null;
    }

    return { year, month, day };
  }

  return null;
};

const getDayOfWeekFromDateString = (bookingDate) => {
  const parts = getBookingDateParts(bookingDate);
  if (!parts) return null;
  return new Date(Date.UTC(parts.year, parts.month - 1, parts.day)).getUTCDay();
};

const toLocalDateString = (date = new Date()) => {
  const parts = getVietnamDateParts(date);
  if (!parts) return null;
  return `${parts.year}-${pad2(parts.month)}-${pad2(parts.day)}`;
};

const getBookingStartAt = (booking) => {
  const bookingDate = booking.booking_date || booking.bookingDate;
  const startMinutes = booking.start_minutes ?? booking.startMinutes;

  if (!bookingDate || startMinutes === undefined || startMinutes === null) {
    return null;
  }

  const dateParts = getBookingDateParts(bookingDate);
  const normalizedStartMinutes = Number(startMinutes);
  if (
    !dateParts ||
    !Number.isFinite(normalizedStartMinutes) ||
    !Number.isInteger(normalizedStartMinutes) ||
    normalizedStartMinutes < 0 ||
    normalizedStartMinutes >= 24 * 60
  ) return null;

  const vietnamMidnightAsUtc = Date.UTC(
    dateParts.year,
    dateParts.month - 1,
    dateParts.day,
    0,
    0,
    0,
    0
  );
  const utcTimestamp = vietnamMidnightAsUtc
    + normalizedStartMinutes * 60 * 1000
    - VIETNAM_UTC_OFFSET_MINUTES * 60 * 1000;

  return new Date(utcTimestamp);
};

const getBookingEndAt = (booking) => {
  const bookingDate = booking.booking_date || booking.bookingDate;
  const endMinutes = booking.end_minutes ?? booking.endMinutes;

  if (!bookingDate || endMinutes === undefined || endMinutes === null) {
    return null;
  }

  const dateParts = getBookingDateParts(bookingDate);
  const normalizedEndMinutes = Number(endMinutes);
  if (
    !dateParts ||
    !Number.isFinite(normalizedEndMinutes) ||
    !Number.isInteger(normalizedEndMinutes) ||
    normalizedEndMinutes <= 0 ||
    normalizedEndMinutes > 24 * 60
  ) return null;

  const vietnamMidnightAsUtc = Date.UTC(
    dateParts.year,
    dateParts.month - 1,
    dateParts.day,
    0,
    0,
    0,
    0
  );
  const utcTimestamp = vietnamMidnightAsUtc
    + normalizedEndMinutes * 60 * 1000
    - VIETNAM_UTC_OFFSET_MINUTES * 60 * 1000;

  return new Date(utcTimestamp);
};

const getBookingAutoCancelAt = (booking) => {
  const startAt = getBookingStartAt(booking);
  if (!startAt) return null;
  return new Date(
    startAt.getTime() - AUTO_CANCEL_LEAD_MINUTES * 60 * 1000
  );
};

const isWithinHoursBeforeStart = (booking, hours, now = new Date()) => {
  const startAt = getBookingStartAt(booking);
  if (!startAt) return false;
  const diffMs = startAt.getTime() - now.getTime();
  return diffMs >= 0 && diffMs < hours * 60 * 60 * 1000;
};

module.exports = {
  BOOKING_STATUSES,
  CANCEL_REASONS,
  CANCELLED_BY,
  BUSINESS_TIME_ZONE,
  AUTO_CANCEL_LEAD_MINUTES,
  CUSTOMER_CANCEL_BLOCK_MESSAGE,
  CUSTOMER_CANCEL_STARTED_MESSAGE,
  CUSTOMER_RESCHEDULE_BLOCK_MESSAGE,
  CUSTOMER_BOOKING_LEAD_TIME_MESSAGE,
  getBookingAutoCancelAt,
  getBookingEndAt,
  getBookingStartAt,
  getDayOfWeekFromDateString,
  isWithinHoursBeforeStart,
  toLocalDateString
};
