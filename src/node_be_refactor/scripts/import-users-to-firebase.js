/*
 * Safe Firebase Auth migration for existing bcrypt users.
 * Default is dry-run. Run only after backup and pilot verification:
 * MIGRATION_CONFIRM=IMPORT_BCRYPT_USERS MIGRATION_DRY_RUN=false node scripts/import-users-to-firebase.js
 */
require('dotenv').config();
const connectDB = require('../src/config/mongo');
const User = require('../src/models/user.model');
const { getFirebaseAdmin } = require('../src/config/firebase-admin');

const batchSize = 1000;
const dryRun = process.env.MIGRATION_DRY_RUN !== 'false';
const confirmed = process.env.MIGRATION_CONFIRM === 'IMPORT_BCRYPT_USERS';

const chunks = (items, size) => Array.from({ length: Math.ceil(items.length / size) }, (_, i) => items.slice(i * size, i * size + size));

async function main() {
  if (!dryRun && !confirmed) throw new Error('Set MIGRATION_CONFIRM=IMPORT_BCRYPT_USERS to run a write migration');
  await connectDB();
  const users = await User.find({ firebaseUid: null, password: { $type: 'string', $regex: /^\$2[aby]\$/ } }).select('_id email password profile status role');
  console.log(`[FirebaseMigration] ${users.length} eligible bcrypt users; dryRun=${dryRun}`);
  if (dryRun) return;

  const auth = getFirebaseAdmin().auth();
  for (const batch of chunks(users, batchSize)) {
    const records = batch.map(user => ({ uid: user._id.toString(), email: user.email, displayName: user.profile?.name || undefined, emailVerified: false, passwordHash: Buffer.from(user.password) }));
    const result = await auth.importUsers(records, { hash: { algorithm: 'BCRYPT' } });
    const failures = new Map(result.errors.map(error => [error.index, error.error.message]));
    await Promise.all(batch.map((user, index) => failures.has(index)
      ? User.updateOne({ _id: user._id }, { authMigrationStatus: `FAILED: ${failures.get(index)}` })
      : User.updateOne({ _id: user._id }, { firebaseUid: user._id.toString(), status: 'PENDING_EMAIL', emailVerifiedAt: null, authMigrationStatus: 'IMPORTED_PENDING_EMAIL', authMigratedAt: new Date() })
    ));
    console.log(`[FirebaseMigration] imported=${result.successCount} failed=${result.failureCount}`);
  }
}

main().catch(error => { console.error('[FirebaseMigration] Failed:', error); process.exitCode = 1; }).finally(() => require('mongoose').disconnect());
