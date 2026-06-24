const admin = require('firebase-admin');
const fs = require('node:fs');
const path = require('node:path');

const localServiceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

const loadCredentials = () => {
  const encoded = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (encoded?.trim()) return JSON.parse(Buffer.from(encoded.trim(), 'base64').toString('utf8'));
  if (fs.existsSync(localServiceAccountPath)) return require(localServiceAccountPath);
  return null;
};

let initializationError = null;
try {
  if (!admin.apps.length) {
    const credentials = loadCredentials();
    if (credentials) admin.initializeApp({ credential: admin.credential.cert(credentials) });
  }
} catch (error) {
  initializationError = error;
  console.error('[FirebaseAdmin] Initialization failed:', error.message);
}

const getFirebaseAdmin = () => {
  if (initializationError) throw initializationError;
  if (!admin.apps.length) throw new Error('Firebase Admin is not configured');
  return admin;
};

module.exports = { getFirebaseAdmin, isFirebaseAdminInitialized: () => admin.apps.length > 0 && !initializationError };
