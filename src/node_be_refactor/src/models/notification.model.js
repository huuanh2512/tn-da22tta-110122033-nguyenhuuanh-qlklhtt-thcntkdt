const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  title: {
    type: String,
    required: true,
    trim: true
  },
  content: {
    type: String,
    required: true,
    trim: true
  },
  type: {
    type: String,
    enum: ['BOOKING', 'PAYMENT', 'SYSTEM', 'PROMOTION'],
    default: 'SYSTEM'
  },
  audience: {
    type: String,
    enum: ['CUSTOMER', 'STAFF', 'ADMIN', 'ALL'],
    default: 'ALL',
    index: true
  },
  metadata: {
    bookingId: { type: String },
    paymentId: { type: String },
    matchingSessionId: { type: String },
    link: { type: String }
  },
  isRead: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

// Compound Index để lấy nhanh danh sách thông báo chưa đọc của user
notificationSchema.index({ userId: 1, audience: 1, isRead: 1, createdAt: -1 });

const Notification = mongoose.model('Notification', notificationSchema);

module.exports = Notification;
