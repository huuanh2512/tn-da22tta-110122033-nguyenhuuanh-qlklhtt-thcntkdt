const paymentService = require('../services/payment.service');
const { sendSuccess, sendError } = require('../utils/response.util');

const queryPayments = async (req, res) => {
  try {
    const { skip, limit, ...filters } = req.query;
    
    // Khách hàng chỉ được xem thanh toán của chính họ
    if (req.user.role === 'CUSTOMER') {
      filters.userId = req.user.id;
    }

    const result = await paymentService.queryPayments(filters, skip, limit);
    return res.status(200).json({
      success: true,
      message: 'Payments retrieved successfully',
      items: result.items,
      total: result.total
    });
  } catch (error) {
    return sendError(res, 500, error.message, 'QUERY_ERROR');
  }
};

const createPayment = async (req, res) => {
  try {
    const { bookingId, amount, method, transactionId } = req.body;
    
    if (!bookingId || amount === undefined) {
      return sendError(res, 400, 'Booking ID and amount are required', 'MISSING_FIELDS');
    }

    const result = await paymentService.createPayment({
      bookingId, amount, method, transactionId
    }, req.user.id);

    return res.status(200).json({
      success: true,
      message: 'Payment created successfully',
      payment: result.payment
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

const updatePaymentStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, transactionId, refundReason } = req.body;
    
    const result = await paymentService.updatePaymentStatus(
      id,
      status,
      transactionId,
      req.user,
      refundReason
    );
    return res.status(200).json({
      success: true,
      message: 'Payment status updated successfully',
      payment: result.payment
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 400,
      error.message,
      error.code || 'UPDATE_ERROR'
    );
  }
};

module.exports = {
  queryPayments,
  createPayment,
  updatePaymentStatus
};
