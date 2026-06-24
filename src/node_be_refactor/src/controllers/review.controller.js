const reviewService = require('../services/review.service');
const { sendSuccess, sendError } = require('../utils/response.util');

const queryReviews = async (req, res) => {
  try {
    const { skip, limit, ...filters } = req.query;
    const result = await reviewService.queryReviews(filters, skip, limit);
    return res.status(200).json({
      success: true,
      message: 'Reviews retrieved successfully',
      items: result.items,
      total: result.total
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 500,
      error.message,
      error.code || 'QUERY_ERROR'
    );
  }
};

const createReview = async (req, res) => {
  try {
    const { courtId, rating, comment } = req.body;
    
    if (!courtId || rating === undefined) {
      return sendError(res, 400, 'Court ID and rating are required', 'MISSING_FIELDS');
    }

    if (rating < 1 || rating > 5) {
      return sendError(res, 400, 'Rating must be between 1 and 5', 'INVALID_RATING');
    }

    const result = await reviewService.createReview({ courtId, rating, comment }, req.user.id);
    
    return res.status(200).json({
      success: true,
      message: 'Review created successfully',
      review: result.review
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 500,
      error.message,
      error.code || 'CREATE_ERROR'
    );
  }
};

const deleteReview = async (req, res) => {
  try {
    const { id } = req.params;
    await reviewService.deleteReview(id);
    return sendSuccess(res, null, 'Review deleted successfully', 'DELETE_SUCCESS');
  } catch (error) {
    return sendError(res, 400, error.message, 'DELETE_ERROR');
  }
};

module.exports = {
  queryReviews,
  createReview,
  deleteReview
};
