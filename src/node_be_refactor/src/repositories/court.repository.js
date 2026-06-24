const Court = require('../models/court.model');

class CourtRepository {
  async create(courtData) {
    const court = new Court(courtData);
    return await court.save();
  }

  async findById(id) {
    return await Court.findById(id).populate('facility_id').populate('sport_id');
  }

  async findMany(query, skip, limit) {
    return await Court.find(query)
      .skip(skip)
      .limit(limit)
      .populate('facility_id')
      .populate('sport_id')
      .sort({ created_at: -1 });
  }

  async count(query) {
    return await Court.countDocuments(query);
  }

  async updateById(id, updateData) {
    return await Court.findByIdAndUpdate(id, updateData, { new: true }).populate('facility_id').populate('sport_id');
  }

  async deleteById(id) {
    return await Court.findByIdAndDelete(id);
  }
}

module.exports = new CourtRepository();