const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  guest_name: {
    type: String,
    trim: true,
    default: null
  },
  guest_phone: {
    type: String,
    trim: true,
    default: null
  },
  court_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Court',
    required: true
  },
  booking_date: {
    type: String,
    required: true
  },
  start_minutes: {
    type: Number,
    required: true
  },
  end_minutes: {
    type: Number,
    required: true
  },
  total_price: {
    type: Number,
    default: 0
  },
  status: {
    type: String,
    enum: ['PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED'],
    default: 'PENDING'
  },
  fixed_schedule_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'FixedSchedule',
    default: null,
    index: true
  },
  is_fixed_schedule: {
    type: Boolean,
    default: false
  },
  cancel_reason: {
    type: String,
    default: null
  },
  cancelled_by: {
    type: String,
    default: null
  },
  cancelled_at: {
    type: Date,
    default: null
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

bookingSchema.index({ status: 1, booking_date: 1, start_minutes: 1 });
bookingSchema.index({ fixed_schedule_id: 1, status: 1, booking_date: 1 });
bookingSchema.index(
  {
    fixed_schedule_id: 1,
    court_id: 1,
    booking_date: 1,
    start_minutes: 1,
    end_minutes: 1
  },
  {
    unique: true,
    partialFilterExpression: {
      fixed_schedule_id: { $exists: true, $ne: null },
      status: { $in: ['PENDING', 'CONFIRMED', 'COMPLETED'] }
    }
  }
);

const Booking = mongoose.model('Booking', bookingSchema);

module.exports = Booking;
