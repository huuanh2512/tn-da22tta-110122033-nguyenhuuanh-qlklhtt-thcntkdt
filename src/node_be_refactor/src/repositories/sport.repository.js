const Sport = require('../models/sport.model');

class SportRepository {
  async create(sportData) {
    const sport = new Sport(sportData);
    return await sport.save();
  }

  async findById(id) {
    return await Sport.findById(id);
  }

  async findMany(query, skip, limit) {
    return await Sport.find(query)
      .skip(skip)
      .limit(limit)
      .sort({ created_at: -1 });
  }

  async count(query) {
    return await Sport.countDocuments(query);
  }

  async updateById(id, updateData) {
    return await Sport.findByIdAndUpdate(id, updateData, { new: true });
  }

  async deleteById(id) {
    return await Sport.findByIdAndDelete(id);
  }
}

module.exports = new SportRepository();