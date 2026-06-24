const express = require('express');
const courtController = require('../controllers/court.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

router.use(authMiddleware.verifyToken);

// 4 API quản lý Court
router.get('/', courtController.queryCourts);
router.post('/', authMiddleware.requireRole(['ADMIN', 'STAFF']), courtController.createCourt);
router.put('/:id', authMiddleware.requireRole(['ADMIN', 'STAFF']), courtController.updateCourt);
router.delete('/:id', authMiddleware.requireRole(['ADMIN', 'STAFF']), courtController.deleteCourt);

// 2 API quản lý Slot Config của Court đó
router.get('/:id/slot-config', courtController.getCourtSlotConfig);
router.put('/:id/slot-config', authMiddleware.requireRole(['ADMIN', 'STAFF']), courtController.upsertCourtSlotConfig);

module.exports = router;
