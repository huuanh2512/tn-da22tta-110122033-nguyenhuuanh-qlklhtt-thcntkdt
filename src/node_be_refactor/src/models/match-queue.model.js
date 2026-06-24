const mongoose = require('mongoose');

const matchQueueSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
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
  booking_date: {
    type: String,
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
  group_size: {
    // One queue is one user/player; this stores the target total players for the match.
    type: Number,
    default: 2,
    min: 2
  },
  team_mode: {
    type: String,
    enum: ['INDIVIDUAL', 'TEAM_FILL', 'TEAM_VS_TEAM'],
    default: 'INDIVIDUAL',
    index: true
  },
  preferred_team: {
    type: String,
    enum: ['A', 'B', 'AUTO'],
    default: 'AUTO'
  },
  member_count: {
    type: Number,
    default: 1,
    min: 1
  },
  team_size: {
    type: Number,
    default: null,
    min: 1
  },
  payment_policy: {
    type: String,
    enum: ['HOST_PAY_ALL', 'SPLIT_EQUALLY', 'TEAM_REPRESENTATIVES_SPLIT'],
    default: 'SPLIT_EQUALLY'
  },
  matching_session_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'MatchingSession',
    default: null,
    index: true
  },
  claim_token: {
    type: String,
    default: null,
    select: false
  },
  status: {
    type: String,
    enum: ['SEARCHING', 'MATCHED', 'CANCELLED', 'EXPIRED'],
    default: 'SEARCHING',
    index: true
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

const MatchQueue = mongoose.model('MatchQueue', matchQueueSchema);

module.exports = MatchQueue;
