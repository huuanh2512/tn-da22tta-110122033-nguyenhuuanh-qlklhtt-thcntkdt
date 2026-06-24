const zaloPayService = require('../services/zalopay.service');
const paymentService  = require('../services/payment.service');
const paymentRepository = require('../repositories/payment.repository');
const { sendSuccess, sendError } = require('../utils/response.util');
const notificationHelper = require('../services/notification.helper');

/**
 * POST /api/v1/zalopay/create-order
 * Tạo đơn hàng ZaloPay từ server, ký HMAC bằng key1 server-side.
 * Body: { paymentId }
 * Trả về: { order_url, app_trans_id, qr_code }
 */
const createOrder = async (req, res) => {
  try {
    const { paymentId } = req.body;

    if (!paymentId) {
      return sendError(res, 400, 'paymentId is required', 'MISSING_PAYMENT_ID');
    }

    // Lấy thông tin payment từ DB
    const payment = await paymentRepository.findById(paymentId);
    if (!payment) {
      return sendError(res, 404, 'Payment not found', 'PAYMENT_NOT_FOUND');
    }

    // Chỉ tạo đơn ZaloPay cho payment đang PENDING
    if (payment.status !== 'PENDING') {
      return sendError(
        res,
        409,
        'Chỉ có thể tạo đơn ZaloPay cho hóa đơn đang chờ thanh toán.',
        'PAYMENT_NOT_PENDING'
      );
    }

    // Kiểm tra quyền: chỉ chủ payment mới được tạo đơn ZaloPay
    const paymentUserId =
      payment.user_id?._id?.toString() || payment.user_id?.toString();
    if (req.user.role === 'CUSTOMER' && paymentUserId !== req.user.id) {
      return sendError(res, 403, 'Bạn không có quyền thanh toán hóa đơn này.', 'FORBIDDEN');
    }

    if (
      payment.method === 'ZALOPAY'
      && payment.transaction_id
      && payment.zalopay_order_url
    ) {
      const cachedOrder = await zaloPayService.queryOrder(payment.transaction_id);
      if (cachedOrder.returnCode !== 2) {
        const cachedQrCode = payment.zalopay_qr_code?.startsWith('zalopay://')
          ? ''
          : payment.zalopay_qr_code;
        return res.status(200).json({
          success: true,
          message: 'Existing ZaloPay order returned',
          order_url: payment.zalopay_order_url,
          deeplink_url: payment.zalopay_deeplink_url,
          app_trans_id: payment.transaction_id,
          qr_code:
            cachedQrCode
            || payment.zalopay_order_url
            || payment.zalopay_deeplink_url
            || null,
        });
      }

      await paymentRepository.updateOne(
        {
          _id: paymentId,
          transaction_id: payment.transaction_id,
          status: 'PENDING',
        },
        {
          transaction_id: '',
          zalopay_order_url: '',
          zalopay_deeplink_url: '',
          zalopay_qr_code: '',
          zalopay_created_at: null,
        }
      );
      console.warn(`[ZaloPay] Discarded failed cached order for payment ${paymentId}.`);
    }

    const bookingId = payment.booking_id?._id?.toString() || payment.booking_id?.toString();
    const amount    = payment.amount;

    const result = await zaloPayService.createOrder({ paymentId, bookingId, amount });

    if (!result) {
      return sendError(res, 502, 'ZaloPay từ chối tạo đơn hàng. Vui lòng thử lại.', 'ZALOPAY_CREATE_FAILED');
    }

    // Cập nhật method của payment sang ZALOPAY và lưu app_trans_id vào transaction_id
    await paymentRepository.updateStatus(paymentId, {
      method:               'ZALOPAY',
      transaction_id:       result.app_trans_id,
      zalopay_order_url:    result.order_url || '',
      zalopay_deeplink_url: result.deeplink_url || '',
      zalopay_qr_code:      result.qr_code || '',
      zalopay_created_at:   new Date(),
    });

    return res.status(200).json({
      success:        true,
      message:        'ZaloPay order created successfully',
      order_url:      result.order_url,
      deeplink_url:   result.deeplink_url,
      zp_trans_token: result.zp_trans_token,
      app_trans_id:   result.app_trans_id,
      qr_code:        result.qr_code,
    });
  } catch (error) {
    console.error('[ZaloPay] createOrder controller error:', error);
    return sendError(res, 500, error.message, 'SERVER_ERROR');
  }
};

/**
 * POST /api/v1/zalopay/callback
 * Webhook ZaloPay gọi vào khi giao dịch hoàn thành (KHÔNG cần auth JWT).
 * ZaloPay gửi: { data (JSON string), mac, type }
 * Docs: https://docs.zalopay.vn/vi/docs/guides/payment-acceptance/callback
 */
const handleCallback = async (req, res) => {
  // ZaloPay yêu cầu response trả về mã JSON với returncode
  const RETURN_SUCCESS = { return_code: 1, return_message: 'success' };
  const RETURN_FAILURE = { return_code: 0, return_message: 'failed' };

  try {
    const { data, mac } = req.body;

    if (!data || !mac) {
      console.warn('[ZaloPay] Callback thiếu data hoặc mac');
      return res.json(RETURN_FAILURE);
    }

    // Xác minh chữ ký MAC với key2
    const { valid, parsedData } = zaloPayService.verifyCallback({ data, mac });
    if (!valid) {
      return res.json(RETURN_FAILURE);
    }

    console.log('[ZaloPay] Callback verified. parsedData:', JSON.stringify(parsedData));

    const appTransId = parsedData.app_trans_id;
    if (!appTransId) {
      return res.json(RETURN_FAILURE);
    }

    // Tìm payment theo app_trans_id đã lưu trong transaction_id
    const payment = await paymentRepository.findRawOne({
      transaction_id: appTransId,
      status:         'PENDING',
    });

    if (!payment) {
      // Có thể đã được cập nhật trước đó (idempotent)
      console.log(`[ZaloPay] Callback: payment with trans_id=${appTransId} not found or already processed`);
      return res.json(RETURN_SUCCESS); // vẫn trả success để ZaloPay không retry
    }

    // Cập nhật payment thành SUCCESS
    const updatedPayment = await paymentRepository.updateStatus(payment._id, {
      status:     'SUCCESS',
      // transaction_id giữ nguyên app_trans_id
    });

    // Gửi notification cho user
    try {
      await notificationHelper.notifyPaymentSuccess(updatedPayment);
    } catch (notifErr) {
      console.error('[ZaloPay] Notify payment success error:', notifErr.message);
    }

    console.log(`[ZaloPay] ✅ Payment ${payment._id} marked SUCCESS via callback (trans: ${appTransId})`);
    return res.json(RETURN_SUCCESS);

  } catch (error) {
    console.error('[ZaloPay] handleCallback error:', error);
    return res.json(RETURN_FAILURE);
  }
};

/**
 * POST /api/v1/zalopay/query
 * Proxy truy vấn trạng thái đơn hàng ZaloPay (dùng cho polling từ Flutter).
 * Body: { app_trans_id, payment_id }
 * Trả về: { is_paid, return_code, message }
 */
const queryOrder = async (req, res) => {
  try {
    const { app_trans_id, payment_id } = req.body;

    if (!app_trans_id) {
      return sendError(res, 400, 'app_trans_id is required', 'MISSING_TRANS_ID');
    }

    if (!payment_id) {
      return sendError(res, 400, 'payment_id is required', 'MISSING_PAYMENT_ID');
    }

    const requestedPayment = await paymentRepository.findById(payment_id);
    if (!requestedPayment) {
      return sendError(res, 404, 'Payment not found', 'PAYMENT_NOT_FOUND');
    }

    const requestedPaymentUserId =
      requestedPayment.user_id?._id?.toString()
      || requestedPayment.user_id?.toString();
    if (req.user.role === 'CUSTOMER' && requestedPaymentUserId !== req.user.id) {
      return sendError(res, 403, 'Forbidden', 'FORBIDDEN');
    }

    if (
      requestedPayment.method !== 'ZALOPAY'
      || requestedPayment.transaction_id !== app_trans_id
    ) {
      return sendError(
        res,
        409,
        'ZaloPay transaction does not match a pending payment.',
        'ZALOPAY_TRANSACTION_MISMATCH'
      );
    }

    if (requestedPayment.status === 'SUCCESS') {
      return res.status(200).json({
        success: true,
        is_paid: true,
        return_code: 1,
        message: 'Payment already confirmed',
      });
    }

    if (requestedPayment.status !== 'PENDING') {
      return sendError(res, 409, 'Payment is not pending.', 'PAYMENT_NOT_PENDING');
    }

    // Nếu có payment_id, kiểm tra quyền truy cập
    if (payment_id) {
      const payment = await paymentRepository.findById(payment_id);
      if (payment) {
        const paymentUserId =
          payment.user_id?._id?.toString() || payment.user_id?.toString();
        if (req.user.role === 'CUSTOMER' && paymentUserId !== req.user.id) {
          return sendError(res, 403, 'Bạn không có quyền truy vấn giao dịch này.', 'FORBIDDEN');
        }
      }
    }

    const result = await zaloPayService.queryOrder(app_trans_id);

    // Nếu đã thanh toán thành công và có payment_id → tự cập nhật DB
    if (result.isPaid && payment_id) {
      const payment = await paymentRepository.findRawOne({
        _id:    payment_id,
        status: 'PENDING',
      });
      if (payment) {
        const updatedPayment = await paymentRepository.updateStatus(payment_id, {
          status: 'SUCCESS',
        });
        try {
          await notificationHelper.notifyPaymentSuccess(updatedPayment);
        } catch (_) {}
        console.log(`[ZaloPay] ✅ Payment ${payment_id} marked SUCCESS via query`);
      }
    }

    if (result.returnCode === 2) {
      await paymentRepository.updateOne(
        {
          _id: payment_id,
          transaction_id: app_trans_id,
          status: 'PENDING',
        },
        {
          transaction_id: '',
          zalopay_order_url: '',
          zalopay_deeplink_url: '',
          zalopay_qr_code: '',
          zalopay_created_at: null,
        }
      );
      console.warn(
        `[ZaloPay] Payment ${payment_id} was rejected by the gateway and can be retried.`
      );
    }

    return res.status(200).json({
      success:     true,
      is_paid:     result.isPaid,
      return_code: result.returnCode,
      message:     result.message,
      sub_return_code: result.subReturnCode,
      sub_message: result.subMessage,
      retryable: result.returnCode === 2,
    });
  } catch (error) {
    console.error('[ZaloPay] queryOrder controller error:', error);
    return sendError(res, 500, error.message, 'SERVER_ERROR');
  }
};

module.exports = { createOrder, handleCallback, queryOrder };
