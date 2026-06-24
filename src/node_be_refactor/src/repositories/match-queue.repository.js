const MatchQueue = require('../models/match-queue.model');

class MatchQueueRepository {
  async create(data, options = {}) {
    const queue = new MatchQueue(data);
    return await queue.save(options);
  }

  async findActiveByUserId(userId, options = {}) {
    return await MatchQueue.findOne({ user_id: userId, status: 'SEARCHING' })
      .session(options.session || null)
      .populate('sport_id')
      .populate('facility_id');
  }

  async findCurrentByUserId(userId, options = {}) {
    return await MatchQueue.findOne({
      user_id: userId,
      status: { $in: ['SEARCHING', 'MATCHED'] }
    })
      .session(options.session || null)
      .populate('sport_id')
      .populate('facility_id')
      .populate('matching_session_id')
      .sort({ updated_at: -1 });
  }

  async findActiveQueues(query = {}, options = {}) {
    return await MatchQueue.find({ status: 'SEARCHING', ...query })
      .session(options.session || null)
      .populate('user_id')
      .populate('sport_id')
      .populate('facility_id');
  }

  async updateStatus(id, status, options = {}) {
    return await MatchQueue.findByIdAndUpdate(id, { status }, {
      new: true,
      session: options.session
    });
  }

  async updateMany(query, updateData, options = {}) {
    return await MatchQueue.updateMany(query, updateData, {
      session: options.session
    });
  }
}

module.exports = new MatchQueueRepository();
