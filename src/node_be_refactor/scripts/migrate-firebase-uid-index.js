require('dotenv').config();

const mongoose = require('mongoose');
const User = require('../src/models/user.model');

async function migrateFirebaseUidIndex() {
  const nullResult = await User.updateMany(
    { firebaseUid: { $type: 10 } },
    { $unset: { firebaseUid: '' } }
  );
  const blankResult = await User.updateMany(
    { firebaseUid: { $type: 'string', $regex: /^\s*$/ } },
    { $unset: { firebaseUid: '' } }
  );

  const indexes = await User.collection.indexes();
  if (indexes.some((index) => index.name === 'firebaseUid_1')) {
    await User.collection.dropIndex('firebaseUid_1');
    console.log('[firebaseUid migration] Dropped legacy firebaseUid_1 index.');
  }

  const duplicates = await User.aggregate([
    { $match: { firebaseUid: { $type: 'string' } } },
    { $group: { _id: '$firebaseUid', count: { $sum: 1 } } },
    { $match: { count: { $gt: 1 } } },
    { $limit: 5 }
  ]);
  if (duplicates.length > 0) {
    throw new Error(
      `Cannot create unique firebaseUid index: ${duplicates.length} duplicate UID value(s) found. Resolve these accounts before retrying.`
    );
  }

  const indexName = await User.collection.createIndex(
    { firebaseUid: 1 },
    {
      name: 'firebaseUid_valid_unique',
      unique: true,
      partialFilterExpression: { firebaseUid: { $type: 'string' } }
    }
  );

  console.log('[firebaseUid migration] Complete.', {
    unsetNull: nullResult.modifiedCount,
    unsetBlank: blankResult.modifiedCount,
    indexName
  });
}

async function main() {
  if (!process.env.MONGODB_URI) {
    throw new Error('MONGODB_URI is required to migrate the firebaseUid index.');
  }
  await mongoose.connect(process.env.MONGODB_URI);
  try {
    await migrateFirebaseUidIndex();
  } finally {
    await mongoose.disconnect();
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error('[firebaseUid migration] Failed:', error.message);
    process.exit(1);
  });
}

module.exports = { migrateFirebaseUidIndex };
