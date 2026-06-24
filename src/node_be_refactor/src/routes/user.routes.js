const express = require('express');
const userController = require('../controllers/user.controller');
const fcmController = require('../controllers/fcm.controller');
const { verifyToken, requireRole } = require('../middlewares/auth.middleware');

const router = express.Router();

// Bật khiên bảo vệ cho TẤT CẢ các API bên dưới (Bắt buộc phải có Access Token)
router.use(verifyToken);

// CỤM 1: Dành cho mọi User đã đăng nhập
router.get('/:id', userController.getUserProfile);
router.put('/:id', userController.updateUserProfile);

// FCM Token Management (dành cho mobile app)
router.post('/register-fcm', fcmController.registerFCMToken);
router.post('/remove-fcm', fcmController.removeFCMToken);

// CỤM 2: Dành riêng cho ADMIN
router.get('/', requireRole(['ADMIN']), userController.queryUsers);
router.put('/:id/role', requireRole(['ADMIN']), userController.updateUserRole);
router.put('/:id/status', requireRole(['ADMIN']), userController.updateUserStatus);
router.post('/:id/assign-facility', requireRole(['ADMIN']), userController.assignUserFacility);
router.post('/provision-firebase', requireRole(['ADMIN']), userController.provisionFirebaseUser);

module.exports = router;
