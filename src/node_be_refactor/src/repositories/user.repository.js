const User = require('../models/user.model');

class UserRepository {
  async create(userData) {
    const user = new User(userData);
    return await user.save();
  }

  async findByEmail(email) {
    return await User.findOne({ email });
  }

  async findByFirebaseUid(firebaseUid) {
    return await User.findOne({ firebaseUid });
  }

  async findById(id) {
    return await User.findById(id);
  }

  async updateById(id, updateData) {
    return await User.findByIdAndUpdate(id, updateData, { new: true });
  }

  async findOneAndUpdate(query, updateData, options = {}) {
    return await User.findOneAndUpdate(query, updateData, {
      new: true,
      ...options
    });
  }

  async updateStatus(id, status) {
    return await User.findByIdAndUpdate(id, { status }, { new: true });
  }

  async findMany(query, skip, limit) {
    return await User.find(query)
      .skip(skip)
      .limit(limit)
      .populate('facility_id')
      .sort({ created_at: -1 });
  }

  async count(query) {
    return await User.countDocuments(query);
  }
}

module.exports = new UserRepository();
