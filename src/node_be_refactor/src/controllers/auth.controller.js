const userAuthService = require('../services/user-auth.service');
const { sendSuccess, sendError } = require('../utils/response.util');

const register = async (req, res) => {
  try {
    const { email, password, fullName, phone } = req.body;
    if (!email || !password) {
      return sendError(res, 400, 'Email and password are required', 'MISSING_FIELDS');
    }

    const result = await userAuthService.register(email, password, { fullName, phone });
    // Custom trả về để lồng success/message vào trong
    return res.status(200).json(result);
  } catch (error) {
    return res.status(error.statusCode || 400).json({
      success: false,
      code: error.code || 'REGISTER_ERROR',
      message: error.message,
      ...(error.data ? { data: error.data } : {})
    });
  }
};

const signIn = async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return sendError(res, 400, 'Email and password are required', 'MISSING_FIELDS');
    }

    const authData = await userAuthService.signIn(email, password);
    return res.status(200).json(authData);
  } catch (error) {
    console.error("LỖI ĐĂNG NHẬP:", error);
    return res.status(error.statusCode || 401).json({
      success: false,
      code: error.code || 'AUTH_FAILED',
      message: error.message,
      ...(error.data ? { data: error.data } : {})
    });
  }
};

const verifyEmail = async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp || !/^\d{6}$/.test(String(otp))) {
      return sendError(res, 400, 'Email và mã xác thực 6 chữ số là bắt buộc.', 'MISSING_OR_INVALID_OTP');
    }
    const result = await userAuthService.verifyEmail(email, String(otp));
    return sendSuccess(res, result, 'Xác thực email thành công.', 'EMAIL_VERIFIED');
  } catch (error) {
    return res.status(error.statusCode || 400).json({ success: false, code: error.code || 'EMAIL_VERIFICATION_ERROR', message: error.message, ...(error.data ? { data: error.data } : {}) });
  }
};

const resendVerification = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return sendError(res, 400, 'Email là bắt buộc.', 'MISSING_FIELDS');
    const result = await userAuthService.resendEmailVerification(email);
    return sendSuccess(res, result, 'Nếu tài khoản đang chờ xác thực, mã mới đã được gửi.', 'EMAIL_VERIFICATION_RESENT');
  } catch (error) {
    return res.status(error.statusCode || 400).json({ success: false, code: error.code || 'EMAIL_VERIFICATION_RESEND_ERROR', message: error.message, ...(error.data ? { data: error.data } : {}) });
  }
};

const firebaseRegister = async (req, res) => {
  try {
    const { firebaseIdToken, fullName, phone } = req.body;
    const result = await userAuthService.firebaseRegister(firebaseIdToken, { fullName, phone });
    return sendSuccess(res, result, 'Firebase account registered. Verify your email to continue.', 'FIREBASE_REGISTERED');
  } catch (error) {
    return res.status(error.statusCode || 400).json({ success: false, code: error.code || 'FIREBASE_REGISTER_ERROR', message: error.message, ...(error.data ? { data: error.data } : {}) });
  }
};

const firebaseCompleteEmailVerification = async (req, res) => {
  try {
    const result = await userAuthService.firebaseCompleteEmailVerification(req.body.firebaseIdToken);
    return res.status(200).json(result);
  } catch (error) {
    return res.status(error.statusCode || 400).json({ success: false, code: error.code || 'FIREBASE_VERIFICATION_ERROR', message: error.message, ...(error.data ? { data: error.data } : {}) });
  }
};

const firebaseLogin = async (req, res) => {
  try {
    const result = await userAuthService.firebaseLogin(req.body.firebaseIdToken);
    return res.status(200).json(result);
  } catch (error) {
    return res.status(error.statusCode || 401).json({ success: false, code: error.code || 'FIREBASE_AUTH_FAILED', message: error.message, ...(error.data ? { data: error.data } : {}) });
  }
};

const refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return sendError(res, 400, 'Refresh token is required', 'MISSING_TOKEN');
    }

    const authData = await userAuthService.refreshToken(refreshToken);
    return res.status(200).json(authData);
  } catch (error) {
    return sendError(res, 401, error.message, 'REFRESH_FAILED');
  }
};

const signOut = async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      return sendError(res, 400, 'User ID is required', 'MISSING_FIELDS');
    }
    await userAuthService.signOut(userId);
    return sendSuccess(res, null, 'Sign out successful', 'SIGNOUT_SUCCESS');
  } catch (error) {
    return sendError(res, 500, error.message, 'SIGNOUT_ERROR');
  }
};

const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email is required',
        errorCode: 'FORGOT_PASSWORD_ERROR'
      });
    }
    await userAuthService.forgotPassword(email);
    return res.status(200).json({
      success: true,
      message: 'Verification OTP sent to email',
      data: null
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Error occurred',
      errorCode: 'FORGOT_PASSWORD_ERROR'
    });
  }
};

const resetPassword = async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;
    if (!email || !otp || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Email, otp, and new password are required',
        errorCode: 'RESET_ERROR'
      });
    }
    await userAuthService.resetPassword(email, otp, newPassword);
    return res.status(200).json({
      success: true,
      message: 'Password reset successfully',
      data: null
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Error occurred',
      errorCode: 'RESET_ERROR'
    });
  }
};

const changePassword = async (req, res) => {
  try {
    const { otp, newPassword } = req.body;
    if (!otp || !newPassword) {
      return sendError(
        res,
        400,
        'OTP and new password are required',
        'MISSING_FIELDS'
      );
    }
    if (newPassword.length < 8) {
      return sendError(
        res,
        400,
        'New password must be at least 8 characters',
        'WEAK_PASSWORD'
      );
    }

    await userAuthService.changePassword(
      req.user.id,
      otp,
      newPassword
    );
    return sendSuccess(
      res,
      null,
      'Password changed successfully',
      'PASSWORD_CHANGED'
    );
  } catch (error) {
    const statusCode = [
      'INVALID_OTP',
      'EXPIRED_OTP',
      'PASSWORD_UNCHANGED'
    ].includes(error.code)
      ? 400
      : error.code === 'USER_NOT_FOUND'
        ? 404
        : 500;
    return sendError(
      res,
      statusCode,
      error.message,
      error.code || 'CHANGE_PASSWORD_ERROR'
    );
  }
};

module.exports = {
  register,
  signIn,
  verifyEmail,
  resendVerification,
  firebaseRegister,
  firebaseCompleteEmailVerification,
  firebaseLogin,
  refreshToken,
  signOut,
  forgotPassword,
  resetPassword,
  changePassword
};
