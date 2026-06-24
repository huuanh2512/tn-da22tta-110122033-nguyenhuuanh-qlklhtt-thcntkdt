const express = require('express');
const facilityController = require('../controllers/facility.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

// Tất cả các API quản lý cơ sở đều cần xác thực Token đầu vào
router.use(authMiddleware.verifyToken);

// API công khai cho mọi tài khoản đã đăng nhập hệ thống xem danh sách sân
router.get('/', facilityController.queryFacilities);
router.get('/:id', facilityController.getFacilityById);

// Các API thay đổi cấu trúc dữ liệu chỉ dành riêng cho tài khoản quản trị hệ thống
router.post('/', authMiddleware.requireRole(['ADMIN']), facilityController.createFacility);
router.put('/:id', authMiddleware.requireRole(['ADMIN', 'STAFF']), facilityController.updateFacility);
router.delete('/:id', authMiddleware.requireRole(['ADMIN']), facilityController.deleteFacility);

module.exports = router;
