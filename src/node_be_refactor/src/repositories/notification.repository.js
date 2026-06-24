const Notification = require('../models/notification.model');

class NotificationRepository {
  async create(notificationData) {
    const notification = new Notification(notificationData);
    return await notification.save();
  }

  async findById(id) {
    return await Notification.findById(id);
  }

  async findMany(query, skip, limit) {
    return await Notification.find(query)
      .skip(skip)
      .limit(limit)
      .sort({ createdAt: -1 }); // Thông báo mới nhất lên đầu
  }

  async count(query) {
    return await Notification.countDocuments(query);
  }

  async markAsRead(id, userId) {
    // Chỉ cập nhật nếu đúng userId để bảo mật
    return await Notification.findOneAndUpdate(
      { _id: id, userId: userId },
      { isRead: true },
      { new: true }
    );
  }

  async markAllAsRead(query) {
    return await Notification.updateMany(
      query,
      { isRead: true }
    );
  }
}

module.exports = new NotificationRepository();
