const express = require('express');
const reportsController = require('../controllers/reports.controller');
const authMiddleware = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(authMiddleware.verifyToken);
router.get('/advanced-performance', reportsController.getAdvancedPerformance);
router.get('/court-performance', reportsController.getCourtPerformance);

module.exports = router;
