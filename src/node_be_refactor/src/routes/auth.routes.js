const express = require('express');
const authController = require('../controllers/auth.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

router.post('/register', authController.register);
router.post('/sign-in', authController.signIn);
router.post('/verify-email', authController.verifyEmail);
router.post('/resend-verification', authController.resendVerification);
router.post('/firebase/register', authController.firebaseRegister);
router.post('/firebase/complete-email-verification', authController.firebaseCompleteEmailVerification);
router.post('/firebase/login', authController.firebaseLogin);
router.post('/firebase/refresh', authController.firebaseLogin);
router.post('/refresh-token', authController.refreshToken);
router.post('/sign-out', authController.signOut);
router.post('/forgot-password', authController.forgotPassword);
router.post('/reset-password', authController.resetPassword);
router.post(
  '/change-password',
  authMiddleware.verifyToken,
  authMiddleware.requireRole(['CUSTOMER', 'STAFF', 'ADMIN']),
  authController.changePassword
);

module.exports = router;
