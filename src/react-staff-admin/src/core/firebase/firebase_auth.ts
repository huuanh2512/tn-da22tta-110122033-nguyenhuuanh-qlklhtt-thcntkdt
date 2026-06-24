import { getApp, getApps, initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const config = {
  apiKey: process.env.REACT_APP_FIREBASE_API_KEY,
  authDomain: process.env.REACT_APP_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.REACT_APP_FIREBASE_PROJECT_ID || 'doantotnghiep-844f6',
  appId: process.env.REACT_APP_FIREBASE_APP_ID,
};

if (!config.apiKey || !config.authDomain || !config.appId) {
  throw new Error('Firebase Web configuration is missing');
}

export const firebaseAuth = getAuth(getApps().length ? getApp() : initializeApp(config));
