const express = require('express');
const bookingController = require('../controllers/booking.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

router.use(authMiddleware.verifyToken);

router.post('/', bookingController.createBooking);
router.get('/', bookingController.queryBookings);
router.get('/:id', bookingController.getBookingDetail);
router.put(
  '/:id',
  authMiddleware.requireRole(['CUSTOMER', 'STAFF', 'ADMIN']),
  bookingController.updateBooking
);
router.put(
  '/:id/cancel',
  authMiddleware.requireRole(['CUSTOMER', 'STAFF', 'ADMIN']),
  bookingController.cancelBooking
);
router.put('/:id/status', authMiddleware.requireRole(['ADMIN', 'STAFF']), bookingController.updateBookingStatus);

module.exports = router; 
