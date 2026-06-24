const express = require('express');
const reviewController = require('../controllers/review.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

router.use(authMiddleware.verifyToken);

router.get('/', reviewController.queryReviews);
router.post('/', reviewController.createReview);
router.delete('/:id', authMiddleware.requireRole(['ADMIN']), reviewController.deleteReview);

module.exports = router;