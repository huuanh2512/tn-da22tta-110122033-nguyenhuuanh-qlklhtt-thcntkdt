const express = require('express');
const paymentController = require('../controllers/payment.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

router.use(authMiddleware.verifyToken);

router.get('/', paymentController.queryPayments);
router.post('/', paymentController.createPayment);

// Customer transitions are restricted to owned online invoices in the service.
router.put(
  '/:id/status',
  authMiddleware.requireRole(['ADMIN', 'STAFF', 'CUSTOMER']),
  paymentController.updatePaymentStatus
);

module.exports = router;
