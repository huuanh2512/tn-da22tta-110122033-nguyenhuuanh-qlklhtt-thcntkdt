const bookingService = require('../services/booking.service');
const { sendSuccess, sendError } = require('../utils/response.util');

const queryBookings = async (req, res) => {
  try {
    const { skip, limit, ...filters } = req.query;
    const result = await bookingService.queryBookings(
      filters,
      skip,
      limit,
      req.user
    );
    return res.status(200).json({
      success: true,
      message: 'Bookings retrieved successfully',
      items: result.items,
      total: result.total
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 500,
      error.message,
      error.code || 'QUERY_ERROR'
    );
  }
};

const createBooking = async (req, res) => {
  try {
    const {
      courtId,
      bookingDate,
      startMinutes,
      endMinutes,
      totalPrice,
      userId,
      guestName,
      guestPhone
    } = req.body;
    
    if (!courtId || !bookingDate || startMinutes === undefined || endMinutes === undefined) {
      return sendError(res, 400, 'Missing required booking fields', 'MISSING_FIELDS');
    }

    const canBookForCustomer = req.user.role === 'ADMIN' || req.user.role === 'STAFF';
    const targetUserId = canBookForCustomer ? (userId || null) : req.user.id;

    if (canBookForCustomer && !targetUserId && (!guestName?.trim() || !guestPhone?.trim())) {
      return sendError(res, 400, 'Walk-in customer name and phone are required', 'MISSING_GUEST_INFO');
    }

    const result = await bookingService.createBooking({
      courtId,
      bookingDate,
      startMinutes,
      endMinutes,
      totalPrice,
      guestName: targetUserId ? null : guestName.trim(),
      guestPhone: targetUserId ? null : guestPhone.trim()
    }, targetUserId, req.user);

    return res.status(200).json({
      success: true,
      message: 'Booking created successfully',
      booking: result.booking
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 500,
      error.message,
      error.code || 'CREATE_ERROR'
    );
  }
};

const getBookingDetail = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await bookingService.getBookingDetail(id, req.user);

    return res.status(200).json({
      success: true,
      message: 'Booking detail retrieved successfully',
      booking: result.booking
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 404,
      error.message,
      error.code || 'NOT_FOUND'
    );
  }
};

const updateBookingStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    const result = await bookingService.updateBookingStatus(id, status, req.user);
    return res.status(200).json({
      success: true,
      message: 'Booking status updated successfully',
      booking: result.booking
    });
  } catch (error) {
    return sendError(res, error.statusCode || 400, error.message, error.code || 'UPDATE_ERROR');
  }
};

const updateBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await bookingService.updateBooking(id, req.body, req.user);
    return res.status(200).json({
      success: true,
      message: 'Booking updated successfully',
      booking: result.booking
    });
  } catch (error) {
    return sendError(res, error.statusCode || 400, error.message, error.code || 'UPDATE_ERROR');
  }
};

const cancelBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await bookingService.cancelBooking(id, req.user);
    const paymentMessage = result.paymentStatus === 'CANCELLED'
      ? ' Hóa đơn chờ thanh toán đã được hủy.'
      : result.paymentStatus === 'REFUND_PENDING'
        ? ' Giao dịch đã thanh toán được chuyển sang chờ hoàn tiền.'
        : '';

    return res.status(200).json({
      success: true,
      message: result.occurrenceOnly
        ? `Đã hủy buổi này, lịch cố định vẫn tiếp tục hoạt động.${paymentMessage}`
        : result.paymentStatus === 'CANCELLED'
          ? 'Đã hủy booking. Hóa đơn chờ thanh toán đã được hủy.'
          : result.paymentStatus === 'REFUND_PENDING'
            ? 'Đã hủy booking. Giao dịch đã thanh toán được chuyển sang chờ hoàn tiền.'
            : 'Booking cancelled successfully',
      booking: result.booking,
      paymentStatus: result.paymentStatus
    });
  } catch (error) {
    return sendError(res, error.statusCode || 400, error.message, error.code || 'CANCEL_ERROR');
  }
};

module.exports = {
  queryBookings,
  createBooking,
  getBookingDetail,
  updateBooking,
  updateBookingStatus,
  cancelBooking
};
