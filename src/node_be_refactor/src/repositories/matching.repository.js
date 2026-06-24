const MatchingSession = require('../models/matching.model');

class MatchingRepository {
  async create(data, options = {}) {
    const session = new MatchingSession(data);
    return await session.save(options);
  }

  async findById(id, options = {}) {
    return await MatchingSession.findById(id)
      .session(options.session || null)
      .populate('host_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate('court_id')
      .populate('teams.representative_user_id')
      .populate('members.user_id');
  }

  async findOne(query, options = {}) {
    return await MatchingSession.findOne(query).session(options.session || null);
  }

  async findMany(query, skip, limit, options = {}) {
    return await MatchingSession.find(query)
      .session(options.session || null)
      .skip(skip)
      .limit(limit)
      .populate('host_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate('court_id')
      .populate('teams.representative_user_id')
      .populate('members.user_id')
      .sort({ created_at: -1 });
  }

  async findLatestForUser(userId, options = {}) {
    return await MatchingSession.findOne({
      $or: [
        { host_id: userId },
        { 'members.user_id': userId }
      ],
      status: { $in: ['OPEN', 'FULL', 'COMPLETED'] }
    })
      .session(options.session || null)
      .sort({ created_at: -1 });
  }

  async count(query) {
    return await MatchingSession.countDocuments(query);
  }

  async updateById(id, updateData, options = {}) {
    return await MatchingSession.findByIdAndUpdate(id, updateData, {
      new: true,
      session: options.session
    })
      .populate('host_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate('members.user_id');
  }
}

module.exports = new MatchingRepository();
