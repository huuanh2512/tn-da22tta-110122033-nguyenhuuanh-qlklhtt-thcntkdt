const Review = require('../models/review.model');

class ReviewRepository {
  async create(reviewData) {
    const review = new Review(reviewData);
    return await review.save();
  }

  async findById(id) {
    return await Review.findById(id).populate('user_id').populate('court_id');
  }

  async findMany(query, skip, limit) {
    return await Review.find(query)
      .skip(skip)
      .limit(limit)
      .populate('user_id')
      .populate('court_id')
      .sort({ created_at: -1 });
  }

  async count(query) {
    return await Review.countDocuments(query);
  }

  async deleteById(id) {
    return await Review.findByIdAndDelete(id);
  }
}

module.exports = new ReviewRepository();