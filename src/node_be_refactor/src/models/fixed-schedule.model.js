const mongoose = require('mongoose');

const fixedScheduleExceptionDateSchema = new mongoose.Schema({
  date: {
    type: String,
    required: true
  },
  type: {
    type: String,
    enum: ['CANCELLED', 'TEAM_UNAVAILABLE'],
    required: true
  },
  reason: {
    type: String,
    default: ''
  }
}, { _id: false });

const fixedScheduleMatchingTeamSchema = new mongoose.Schema({
  team_code: {
    type: String,
    enum: ['A', 'B'],
    required: true
  },
  max_players: {
    type: Number,
    required: true,
    min: 1
  },
  representative_user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  }
}, { _id: false });

const fixedScheduleMatchingMemberSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  team_code: {
    type: String,
    enum: ['A', 'B'],
    required: true
  },
  represented_count: {
    type: Number,
    default: 1,
    min: 1
  },
  status: {
    type: String,
    enum: ['INVITED', 'APPROVED', 'LEFT'],
    default: 'APPROVED'
  },
  joined_at: {
    type: Date,
    default: Date.now
  }
}, { _id: false });

const fixedScheduleMatchingConfigSchema = new mongoose.Schema({
  team_mode: {
    type: String,
    enum: ['INDIVIDUAL', 'TEAM_FILL', 'TEAM_VS_TEAM'],
    required: true
  },
  team_size: {
    type: Number,
    required: true,
    min: 1
  },
  payment_policy: {
    type: String,
    enum: ['HOST_PAY_ALL', 'SPLIT_EQUALLY', 'TEAM_REPRESENTATIVES_SPLIT'],
    required: true
  },
  host_team_code: {
    type: String,
    enum: ['A', 'B'],
    default: 'A'
  },
  host_represented_count: {
    type: Number,
    default: 1,
    min: 1
  },
  readiness: {
    type: String,
    enum: ['RECRUITING', 'READY'],
    default: 'RECRUITING'
  },
  teams: {
    type: [fixedScheduleMatchingTeamSchema],
    default: []
  },
  members: {
    type: [fixedScheduleMatchingMemberSchema],
    default: []
  }
}, { _id: false });

const fixedScheduleSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  type: {
    type: String,
    enum: ['COURT_BOOKING', 'MATCHING'],
    required: true,
    index: true
  },
  sport_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Sport',
    required: true,
    index: true
  },
  facility_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Facility',
    required: true,
    index: true
  },
  court_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Court',
    required: true,
    index: true
  },
  start_minutes: {
    type: Number,
    required: true
  },
  end_minutes: {
    type: Number,
    required: true
  },
  frequency: {
    type: String,
    enum: ['DAILY', 'WEEKLY'],
    required: true,
    index: true
  },
  days_of_week: {
    type: [Number], // 0: Sunday, 1: Monday, ..., 6: Saturday
    default: []
  },
  start_date: {
    type: String, // "YYYY-MM-DD"
    required: true
  },
  end_date: {
    type: String, // "YYYY-MM-DD" (Optional)
    default: null
  },
  status: {
    type: String,
    enum: ['PENDING_APPROVAL', 'ACTIVE', 'PAUSED', 'REJECTED', 'CANCELLED', 'EXPIRED'],
    default: 'PENDING_APPROVAL',
    index: true
  },
  exception_dates: {
    type: [fixedScheduleExceptionDateSchema],
    default: []
  },
  paused_at: {
    type: Date,
    default: null
  },
  matching_config: {
    type: fixedScheduleMatchingConfigSchema,
    default: null
  },
  approved_by: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  approved_at: {
    type: Date,
    default: null
  },
  rejected_by: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  rejected_at: {
    type: Date,
    default: null
  },
  rejection_reason: {
    type: String,
    default: null
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

const FixedSchedule = mongoose.model('FixedSchedule', fixedScheduleSchema);

module.exports = FixedSchedule;
