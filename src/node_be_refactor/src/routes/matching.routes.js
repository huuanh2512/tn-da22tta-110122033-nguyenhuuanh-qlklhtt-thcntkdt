const express = require('express');
const matchingController = require('../controllers/matching.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

router.use(authMiddleware.verifyToken);

// Queue routes must stay before dynamic /:id routes.
router.post('/queue/join', authMiddleware.requireRole(['CUSTOMER']), matchingController.joinQueue);
router.post('/queue/leave', authMiddleware.requireRole(['CUSTOMER']), matchingController.leaveQueue);
router.get('/queue/status', authMiddleware.requireRole(['CUSTOMER']), matchingController.getQueueStatus);

router.post('/', authMiddleware.requireRole(['CUSTOMER']), matchingController.createSession);
router.get('/', matchingController.querySessions);
router.get('/:id', matchingController.getSessionDetail);
router.post('/:id/join', authMiddleware.requireRole(['CUSTOMER']), matchingController.joinSession);
router.post('/:id/leave', authMiddleware.requireRole(['CUSTOMER']), matchingController.leaveSession);
router.put('/:id/members/:userId', authMiddleware.requireRole(['CUSTOMER']), matchingController.updateMemberStatus);
router.put('/:id/status', authMiddleware.requireRole(['CUSTOMER']), matchingController.updateSessionStatus);

module.exports = router;
