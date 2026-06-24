const express = require('express');
const zaloPayController = require('../controllers/zalopay.controller');
const authMiddleware = require('../middlewares/auth.middleware');

const router = express.Router();

/**
 * POST /api/v1/zalopay/callback
 * ⚠️  KHÔNG dùng verifyToken ở đây — ZaloPay server gọi vào, không có JWT.
 *     Thay vào đó, xác thực bằng HMAC-MAC trong controller.
 *     Đặt trước middleware chung để tránh bị chặn.
 */
router.post('/callback', zaloPayController.handleCallback);

// Các endpoint còn lại yêu cầu đăng nhập
router.use(authMiddleware.verifyToken);

/**
 * POST /api/v1/zalopay/create-order
 * Tạo đơn hàng ZaloPay cho một payment đang PENDING.
 * Body: { paymentId: string }
 */
router.post(
  '/create-order',
  authMiddleware.requireRole(['CUSTOMER', 'STAFF', 'ADMIN']),
  zaloPayController.createOrder
);

/**
 * POST /api/v1/zalopay/query
 * Truy vấn trạng thái đơn hàng ZaloPay (polling từ Flutter).
 * Body: { app_trans_id: string, payment_id?: string }
 */
router.post(
  '/query',
  authMiddleware.requireRole(['CUSTOMER', 'STAFF', 'ADMIN']),
  zaloPayController.queryOrder
);

module.exports = router;
