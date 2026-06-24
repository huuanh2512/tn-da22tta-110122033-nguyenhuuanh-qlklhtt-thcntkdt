const express = require('express');
const fixedScheduleController = require('../controllers/fixed-schedule.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

router.use(authMiddleware.verifyToken);

router.post('/', fixedScheduleController.createFixedSchedule);
router.get('/', fixedScheduleController.queryFixedSchedules);
router.post('/:id/matching/join', fixedScheduleController.joinFixedMatchingSchedule);
router.post('/:id/matching/leave', fixedScheduleController.leaveFixedMatchingSchedule);
router.post('/:id/occurrences/:date/cancel', fixedScheduleController.cancelFixedMatchingOccurrence);
router.put('/:id/approve', fixedScheduleController.approveFixedSchedule);
router.put('/:id/reject', fixedScheduleController.rejectFixedSchedule);
router.put('/:id/pause', fixedScheduleController.pauseFixedSchedule);
router.put('/:id/resume', fixedScheduleController.resumeFixedSchedule);
router.put('/:id/cancel', fixedScheduleController.cancelFixedSchedule);

module.exports = router;
