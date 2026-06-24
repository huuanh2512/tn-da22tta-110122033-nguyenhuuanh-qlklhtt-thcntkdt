const express = require('express');
const sportController = require('../controllers/sport.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

router.use(authMiddleware.verifyToken);

router.get('/', sportController.querySports);
router.post('/', authMiddleware.requireRole(['ADMIN']), sportController.createSport);
router.put('/:id', authMiddleware.requireRole(['ADMIN']), sportController.updateSport);
router.delete('/:id', authMiddleware.requireRole(['ADMIN']), sportController.deleteSport);

module.exports = router;