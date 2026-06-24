const mongoose = require('mongoose');
const reviewRepository = require('../repositories/review.repository');

class ReviewService {
  _businessError(message, statusCode = 400, code = 'REVIEW_ERROR') {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  _objectId(value, name, required = false) {
    if (value === undefined || value === null || value === '') {
      if (required) {
        throw this._businessError(`${name} is required`, 400, 'MISSING_FIELDS');
      }
      return null;
    }

    if (typeof value !== 'string') {
      throw this._businessError(`Invalid ${name}`, 400, 'INVALID_ID');
    }

    const normalized = value.trim();
    if (!mongoose.isValidObjectId(normalized)) {
      throw this._businessError(`Invalid ${name}`, 400, 'INVALID_ID');
    }

    return normalized;
  }

  _formatReviewResponse(review) {
    return {
      id: review._id.toString(),
      user: review.user_id ? {
        id: review.user_id._id?.toString() || review.user_id.toString(),
        name: review.user_id.profile?.name || '',
        avatarUrl: review.user_id.profile?.avatar_url || ''
      } : null,
      court: review.court_id ? {
        id: review.court_id._id?.toString() || review.court_id.toString(),
        name: review.court_id.name || ''
      } : null,
      rating: review.rating,
      comment: review.comment,
      createdAt: review.created_at ? new Date(review.created_at).toISOString() : null
    };
  }

  async queryReviews(filters, skip = 0, limit = 20) {
    const query = {};
    const courtId = this._objectId(filters.courtId, 'courtId');
    const userId = this._objectId(filters.userId, 'userId');
    
    if (courtId) query.court_id = courtId;
    if (userId) query.user_id = userId;
    if (filters.rating) query.rating = parseInt(filters.rating);

    const [reviews, total] = await Promise.all([
      reviewRepository.findMany(query, parseInt(skip), parseInt(limit)),
      reviewRepository.count(query)
    ]);

    return {
      items: reviews.map(r => this._formatReviewResponse(r)),
      total: total
    };
  }

  async createReview(data, userId) {
    const normalizedCourtId = this._objectId(data.courtId, 'courtId', true);
    const normalizedUserId = this._objectId(userId, 'userId', true);
    const reviewData = {
      user_id: normalizedUserId,
      court_id: normalizedCourtId,
      rating: data.rating,
      comment: data.comment || ''
    };

    let newReview = await reviewRepository.create(reviewData);
    newReview = await reviewRepository.findById(newReview._id);
    
    return { review: this._formatReviewResponse(newReview) };
  }

  async deleteReview(id) {
    const deleted = await reviewRepository.deleteById(id);
    if (!deleted) throw new Error('Review not found');
    return true;
  }
}

module.exports = new ReviewService();
