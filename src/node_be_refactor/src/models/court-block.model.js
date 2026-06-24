const mongoose = require('mongoose');

const courtBlockSchema = new mongoose.Schema({
  facility_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Facility',
    required: true,
    index: true
  },
  court_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Court',
    default: null,
    index: true
  },
  start_time: {
    type: Date,
    required: true,
    index: true
  },
  end_time: {
    type: Date,
    required: true,
    index: true
  },
  reason: {
    type: String,
    trim: true,
    default: ''
  },
  type: {
    type: String,
    enum: ['MAINTENANCE', 'HOLIDAY', 'MANUAL_BLOCK', 'CLOSED', 'OTHER'],
    default: 'MANUAL_BLOCK'
  },
  status: {
    type: String,
    enum: ['ACTIVE', 'CANCELLED'],
    default: 'ACTIVE',
    index: true
  },
  created_by: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

courtBlockSchema.pre('validate', function validateTimeRange(next) {
  if (
    this.start_time
    && this.end_time
    && this.start_time >= this.end_time
  ) {
    return next(new Error('start_time must be before end_time'));
  }
  return next();
});

courtBlockSchema.index({
  facility_id: 1,
  court_id: 1,
  status: 1,
  start_time: 1,
  end_time: 1
});

module.exports = mongoose.model('CourtBlock', courtBlockSchema);
