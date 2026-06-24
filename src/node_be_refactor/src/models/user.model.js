const mongoose = require('mongoose');

const normalizeFirebaseUid = (value) => {
  if (value === null || value === undefined) return undefined;
  if (typeof value !== 'string') return value;
  const normalized = value.trim();
  return normalized || undefined;
};

const userProfileSchema = new mongoose.Schema({
  name: {
    type: String,
    default: ''
  },
  phone: {
    type: String,
    default: ''
  },
  avatar_url: {
    type: String,
    default: ''
  }
}, { _id: false });

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true
  },
  password: {
    type: String,
    required: false,
    default: null
  },
  // Firebase is optional for legacy/password accounts. Do not persist null or
  // empty values: a partial unique index below only indexes real string UIDs.
  firebaseUid: { type: String, set: normalizeFirebaseUid },
  role: {
    type: String,
    enum: ['CUSTOMER', 'STAFF', 'ADMIN'],
    default: 'CUSTOMER'
  },
  status: {
    type: String,
    enum: ['PENDING_OTP', 'PENDING_EMAIL', 'ACTIVE', 'INACTIVE', 'BANNED'],
    default: 'PENDING_OTP'
  },
  profile: {
    type: userProfileSchema,
    default: () => ({})
  },
  facility_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Facility',
    default: null
  },
  fcmTokens: [{ type: String }],
  resetPasswordOtp: {
    type: String,
    default: null
  },
  resetPasswordOtpExpires: {
    type: Date,
    default: null
  },
  emailVerifiedAt: {
    type: Date,
    default: null
  },
  authMigrationStatus: { type: String, default: null },
  authMigratedAt: { type: Date, default: null },
  migration: {
    testActivationAt: { type: Date, default: null },
    testActivationSource: { type: String, default: null }
  },
  emailVerificationOtpHash: {
    type: String,
    default: null
  },
  emailVerificationExpiresAt: {
    type: Date,
    default: null
  },
  emailVerificationAttempts: {
    type: Number,
    default: 0,
    min: 0
  },
  emailVerificationLastSentAt: {
    type: Date,
    default: null
  },
  emailVerificationLockedUntil: {
    type: Date,
    default: null
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

userSchema.index(
  { firebaseUid: 1 },
  {
    name: 'firebaseUid_valid_unique',
    unique: true,
    partialFilterExpression: { firebaseUid: { $type: 'string' } }
  }
);

const User = mongoose.model('User', userSchema);

module.exports = User;
