const paymentRepository = require('../repositories/payment.repository');
const Booking = require('../models/booking.model');
const User = require('../models/user.model');
const notificationHelper = require('./notification.helper');

class PaymentService {
  _formatPaymentResponse(payment) {
    return {
      id: payment._id.toString(),
      user: payment.user_id ? {
        id: payment.user_id._id?.toString() || payment.user_id.toString(),
        name: payment.user_id.profile?.name || '',
        email: payment.user_id.email || ''
      } : null,
      booking: payment.booking_id ? {
        id: payment.booking_id._id?.toString() || payment.booking_id.toString(),
        courtName: payment.booking_id.court_id?.name || '',
        court: payment.booking_id.court_id ? {
          id: payment.booking_id.court_id._id?.toString() || payment.booking_id.court_id.toString(),
          name: payment.booking_id.court_id.name || ''
        } : null,
        sport: payment.booking_id.court_id?.sport_id ? {
          id: payment.booking_id.court_id.sport_id._id?.toString()
            || payment.booking_id.court_id.sport_id.toString(),
          name: payment.booking_id.court_id.sport_id.name || ''
        } : null,
        bookingDate: payment.booking_id.booking_date || '',
        startMinutes: payment.booking_id.start_minutes,
        endMinutes: payment.booking_id.end_minutes,
        status: payment.booking_id.status,
        totalPrice: payment.booking_id.total_price,
        fixedScheduleId: payment.booking_id.fixed_schedule_id
          ? payment.booking_id.fixed_schedule_id.toString()
          : null,
        isFixedSchedule: payment.booking_id.is_fixed_schedule || false
      } : null,
      amount: payment.amount,
      method: payment.method,
      status: payment.status,
      transactionId: payment.transaction_id || '',
      refundedAt: payment.refunded_at
        ? new Date(payment.refunded_at).toISOString()
        : null,
      refundedBy: payment.refunded_by
        ? payment.refunded_by._id?.toString() || payment.refunded_by.toString()
        : null,
      refundReason: payment.refund_reason || null,
      createdAt: payment.created_at ? new Date(payment.created_at).toISOString() : null
    };
  }

  _businessError(message, statusCode = 400, code = 'PAYMENT_ERROR') {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  async syncPaymentOnBookingCancelled(bookingId, options = {}) {
    const payments = await paymentRepository.findManyRaw(
      { booking_id: bookingId },
      options
    );

    if (payments.length === 0) {
      console.warn(`[Payment Sync] No payment found for cancelled booking ${bookingId}`);
      return null;
    }

    const pendingIds = payments
      .filter(payment => payment.status === 'PENDING')
      .map(payment => payment._id);
    if (pendingIds.length > 0) {
      await paymentRepository.updateMany(
        { _id: { $in: pendingIds } },
        { status: 'CANCELLED' },
        options
      );
    }

    const successPayments = payments.filter(payment => payment.status === 'SUCCESS');
    if (successPayments.length > 0) {
      console.warn(`[Payment Sync] Booking ${bookingId} has SUCCESS payments; refund is not automated by current matching policy.`);
    }

    return {
      status: pendingIds.length > 0 ? 'CANCELLED' : null,
      cancelledCount: pendingIds.length,
      successCount: successPayments.length
    };
  }

  async queryPaymentByBookingId(bookingId, options = {}) {
    return await paymentRepository.findOne({ booking_id: bookingId }, options);
  }

  async queryMyPaymentForBooking(bookingId, userId, options = {}) {
    if (!bookingId || !userId) return null;
    return await paymentRepository.findRawOne(
      { booking_id: bookingId, user_id: userId },
      options
    );
  }

  _splitAmount(totalAmount, userIds) {
    const normalizedTotal = Math.round(Number(totalAmount || 0));
    if (userIds.length === 0) return [];

    const baseAmount = Math.floor(normalizedTotal / userIds.length);
    const remainder = normalizedTotal - baseAmount * userIds.length;

    return userIds.map((userId, index) => ({
      userId,
      // The first participant is the host, so any indivisible VND remainder stays with host.
      amount: baseAmount + (index === 0 ? remainder : 0)
    }));
  }

  async createPendingPaymentIfMissing({ bookingId, userId, amount, method = 'BANK_TRANSFER' }, options = {}) {
    const existing = await paymentRepository.findRawOne(
      {
        booking_id: bookingId,
        user_id: userId,
        status: { $in: ['PENDING', 'SUCCESS'] }
      },
      options
    );

    if (existing) return existing;

    return await paymentRepository.create(
      {
        booking_id: bookingId,
        user_id: userId,
        amount,
        method,
        status: 'PENDING',
        transaction_id: ''
      },
      options
    );
  }

  async createPendingPaymentsForMatching({ booking, hostUserId, memberUserIds = [], paymentPolicy }, options = {}) {
    const bookingId = booking._id || booking;
    const totalAmount = booking.total_price || 0;

    if (paymentPolicy === 'SPLIT_EQUALLY') {
      const userIds = [
        hostUserId.toString(),
        ...memberUserIds.map(id => id.toString())
      ];
      const shares = this._splitAmount(totalAmount, userIds);
      const payments = [];
      for (const share of shares) {
        payments.push(await this.createPendingPaymentIfMissing({
          bookingId,
          userId: share.userId,
          amount: share.amount
        }, options));
      }
      return payments;
    }

    return [
      await this.createPendingPaymentIfMissing({
        bookingId,
        userId: hostUserId,
        amount: Math.round(Number(totalAmount || 0))
      }, options)
    ];
  }

  async hasSuccessfulPaymentForBooking(bookingId, options = {}) {
    const payment = await paymentRepository.findRawOne(
      { booking_id: bookingId, status: 'SUCCESS' },
      options
    );
    return Boolean(payment);
  }

  async cancelPendingPaymentForUser(bookingId, userId, options = {}) {
    return await paymentRepository.updateMany(
      { booking_id: bookingId, user_id: userId, status: 'PENDING' },
      { status: 'CANCELLED' },
      options
    );
  }

  async syncSplitPaymentsForSession({
    booking,
    hostUserId,
    memberUserIds = []
  }, options = {}) {
    const bookingId = booking._id || booking;
    const participantIds = [
      hostUserId.toString(),
      ...memberUserIds.map(id => id.toString())
    ].filter((userId, index, all) => all.indexOf(userId) === index);
    const participantIdSet = new Set(participantIds);
    const payments = await paymentRepository.findManyRaw(
      { booking_id: bookingId },
      options
    );

    const departedPendingIds = payments
      .filter(payment => (
        payment.status === 'PENDING'
        && !participantIdSet.has(payment.user_id.toString())
      ))
      .map(payment => payment._id);

    if (departedPendingIds.length > 0) {
      await paymentRepository.updateMany(
        { _id: { $in: departedPendingIds }, status: 'PENDING' },
        { status: 'CANCELLED' },
        options
      );
    }

    const shares = this._splitAmount(booking.total_price || 0, participantIds);
    for (const share of shares) {
      const activePayment = payments.find(payment => (
        payment.user_id.toString() === share.userId
        && ['PENDING', 'SUCCESS'].includes(payment.status)
      ));

      if (activePayment?.status === 'PENDING') {
        await paymentRepository.updateStatus(
          activePayment._id,
          { amount: share.amount },
          options
        );
      } else if (!activePayment) {
        await this.createPendingPaymentIfMissing({
          bookingId,
          userId: share.userId,
          amount: share.amount
        }, options);
      }
    }
  }

  async syncTeamRepresentativePaymentsForSession({
    session,
    booking
  }, options = {}) {
    const bookingId = booking._id || booking;
    const hostUserId = (session.host_id?._id || session.host_id).toString();
    const hostTeamCode = session.host_team_code || 'A';
    const approvedMembers = session.members.filter(member => member.status === 'APPROVED');

    const representativeForTeam = teamCode => {
      if (teamCode === hostTeamCode) return hostUserId;

      const configuredTeam = session.teams?.find(team => team.team_code === teamCode);
      const configuredRepresentativeId =
        configuredTeam?.representative_user_id?._id?.toString()
        || configuredTeam?.representative_user_id?.toString();
      const configuredMember = approvedMembers.find(member => (
        member.team_code === teamCode
        && (member.user_id?._id || member.user_id).toString() === configuredRepresentativeId
      ));
      if (configuredMember) return configuredRepresentativeId;

      const fallbackMember = approvedMembers.find(member => (
        member.team_code === teamCode
        && Number(member.represented_count || 1) > 0
      ));
      return fallbackMember
        ? (fallbackMember.user_id?._id || fallbackMember.user_id).toString()
        : null;
    };

    const opposingTeamCode = hostTeamCode === 'A' ? 'B' : 'A';
    const hostTeamRepresentativeId = representativeForTeam(hostTeamCode);
    const opposingTeamRepresentativeId = representativeForTeam(opposingTeamCode);
    if (!hostTeamRepresentativeId || !opposingTeamRepresentativeId) {
      await this.cancelPendingPaymentsForBooking(bookingId, options);
      console.warn(
        `[Payment Sync] Matching session ${session._id} is FULL but one team representative is missing. Representative payments were not created.`
      );
      return [];
    }

    const representativeIds = [
      hostTeamRepresentativeId,
      opposingTeamRepresentativeId
    ];
    const payments = await paymentRepository.findManyRaw(
      { booking_id: bookingId },
      options
    );
    const representativeIdSet = new Set(representativeIds);
    const stalePendingIds = payments
      .filter(payment => (
        payment.status === 'PENDING'
        && !representativeIdSet.has(payment.user_id.toString())
      ))
      .map(payment => payment._id);

    if (stalePendingIds.length > 0) {
      await paymentRepository.updateMany(
        { _id: { $in: stalePendingIds }, status: 'PENDING' },
        { status: 'CANCELLED' },
        options
      );
    }

    const shares = this._splitAmount(booking.total_price || 0, representativeIds);
    const syncedPayments = [];
    for (const share of shares) {
      const activePayment = payments.find(payment => (
        payment.user_id.toString() === share.userId
        && ['PENDING', 'SUCCESS'].includes(payment.status)
      ));

      if (activePayment?.status === 'PENDING') {
        syncedPayments.push(await paymentRepository.updateStatus(
          activePayment._id,
          { amount: share.amount },
          options
        ));
      } else if (activePayment) {
        syncedPayments.push(activePayment);
      } else {
        syncedPayments.push(await this.createPendingPaymentIfMissing({
          bookingId,
          userId: share.userId,
          amount: share.amount
        }, options));
      }
    }
    return syncedPayments;
  }

  async cancelPendingPaymentsForBooking(bookingId, options = {}) {
    return await paymentRepository.updateMany(
      { booking_id: bookingId, status: 'PENDING' },
      { status: 'CANCELLED' },
      options
    );
  }

  async _syncStaleCancelledBookingPayments(filters = {}) {
    const pendingQuery = { status: 'PENDING' };
    if (filters.userId) pendingQuery.user_id = filters.userId;
    if (filters.bookingId) pendingQuery.booking_id = filters.bookingId;

    const pendingPayments = await paymentRepository.findManyRaw(pendingQuery);
    if (pendingPayments.length === 0) return;

    const pendingBookingIds = pendingPayments.map(payment => payment.booking_id);
    const cancelledBookingIds = await Booking.find({
      _id: { $in: pendingBookingIds },
      status: 'CANCELLED'
    }).distinct('_id');

    if (cancelledBookingIds.length === 0) return;

    await paymentRepository.updateMany(
      {
        booking_id: { $in: cancelledBookingIds },
        status: 'PENDING'
      },
      { status: 'CANCELLED' }
    );
  }

  async queryPayments(filters, skip = 0, limit = 20) {
    await this._ensureFixedSchedulePendingPayments(filters.userId);
    await this._syncStaleCancelledBookingPayments(filters);

    const query = {};
    
    if (filters.userId) query.user_id = filters.userId;
    if (filters.bookingId) query.booking_id = filters.bookingId;
    if (filters.status) query.status = filters.status;
    if (filters.method) query.method = filters.method;

    const [payments, total] = await Promise.all([
      paymentRepository.findMany(query, parseInt(skip), parseInt(limit)),
      paymentRepository.count(query)
    ]);

    return {
      items: payments.map(p => this._formatPaymentResponse(p)),
      total: total
    };
  }

  async _ensureFixedSchedulePendingPayments(userId) {
    if (!userId) return;

    const pendingFixedBookings = await Booking.find({
      user_id: userId,
      status: 'CONFIRMED',
      is_fixed_schedule: true
    });

    for (const booking of pendingFixedBookings) {
      const existingPayment = await paymentRepository.findOne({
        booking_id: booking._id
      });
      if (existingPayment) continue;

      await paymentRepository.create({
        booking_id: booking._id,
        user_id: booking.user_id,
        amount: booking.total_price || 0,
        method: 'BANK_TRANSFER',
        status: 'PENDING',
        transaction_id: ''
      });
    }
  }

  async createPayment(data, userId) {
    const booking = await Booking.findById(data.bookingId);
    if (!booking) {
      throw this._businessError('Booking not found', 404, 'BOOKING_NOT_FOUND');
    }
    if (booking.status === 'CANCELLED') {
      throw this._businessError(
        'Không thể tạo thanh toán cho booking đã hủy.',
        409,
        'BOOKING_CANCELLED'
      );
    }
    if (booking.status !== 'CONFIRMED') {
      throw this._businessError(
        'Hóa đơn chỉ được tạo sau khi booking đã được duyệt.',
        409,
        'BOOKING_NOT_CONFIRMED'
      );
    }

    const existingPayment = await paymentRepository.findOne({
      booking_id: data.bookingId,
      status: { $in: ['PENDING', 'SUCCESS'] }
    });
    if (existingPayment) {
      return { payment: this._formatPaymentResponse(existingPayment) };
    }

    const paymentData = {
      booking_id: data.bookingId,
      user_id: userId,
      amount: data.amount,
      method: data.method || 'CASH',
      status: 'PENDING',
      transaction_id: data.transactionId || ''
    };

    let newPayment = await paymentRepository.create(paymentData);
    newPayment = await paymentRepository.findById(newPayment._id);
    
    return { payment: this._formatPaymentResponse(newPayment) };
  }

  async updatePaymentStatus(id, status, transactionId, actor = null, refundReason = null) {
    const validStatuses = [
      'PENDING',
      'SUCCESS',
      'FAILED',
      'CANCELLED',
      'REFUND_PENDING',
      'REFUNDED'
    ];
    if (!validStatuses.includes(status)) {
      throw this._businessError('Invalid payment status', 400, 'INVALID_PAYMENT_STATUS');
    }

    const currentPayment = await paymentRepository.findById(id);
    if (!currentPayment) {
      throw this._businessError('Payment not found', 404, 'PAYMENT_NOT_FOUND');
    }

    if (actor?.role === 'CUSTOMER') {
      const paymentUserId =
        currentPayment.user_id?._id?.toString()
        || currentPayment.user_id?.toString();

      if (paymentUserId !== actor.id?.toString()) {
        throw this._businessError(
          'Bạn không có quyền thanh toán hóa đơn này.',
          403,
          'FORBIDDEN'
        );
      }

      if (
        currentPayment.method === 'ZALOPAY'
        && currentPayment.status === 'SUCCESS'
        && status === 'SUCCESS'
      ) {
        return { payment: this._formatPaymentResponse(currentPayment) };
      }

      if (currentPayment.status !== 'PENDING' || status !== 'SUCCESS') {
        throw this._businessError(
          'Khách hàng chỉ có thể thanh toán hóa đơn đang chờ thanh toán.',
          409,
          'INVALID_CUSTOMER_PAYMENT_TRANSITION'
        );
      }

      if (['CASH', 'ZALOPAY'].includes(currentPayment.method)) {
        throw this._businessError(
          currentPayment.method === 'ZALOPAY'
            ? 'Giao dịch ZaloPay chỉ được xác nhận từ ZaloPay.'
            : 'Khách hàng không thể tự xác nhận thanh toán tiền mặt tại quầy.',
          409,
          currentPayment.method === 'ZALOPAY'
            ? 'CUSTOMER_ZALOPAY_CONFIRMATION_FORBIDDEN'
            : 'CUSTOMER_CASH_CONFIRMATION_FORBIDDEN'
        );
      }
    }

    if (status === 'REFUND_PENDING' || status === 'CANCELLED') {
      throw this._businessError(
        'Trạng thái này chỉ được cập nhật tự động khi booking bị hủy.',
        400,
        'PAYMENT_STATUS_MANAGED_BY_BOOKING'
      );
    }

    if (
      ['CANCELLED', 'REFUNDED'].includes(currentPayment.status) &&
      status !== currentPayment.status
    ) {
      throw this._businessError(
        'Không thể thay đổi giao dịch đã kết thúc.',
        409,
        'TERMINAL_PAYMENT_STATUS'
      );
    }

    if (
      currentPayment.status === 'REFUND_PENDING' &&
      status !== 'REFUNDED'
    ) {
      throw this._businessError(
        'Giao dịch đang chờ hoàn tiền chỉ có thể chuyển sang đã hoàn tiền.',
        409,
        'INVALID_REFUND_TRANSITION'
      );
    }

    if (
      currentPayment.booking_id?.status === 'CANCELLED' &&
      ['PENDING', 'SUCCESS'].includes(status)
    ) {
      throw this._businessError(
        'Không thể kích hoạt thanh toán cho booking đã hủy.',
        409,
        'BOOKING_CANCELLED'
      );
    }

    const updateData = { status };
    if (transactionId !== undefined) {
      updateData.transaction_id = transactionId;
    }

    if (status === 'REFUNDED') {
      if (currentPayment.status !== 'REFUND_PENDING') {
        throw this._businessError(
          'Chỉ có thể xác nhận hoàn tiền cho giao dịch đang chờ hoàn tiền.',
          409,
          'INVALID_REFUND_TRANSITION'
        );
      }

      if (!actor || !['STAFF', 'ADMIN'].includes(actor.role)) {
        throw this._businessError(
          'Bạn không có quyền xác nhận hoàn tiền.',
          403,
          'FORBIDDEN'
        );
      }

      if (actor.role === 'STAFF') {
        const staff = await User.findById(actor.id).select('facility_id');
        const staffFacilityId = staff?.facility_id?.toString();
        const paymentFacilityId =
          currentPayment.booking_id?.court_id?.facility_id?._id?.toString()
          || currentPayment.booking_id?.court_id?.facility_id?.toString();
        if (
          !staffFacilityId ||
          !paymentFacilityId ||
          staffFacilityId !== paymentFacilityId
        ) {
          throw this._businessError(
            'Bạn không có quyền hoàn tiền cho booking ngoài cơ sở được phân công.',
            403,
            'FORBIDDEN'
          );
        }
      }

      updateData.refunded_at = new Date();
      updateData.refunded_by = actor.id;
      updateData.refund_reason =
        typeof refundReason === 'string' && refundReason.trim()
          ? refundReason.trim()
          : null;
    }

    const updatedPayment = await paymentRepository.updateStatus(id, updateData);
    if (!updatedPayment) {
      throw this._businessError('Payment not found', 404, 'PAYMENT_NOT_FOUND');
    }

    // Gửi thông báo tự động (bọc trong try/catch để tránh gián đoạn tiến trình chính)
    try {
      if (status === 'SUCCESS') {
        await notificationHelper.notifyPaymentSuccess(updatedPayment);
      } else if (status === 'FAILED') {
        await notificationHelper.notifyPaymentFailed(updatedPayment);
      }
    } catch (err) {
      console.error(`Failed to send payment notification for status ${status}:`, err);
    }

    return { payment: this._formatPaymentResponse(updatedPayment) };
  }
}

module.exports = new PaymentService();
