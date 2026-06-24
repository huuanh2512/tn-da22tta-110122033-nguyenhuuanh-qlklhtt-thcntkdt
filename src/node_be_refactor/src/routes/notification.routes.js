const express = require('express');
const notificationController = require('../controllers/notification.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

router.use(authMiddleware.verifyToken);

// Các API dành cho người dùng đang đăng nhập xem và cập nhật thông báo của chính mình
router.get('/', notificationController.getMyNotifications);
router.put('/mark-all-read', notificationController.markAllAsRead);
router.put('/:id/read', notificationController.markAsRead);

// API dành cho hệ thống hoặc ADMIN chủ động bắn thông báo cho người dùng
router.post('/', authMiddleware.requireRole(['ADMIN']), notificationController.createSystemNotification);

module.exports = router;