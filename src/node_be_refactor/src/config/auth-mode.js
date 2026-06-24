const authMode = () => process.env.AUTH_MODE || 'legacy';
const isFirebaseActive = () => authMode() === 'firebase_active';
module.exports = { authMode, isFirebaseActive };
