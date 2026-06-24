const notificationRepository = require('../repositories/notification.repository');

class NotificationService {
  _normalizeRole(userRole) {
    const role = userRole?.toString().toUpperCase();
    if (role === 'SUPER_ADMIN') {
      return 'ADMIN';
    }

    return ['CUSTOMER', 'STAFF', 'ADMIN'].includes(role)
      ? role
      : 'CUSTOMER';
  }

  _buildVisibilityQuery(userId, userRole, additionalFilters = {}) {
    const role = this._normalizeRole(userRole);
    const audienceFilters = [
      { audience: role },
      { audience: 'ALL' }
    ];

    // Legacy records without audience are customer-facing only. Staff/admin
    // must not see older customer notifications that predate audience tagging.
    if (role === 'CUSTOMER') {
      audienceFilters.push({ audience: { $exists: false } });
    }

    return {
      userId,
      ...additionalFilters,
      $or: audienceFilters
    };
  }

  _formatNotificationResponse(notification) {
    return {
      _id: notification._id.toString(),
      userId: notification.userId.toString(),
      title: notification.title,
      content: notification.content,
      type: notification.type,
      audience: notification.audience || 'ALL',
      metadata: notification.metadata || {},
      isRead: notification.isRead,
      createdAt: notification.createdAt ? new Date(notification.createdAt).toISOString() : null
    };
  }

  async queryNotifications(userId, userRole, skip = 0, limit = 10) {
    const query = this._buildVisibilityQuery(userId, userRole);
    const unreadQuery = this._buildVisibilityQuery(userId, userRole, { isRead: false });

    const [notifications, total, unreadCount] = await Promise.all([
      notificationRepository.findMany(query, parseInt(skip), parseInt(limit)),
      notificationRepository.count(query),
      notificationRepository.count(unreadQuery)
    ]);

    return {
      items: notifications.map(n => this._formatNotificationResponse(n)),
      total,
      unreadCount
    };
  }

  async createNotification(data) {
    const notificationData = {
      userId: data.userId,
      title: data.title,
      content: data.content || data.body,
      type: data.type || 'SYSTEM',
      audience: data.audience || 'ALL',
      metadata: data.metadata || {}
    };

    const newNotification = await notificationRepository.create(notificationData);
    return { notification: this._formatNotificationResponse(newNotification) };
  }

  async markAsRead(id, userId) {
    const updatedNotification = await notificationRepository.markAsRead(id, userId);
    if (!updatedNotification) throw new Error('Notification not found or access denied');

    return { notification: this._formatNotificationResponse(updatedNotification) };
  }

  async markAllAsRead(userId, userRole) {
    const query = this._buildVisibilityQuery(userId, userRole, { isRead: false });
    await notificationRepository.markAllAsRead(query);
    return true;
  }
}

module.exports = new NotificationService();
