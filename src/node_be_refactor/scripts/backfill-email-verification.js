require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../src/models/user.model');

async function run() {
  if (!process.env.MONGODB_URI) throw new Error('MONGODB_URI is required');
  await mongoose.connect(process.env.MONGODB_URI);
  const now = new Date();
  const result = await User.updateMany(
    { emailVerifiedAt: { $exists: false } },
    {
      $set: {
        status: 'ACTIVE',
        emailVerifiedAt: now,
        emailVerificationOtpHash: null,
        emailVerificationExpiresAt: null,
        emailVerificationAttempts: 0,
        emailVerificationLastSentAt: null,
        emailVerificationLockedUntil: null
      }
    }
  );
  console.log(`Backfilled ${result.modifiedCount} existing users as ACTIVE.`);
  await mongoose.disconnect();
}

run().catch(async (error) => {
  console.error('Email verification backfill failed:', error.message);
  await mongoose.disconnect().catch(() => undefined);
  process.exitCode = 1;
});
