/*
 * One-time activation for imported legacy TEST accounts only.
 * Dry-run by default. Never run this from Render/deployment automation.
 * Write mode requires both explicit environment variables documented below.
 */
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../src/models/user.model');
const { getFirebaseAdmin } = require('../src/config/firebase-admin');

const realVerificationEmail = 'nghuuanh2004@gmail.com';
const dryRun = process.env.TEST_ACTIVATION_DRY_RUN !== 'false';
const confirmed = process.env.TEST_ACTIVATION_CONFIRM === 'ACTIVATE_LEGACY_TEST_USERS';

const summary = {
  selected: 0,
  excludedRealEmail: 0,
  skippedInactiveBanned: 0,
  skippedMissingFirebaseUid: 0,
  skippedMismatchedIdentity: 0,
  skippedAlreadyActive: 0,
  skippedMissingFirebaseUser: 0,
  updated: 0,
};

const log = (message, user) => console.log(`[LegacyTestActivation] ${message}`, user ? {
  mongoId: user._id.toString(), email: user.email, role: user.role, firebaseUid: user.firebaseUid, status: user.status,
} : '');

async function main() {
  if (!dryRun && !confirmed) throw new Error('Set TEST_ACTIVATION_CONFIRM=ACTIVATE_LEGACY_TEST_USERS and TEST_ACTIVATION_DRY_RUN=false to write');
  if (!process.env.MONGODB_URI) throw new Error('MONGODB_URI is required');
  await mongoose.connect(process.env.MONGODB_URI);
  const firebaseAuth = getFirebaseAdmin().auth();
  const users = await User.find({ authMigrationStatus: /^IMPORTED/, email: { $ne: realVerificationEmail } });

  console.log(`[LegacyTestActivation] ${dryRun ? 'DRY RUN' : 'WRITE MODE'}`);
  const realUser = await User.exists({ authMigrationStatus: /^IMPORTED/, email: realVerificationEmail });
  if (realUser) summary.excludedRealEmail += 1;

  for (const user of users) {
    if (!user.firebaseUid) { summary.skippedMissingFirebaseUid++; log('SKIP missing-firebase-uid', user); continue; }
    if (['BANNED', 'INACTIVE'].includes(user.status)) { summary.skippedInactiveBanned++; log('SKIP inactive-or-banned', user); continue; }
    let firebaseUser;
    try { firebaseUser = await firebaseAuth.getUser(user.firebaseUid); }
    catch (_) { summary.skippedMissingFirebaseUser++; log('SKIP missing-firebase-user', user); continue; }
    if (firebaseUser.email?.trim().toLowerCase() !== user.email.trim().toLowerCase()) { summary.skippedMismatchedIdentity++; log('SKIP mismatched-identity', user); continue; }
    if (firebaseUser.emailVerified && user.status === 'ACTIVE' && user.emailVerifiedAt) { summary.skippedAlreadyActive++; log('SKIP already-active', user); continue; }

    summary.selected++;
    console.log('[LegacyTestActivation] ' + (dryRun ? 'DRY RUN' : 'ACTIVATE'), {
      mongoId: user._id.toString(), email: user.email, role: user.role, firebaseUid: user.firebaseUid,
      firebaseEmailVerified: firebaseUser.emailVerified, mongoStatus: user.status, action: 'ACTIVATE',
    });
    if (!dryRun) {
      if (!firebaseUser.emailVerified) await firebaseAuth.updateUser(user.firebaseUid, { emailVerified: true });
      const now = new Date();
      await User.updateOne({ _id: user._id }, { status: 'ACTIVE', emailVerifiedAt: now, 'migration.testActivationAt': now, 'migration.testActivationSource': 'manual-legacy-test-activation' });
      summary.updated++;
    }
  }
  console.log('[LegacyTestActivation] Summary', summary);
}

main().catch(error => { console.error('[LegacyTestActivation] Failed:', error.message); process.exitCode = 1; }).finally(() => mongoose.disconnect());
