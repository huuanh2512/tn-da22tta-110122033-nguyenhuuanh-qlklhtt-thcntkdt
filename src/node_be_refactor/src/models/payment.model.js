const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  booking_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking',
    required: true
  },
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  amount: {
    type: Number,
    required: true
  },
  method: {
    type: String,
    enum: ['CASH', 'BANK_TRANSFER', 'MOMO', 'ZALOPAY', 'VNPAY'],
    default: 'CASH'
  },
  status: {
    type: String,
    enum: [
      'PENDING',
      'SUCCESS',
      'FAILED',
      'CANCELLED',
      'REFUND_PENDING',
      'REFUNDED'
    ],
    default: 'PENDING'
  },
  transaction_id: {
    type: String,
    default: ''
  },
  zalopay_order_url: {
    type: String,
    default: ''
  },
  zalopay_deeplink_url: {
    type: String,
    default: ''
  },
  zalopay_qr_code: {
    type: String,
    default: ''
  },
  zalopay_created_at: {
    type: Date,
    default: null
  },
  refunded_at: {
    type: Date,
    default: null
  },
  refunded_by: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  refund_reason: {
    type: String,
    trim: true,
    default: null
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

paymentSchema.index(
  { booking_id: 1, user_id: 1 },
  {
    unique: true,
    partialFilterExpression: { status: { $in: ['PENDING', 'SUCCESS'] } }
  }
);

const Payment = mongoose.model('Payment', paymentSchema);

module.exports = Payment;
