/**
 * Notification Helper
 * Hàm tiện ích để phát sóng thông báo trong các business logic khác
 */

const notificationService = require('./notification.service');
const socketIOService = require('./socket-io.service');
const fcmService = require('./fcm.service');
const User = require('../models/user.model');
const Facility = require('../models/facility.model');

class NotificationHelper {
  /**
   * Tạo và phát sóng thông báo (DB + Real-time + FCM)
   * @param {object} params - Tham số
   */
  async notifyUser(params) {
    const {
      userId,
      title,
      content,
      type = 'SYSTEM',
      audience,
      metadata = {},
      sendRealtime = true,
      sendFCM = true
    } = params;

    let notification;
    try {
      let resolvedAudience = audience;
      if (!resolvedAudience) {
        const targetUser = await User.findById(userId).select('role');
        resolvedAudience = targetUser?.role || 'ALL';
      }
      if (resolvedAudience === 'SUPER_ADMIN') {
        resolvedAudience = 'ADMIN';
      }
      notification = await notificationService.createNotification({
        userId,
        title,
        content,
        type,
        audience: resolvedAudience,
        metadata
      });
    } catch (error) {
      console.error(`Error creating notification for user ${userId}:`, error);
      throw error;
    }

    if (sendRealtime && socketIOService.io) {
      try {
        socketIOService.notifyUser(userId, notification.notification);
      } catch (error) {
        console.warn(`Realtime notification failed for user ${userId}:`, error.message);
      }
    }

    if (sendFCM) {
      try {
        await fcmService.sendPushNotification(userId, title, content, {
          type,
          ...metadata
        });
      } catch (error) {
        console.warn(`FCM notification failed for user ${userId}:`, error.message);
      }
    }

    return { success: true, notification: notification.notification };
  }

  /**
   * Thông báo cho tất cả STAFF
   */
  async notifyStaff(params) {
    const {
      title,
      content,
      type = 'SYSTEM',
      metadata = {}
    } = params;

    try {
      // 1. Tìm tất cả User có role là STAFF
      const staffUsers = await User.find({ role: 'STAFF' });

      // 2. Gửi thông báo đến từng staff (DB + Real-time + FCM)
      const promises = staffUsers.map(user =>
        this.notifyUser({
          userId: user._id.toString(),
          title,
          content,
          type,
          audience: 'STAFF',
          metadata
        }).catch(err => console.error(`Error notifying staff ${user._id}:`, err))
      );
      await Promise.all(promises);

      return { success: true };
    } catch (error) {
      console.error('Error in notifyStaff:', error);
      throw error;
    }
  }

  /**
   * Thông báo cho tất cả ADMIN
   */
  async notifyAdmin(params) {
    const {
      title,
      content,
      type = 'SYSTEM',
      metadata = {}
    } = params;

    try {
      // 1. Tìm tất cả User có role là ADMIN
      const adminUsers = await User.find({ role: { $in: ['ADMIN', 'SUPER_ADMIN'] } });

      // 2. Gửi thông báo đến từng admin (DB + Real-time + FCM)
      const promises = adminUsers.map(user =>
        this.notifyUser({
          userId: user._id.toString(),
          title,
          content,
          type,
          audience: 'ADMIN',
          metadata
        }).catch(err => console.error(`Error notifying admin ${user._id}:`, err))
      );
      await Promise.all(promises);

      return { success: true };
    } catch (error) {
      console.error('Error in notifyAdmin:', error);
      throw error;
    }
  }

  /**
   * Thông báo cho nhân viên và admin (phòng staff + admin)
   */
  async notifyFacilityStaff(params) {
    const {
      facilityId,
      title,
      content,
      type = 'SYSTEM',
      metadata = {}
    } = params;

    if (!facilityId) {
      console.warn('[Notification] Missing facilityId, skip facility staff notification');
      return { success: false };
    }

    try {
      const facility = await Facility.findById(facilityId).select('staff_ids');
      const staffIds = new Set((facility?.staff_ids || []).map(id => id.toString()));

      const scopedStaff = await User.find({
        role: 'STAFF',
        $or: [
          { facility_id: facilityId },
          { _id: { $in: Array.from(staffIds) } }
        ]
      });

      if (scopedStaff.length === 0) {
        console.warn(`[Notification] No staff found for facility ${facilityId}`);
        return { success: true };
      }

      const promises = scopedStaff.map(user =>
        this.notifyUser({
          userId: user._id.toString(),
          title,
          content,
          type,
          audience: 'STAFF',
          metadata
        }).catch(err => console.error(`Error notifying facility staff ${user._id}:`, err))
      );
      await Promise.all(promises);

      return { success: true };
    } catch (error) {
      console.error('Error in notifyFacilityStaff:', error);
      throw error;
    }
  }

  async notifyStaffAndAdmin(params) {
    const { title, content, type = 'SYSTEM', metadata = {} } = params;

    try {
      // 1. Tìm tất cả User có role là STAFF hoặc ADMIN
      const staffAndAdminUsers = await User.find({ role: { $in: ['STAFF', 'ADMIN', 'SUPER_ADMIN'] } });

      // 2. Gửi thông báo đến từng người (DB + Real-time + FCM)
      const promises = staffAndAdminUsers.map(user =>
        this.notifyUser({
          userId: user._id.toString(),
          title,
          content,
          type,
          audience: user.role === 'SUPER_ADMIN' ? 'ADMIN' : user.role,
          metadata
        }).catch(err => console.error(`Error notifying staff/admin ${user._id}:`, err))
      );
      await Promise.all(promises);

      return { success: true };
    } catch (error) {
      console.error('Error in notifyStaffAndAdmin:', error);
      throw error;
    }
  }

  /**
   * Thông báo bản đặt sân được tạo (Customer → Staff/Admin)
   */
  async notifyBookingCreated(booking) {
    try {
      const customerId = booking.customerId || booking.user_id?._id?.toString() || booking.user_id?.toString() || booking.userId;
      const customerName = booking.customerName || booking.guest_name || booking.user_id?.profile?.name || 'Khách';
      const courtName = booking.courtName || booking.court_id?.name || 'sân thể thao';
      const bookingDate = booking.bookingDate || booking.booking_date || 'hôm nay';
      const bookingId = booking._id?.toString() || booking.id;

      const title = 'Đặt sân mới';
      const content = `Khách hàng ${customerName} vừa đặt sân ${courtName} vào ngày ${bookingDate}`;

      // Thông báo cho staff và admin
      await this.notifyStaffAndAdmin({
        title,
        content,
        type: 'BOOKING',
        metadata: {
          bookingId,
          link: `/bookings/${bookingId}`
        }
      });

      // Thông báo cho customer (xác nhận đặt sân)
      if (customerId) {
        await this.notifyUser({
          userId: customerId,
          title: 'Đặt sân thành công',
          content: `Lịch đặt sân của bạn vào ngày ${bookingDate} đã được gửi và đang chờ duyệt.`,
          type: 'BOOKING',
          audience: 'CUSTOMER',
          metadata: {
            bookingId,
            link: `/bookings/${bookingId}`
          }
        });
      }

      return { success: true };
    } catch (error) {
      console.error('Error in notifyBookingCreated:', error);
      throw error;
    }
  }

  /**
   * Thông báo bản đặt sân được duyệt
   */
  async notifyBookingApproved(booking) {
    try {
      const customerId = booking.customerId || booking.user_id?._id?.toString() || booking.user_id?.toString() || booking.userId;
      if (!customerId) return { success: true };
      const bookingDate = booking.bookingDate || booking.booking_date || 'hôm nay';
      const bookingId = booking._id?.toString() || booking.id;

      const title = 'Đặt sân được duyệt';
      const content = `Lịch đặt sân của bạn vào ngày ${bookingDate} đã được duyệt. Vui lòng thanh toán để hoàn tất.`;

      await this.notifyUser({
        userId: customerId,
        title,
        content,
        type: 'BOOKING',
        audience: 'CUSTOMER',
        metadata: {
          bookingId,
          link: `/bookings/${bookingId}`
        }
      });

      return { success: true };
    } catch (error) {
      console.error('Error in notifyBookingApproved:', error);
      throw error;
    }
  }

  /**
   * Thông báo bản đặt sân bị hủy
   */
  async notifyBookingCancelled(booking, reason = 'Hủy bởi quản trị viên') {
    try {
      const customerId = booking.customerId || booking.user_id?._id?.toString() || booking.user_id?.toString() || booking.userId;
      if (!customerId) return { success: true };
      const bookingDate = booking.bookingDate || booking.booking_date || 'hôm nay';
      const bookingId = booking._id?.toString() || booking.id;

      const title = 'Đặt sân bị hủy';
      const content = `Lịch đặt sân của bạn vào ngày ${bookingDate} đã bị hủy. Lý do: ${reason}`;

      await this.notifyUser({
        userId: customerId,
        title,
        content,
        type: 'BOOKING',
        audience: 'CUSTOMER',
        metadata: {
          bookingId,
          link: `/bookings/${bookingId}`
        }
      });

      return { success: true };
    } catch (error) {
      console.error('Error in notifyBookingCancelled:', error);
      throw error;
    }
  }

  /**
   * Thông báo thanh toán thành công
   */
  async notifyBookingAutoCancelled(booking) {
    const customerId = booking.customerId || booking.user_id?._id?.toString() || booking.user_id?.toString() || booking.userId;
    const bookingId = booking._id?.toString() || booking.id;
    const facilityId = booking.court_id?.facility_id?._id?.toString()
      || booking.court_id?.facility_id?.toString()
      || booking.facilityId;

    try {
      if (customerId) await this.notifyUser({
        userId: customerId,
        title: 'Đặt sân đã bị hủy tự động',
        content: 'Đơn đặt sân của bạn đã bị hủy tự động vì chưa được nhân viên duyệt trước giờ bắt đầu 10 phút.',
        type: 'BOOKING',
        audience: 'CUSTOMER',
        metadata: {
          bookingId,
          link: `/bookings/${bookingId}`
        }
      });
    } catch (error) {
      console.error(`Customer auto-cancel notification failed for booking ${bookingId}:`, error);
    }

    if (!facilityId) {
      console.warn(`[Notification] Cannot resolve facility for auto-cancelled booking ${bookingId}`);
      return { success: true };
    }

    try {
      await this.notifyFacilityStaff({
        facilityId,
        title: 'Có đơn đặt sân bị hủy tự động',
        content: 'Một đơn đặt sân đã bị hủy tự động vì chưa được duyệt trước giờ bắt đầu 10 phút.',
        type: 'BOOKING',
        metadata: {
          bookingId,
          link: `/bookings/${bookingId}`
        }
      });
    } catch (error) {
      console.error(`Facility staff auto-cancel notification failed for booking ${bookingId}:`, error);
    }

    return { success: true };
  }

  async notifyPaymentSuccess(payment) {
    try {
      const bookingCustomerId = payment.booking_id?.user_id?._id?.toString()
        || payment.booking_id?.user_id?.toString();
      const paymentUserId = payment.user_id?._id?.toString()
        || payment.user_id?.toString()
        || payment.userId;
      const customerId = payment.customerId
        || (payment.booking_id ? bookingCustomerId : paymentUserId);
      if (!customerId) return { success: true };

      const bookingId = payment.bookingId || payment.booking_id?._id?.toString() || payment.booking_id?.toString() || payment.booking_id;
      const paymentId = payment._id?.toString() || payment.id;
      const amount = payment.amount;

      const title = 'Thanh toán thành công 🎉';
      const content = `Thanh toán ${amount ? Number(amount).toLocaleString('vi-VN') : '...'} VNĐ cho lịch đặt sân đã được xác nhận thành công. Cảm ơn bạn đã sử dụng dịch vụ!`;

      await this.notifyUser({
        userId: customerId,
        title,
        content,
        type: 'PAYMENT',
        audience: 'CUSTOMER',
        metadata: {
          paymentId,
          bookingId,
          link: `/payments/${paymentId}`
        }
      });

      return { success: true };
    } catch (error) {
      console.error('Error in notifyPaymentSuccess:', error);
      throw error;
    }
  }

  /**
   * Thông báo thanh toán thất bại
   */
  async notifyPaymentFailed(payment, reason = 'Thanh toán bị từ chối') {
    try {
      const bookingCustomerId = payment.booking_id?.user_id?._id?.toString()
        || payment.booking_id?.user_id?.toString();
      const paymentUserId = payment.user_id?._id?.toString()
        || payment.user_id?.toString()
        || payment.userId;
      const customerId = payment.customerId
        || (payment.booking_id ? bookingCustomerId : paymentUserId);
      const bookingId = payment.bookingId || payment.booking_id?._id?.toString() || payment.booking_id?.toString() || payment.booking_id;
      const paymentId = payment._id?.toString() || payment.id;
      const amount = payment.amount;

      const title = 'Thanh toán thất bại';
      const content = `Thanh toán ${amount ? Number(amount).toLocaleString('vi-VN') : '...'} VNĐ cho lịch đặt sân không thành công. Lý do: ${reason}. Vui lòng thử lại.`;

      await this.notifyUser({
        userId: customerId,
        title,
        content,
        type: 'PAYMENT',
        audience: 'CUSTOMER',
        metadata: {
          paymentId,
          bookingId,
          link: `/payments/${paymentId}`
        }
      });

      return { success: true };
    } catch (error) {
      console.error('Error in notifyPaymentFailed:', error);
      throw error;
    }
  }
}

module.exports = new NotificationHelper();
