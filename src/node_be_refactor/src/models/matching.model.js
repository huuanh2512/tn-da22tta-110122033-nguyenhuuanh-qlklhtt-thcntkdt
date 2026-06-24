const mongoose = require('mongoose');

const matchingMemberSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  status: {
    type: String,
    enum: ['PENDING', 'APPROVED', 'REJECTED'],
    default: 'PENDING'
  },
  team_code: {
    type: String,
    enum: ['A', 'B'],
    default: null
  },
  represented_count: {
    type: Number,
    default: 1,
    min: 1
  },
  join_mode: {
    type: String,
    enum: ['INDIVIDUAL', 'TEAM_REPRESENTATIVE'],
    default: 'INDIVIDUAL'
  },
  team_name: {
    type: String,
    default: '',
    trim: true,
    maxlength: 100
  },
  note: {
    type: String,
    default: '',
    trim: true,
    maxlength: 500
  },
  joined_at: {
    type: Date,
    default: Date.now
  }
}, { _id: false });

const matchingTeamSchema = new mongoose.Schema({
  team_code: {
    type: String,
    enum: ['A', 'B'],
    required: true
  },
  name: {
    type: String,
    default: '',
    trim: true
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

const matchingSessionSchema = new mongoose.Schema({
  host_id: {
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
  court_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Court',
    required: true
  },
  booking_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking',
    default: null
  },
  fixed_schedule_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'FixedSchedule',
    default: null,
    index: true
  },
  booking_date: {
    type: String, // Định dạng "YYYY-MM-DD"
    required: true,
    index: true
  },
  start_minutes: {
    type: Number, // Số phút tính từ 00:00 (Ví dụ: 540 = 9:00 AM)
    required: true
  },
  end_minutes: {
    type: Number, // Ví dụ: 600 = 10:00 AM
    required: true
  },
  total_players_needed: {
    type: Number, // Số lượng chân cần tuyển thêm
    required: true,
    min: 1
  },
  team_mode: {
    type: String,
    enum: ['INDIVIDUAL', 'TEAM_FILL', 'TEAM_VS_TEAM'],
    default: 'INDIVIDUAL'
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
  teams: {
    type: [matchingTeamSchema],
    default: []
  },
  description: {
    type: String,
    default: '',
    trim: true
  },
  auto_approve: {
    type: Boolean,
    default: true // Nếu true, người chơi tham gia sẽ tự động APPROVED
  },
  payment_policy: {
    type: String,
    enum: ['HOST_PAY_ALL', 'SPLIT_EQUALLY', 'TEAM_REPRESENTATIVES_SPLIT'],
    default: 'HOST_PAY_ALL'
  },
  members: {
    type: [matchingMemberSchema],
    default: []
  },
  status: {
    type: String,
    enum: ['OPEN', 'FULL', 'CANCELLED', 'COMPLETED'],
    default: 'OPEN',
    index: true
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

// Chỉ cho phép Host có 1 trận đấu hoạt động tại cùng một khung giờ
matchingSessionSchema.index(
  { host_id: 1, booking_date: 1, start_minutes: 1 },
  {
    unique: true,
    partialFilterExpression: { status: { $in: ['OPEN', 'FULL'] } }
  }
);

matchingSessionSchema.index(
  { fixed_schedule_id: 1, booking_date: 1, start_minutes: 1 },
  {
    unique: true,
    partialFilterExpression: { fixed_schedule_id: { $exists: true, $ne: null } }
  }
);

matchingSessionSchema.index(
  { fixed_schedule_id: 1, booking_date: 1, start_minutes: 1, court_id: 1 },
  {
    unique: true,
    partialFilterExpression: { fixed_schedule_id: { $exists: true, $ne: null } }
  }
);

const MatchingSession = mongoose.model('MatchingSession', matchingSessionSchema);

module.exports = MatchingSession;
