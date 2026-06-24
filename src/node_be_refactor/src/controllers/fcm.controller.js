const fcmService = require('../services/fcm.service');
const { sendSuccess, sendError } = require('../utils/response.util');

class FCMController {
  /**
   * POST /api/v1/user/register-fcm
   * Đăng ký FCM token từ thiết bị mobile
   */
  async registerFCMToken(req, res) {
    try {
      const userId = req.user.id;
      const { token } = req.body;

      if (!token) {
        return sendError(res, 400, 'FCM token is required', 'MISSING_TOKEN');
      }

      const result = await fcmService.registerFCMToken(userId, token);
      return res.status(200).json({
        success: result.success,
        message: result.message,
        fcmTokenCount: result.fcmTokenCount
      });
    } catch (error) {
      console.error('FCM registration error:', error);
      return sendError(res, 500, error.message, 'FCM_REGISTER_ERROR');
    }
  }

  /**
   * POST /api/v1/user/remove-fcm
   * Gỡ bỏ FCM token khi người dùng logout
   */
  async removeFCMToken(req, res) {
    try {
      const userId = req.user.id;
      const { token } = req.body;

      if (!token) {
        return sendError(res, 400, 'FCM token is required', 'MISSING_TOKEN');
      }

      const result = await fcmService.removeFCMToken(userId, token);
      return res.status(200).json({
        success: result.success,
        message: result.message
      });
    } catch (error) {
      console.error('FCM removal error:', error);
      return sendError(res, 500, error.message, 'FCM_REMOVE_ERROR');
    }
  }
}

module.exports = new FCMController();
