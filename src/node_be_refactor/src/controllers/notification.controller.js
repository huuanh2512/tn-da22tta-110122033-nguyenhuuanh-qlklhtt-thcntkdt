const notificationService = require('../services/notification.service');
const notificationHelper = require('../services/notification.helper');
const { sendSuccess, sendError } = require('../utils/response.util');

const getMyNotifications = async (req, res) => {
  try {
    const { skip, limit } = req.query;
    const userId = req.user.id; // Lấy từ token đăng nhập

    const result = await notificationService.queryNotifications(
      userId,
      req.user.role,
      skip,
      limit
    );
    return res.status(200).json({
      success: true,
      message: 'Notifications retrieved successfully',
      unreadCount: result.unreadCount,
      items: result.items,
      total: result.total
    });
  } catch (error) {
    return sendError(res, 500, error.message, 'QUERY_ERROR');
  }
};

const createSystemNotification = async (req, res) => {
  try {
    const { userId, title, content, body, type, audience, metadata } = req.body;
    
    if (!userId || !title || (!content && !body)) {
      return sendError(res, 400, 'User ID, title, and content are required', 'MISSING_FIELDS');
    }
    // Thay đổi từ notificationService.createNotification sang notificationHelper.notifyUser
    const result = await notificationHelper.notifyUser({ 
      userId, 
      title, 
      content: content || body, 
      type,
      audience,
      metadata,
      sendRealtime: true,
      sendFCM: true
    });
    
    return res.status(200).json({
      success: true,
      message: 'Notification created and sent successfully',
      notification: result.notification
    });
  } catch (error) {
    return sendError(res, 500, error.message, 'CREATE_ERROR');
  }
};

const markAsRead = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const result = await notificationService.markAsRead(id, userId);
    return res.status(200).json({
      success: true,
      message: 'Notification marked as read'
    });
  } catch (error) {
    return sendError(res, 404, error.message, 'NOT_FOUND');
  }
};

const markAllAsRead = async (req, res) => {
  try {
    const userId = req.user.id;
    await notificationService.markAllAsRead(userId, req.user.role);
    
    return sendSuccess(res, null, 'All notifications marked as read', 'MARK_ALL_SUCCESS');
  } catch (error) {
    return sendError(res, 500, error.message, 'UPDATE_ERROR');
  }
};

module.exports = {
  getMyNotifications,
  createSystemNotification,
  markAsRead,
  markAllAsRead
};
