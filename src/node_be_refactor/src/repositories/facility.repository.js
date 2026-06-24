const Facility = require('../models/facility.model');

class FacilityRepository {
  async create(facilityData) {
    const facility = new Facility(facilityData);
    return await facility.save();
  }

  async findById(id) {
    return await Facility.findById(id);
  }

  async findMany(query, skip, limit) {
    return await Facility.find(query)
      .skip(skip)
      .limit(limit)
      .sort({ created_at: -1 });
  }

  async count(query) {
    return await Facility.countDocuments(query);
  }

  async updateById(id, updateData) {
    return await Facility.findByIdAndUpdate(id, updateData, { new: true });
  }

  async deleteById(id) {
    return await Facility.findByIdAndDelete(id);
  }
}

module.exports = new FacilityRepository();