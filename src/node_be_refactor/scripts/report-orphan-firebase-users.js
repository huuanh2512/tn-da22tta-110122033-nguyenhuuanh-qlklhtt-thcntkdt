/* Read-only Firebase/MongoDB orphan report. Never deletes or updates users. */
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../src/models/user.model');
const { getFirebaseAdmin } = require('../src/config/firebase-admin');

const ageMinutes = Number(process.env.ORPHAN_FIREBASE_MIN_AGE_MINUTES || 30);
const cutoff = Date.now() - ageMinutes * 60 * 1000;

async function main() {
  await mongoose.connect(process.env.MONGO_URI || process.env.MONGODB_URI);
  const auth = getFirebaseAdmin().auth();
  let pageToken;
  let scanned = 0;
  const orphans = [];
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const firebaseUser of page.users) {
      scanned += 1;
      const createdAt = new Date(firebaseUser.metadata.creationTime).getTime();
      if (createdAt > cutoff) continue;
      const profile = await User.exists({ firebaseUid: firebaseUser.uid });
      if (!profile) orphans.push({ uid: firebaseUser.uid, email: firebaseUser.email || null, createdAt: firebaseUser.metadata.creationTime });
    }
    pageToken = page.pageToken;
  } while (pageToken);
  console.log(JSON.stringify({ mode: 'read-only', ageMinutes, scanned, orphanCount: orphans.length, orphans }, null, 2));
}

main().catch((error) => { console.error('[orphan-report] failed:', error.message); process.exitCode = 1; }).finally(() => mongoose.disconnect());
