require('dotenv').config();

const test = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const User = require('../src/models/user.model');
const { migrateFirebaseUidIndex } = require('./migrate-firebase-uid-index');

const PREFIX = `firebase-uid-index-${Date.now()}`;
const email = (suffix) => `${PREFIX}-${suffix}@example.test`;

test('firebaseUid is optional and only valid values are unique', async (t) => {
  if (!process.env.MONGODB_URI) {
    t.skip('MONGODB_URI is not configured');
    return;
  }

  await mongoose.connect(process.env.MONGODB_URI);
  try {
    await migrateFirebaseUidIndex();
    await migrateFirebaseUidIndex();

    await User.create({ email: email('missing-a'), profile: { name: 'Missing A' } });
    await User.create({ email: email('missing-b'), profile: { name: 'Missing B' } });
    await User.create({ email: email('null'), firebaseUid: null, profile: { name: 'Null UID' } });
    await User.create({ email: email('blank'), firebaseUid: '   ', profile: { name: 'Blank UID' } });

    const [nullUser, blankUser] = await Promise.all([
      User.findOne({ email: email('null') }),
      User.findOne({ email: email('blank') })
    ]);
    assert.equal(nullUser.firebaseUid, undefined);
    assert.equal(blankUser.firebaseUid, undefined);

    await User.create({ email: email('uid-a'), firebaseUid: 'firebase-unique-id' });
    await assert.rejects(
      User.create({ email: email('uid-b'), firebaseUid: 'firebase-unique-id' }),
      (error) => error?.code === 11000
    );
  } finally {
    await User.deleteMany({ email: { $regex: new RegExp(`^${PREFIX}`) } });
    await mongoose.disconnect();
  }
});
