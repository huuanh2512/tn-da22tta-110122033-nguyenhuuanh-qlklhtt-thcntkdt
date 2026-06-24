const fixedScheduleService = require('../services/fixed-schedule.service');
const { sendSuccess, sendError } = require('../utils/response.util');

const errorStatus = (error, fallback = 500) => error.statusCode || fallback;
const errorCode = (error, fallback) => error.code || fallback;

const createFixedSchedule = async (req, res) => {
  try {
    const {
      type,
      sportId,
      facilityId,
      courtId,
      startMinutes,
      endMinutes,
      frequency,
      daysOfWeek,
      startDate,
      endDate,
      matchingConfig,
      matching_config
    } = req.body;

    if (!type || !courtId || startMinutes === undefined || endMinutes === undefined || !frequency || !startDate) {
      return sendError(res, 400, 'Thiếu thông tin đăng ký bắt buộc', 'MISSING_FIELDS');
    }

    const result = await fixedScheduleService.createFixedSchedule({
      type,
      sportId,
      facilityId,
      courtId,
      startMinutes,
      endMinutes,
      frequency,
      daysOfWeek,
      startDate,
      endDate,
      matchingConfig: matchingConfig || matching_config || null
    }, req.user.id);

    return res.status(200).json({
      success: true,
      message: 'Đăng ký lịch cố định đã được gửi, vui lòng chờ nhân viên duyệt.',
      schedule: result.schedule
    });
  } catch (error) {
    return sendError(
      res,
      errorStatus(error, 500),
      error.message,
      errorCode(error, 'CREATE_ERROR')
    );
  }
};

const queryFixedSchedules = async (req, res) => {
  try {
    const { skip, limit, ...filters } = req.query;

    const result = await fixedScheduleService.queryFixedSchedules(filters, skip, limit, req.user);

    return res.status(200).json({
      success: true,
      message: 'Lấy danh sách lịch cố định thành công',
      items: result.items,
      total: result.total
    });
  } catch (error) {
    return sendError(
      res,
      errorStatus(error, 500),
      error.message,
      errorCode(error, 'QUERY_ERROR')
    );
  }
};

const approveFixedSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await fixedScheduleService.approveFixedSchedule(id, req.user);

    return res.status(200).json({
      success: true,
      message: 'Đã duyệt lịch cố định',
      schedule: result.schedule,
      generatedBookings: result.generatedBookings
    });
  } catch (error) {
    return sendError(
      res,
      errorStatus(error, 400),
      error.message,
      errorCode(error, 'APPROVE_ERROR')
    );
  }
};

const rejectFixedSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};
    const result = await fixedScheduleService.rejectFixedSchedule(id, req.user, reason);

    return res.status(200).json({
      success: true,
      message: 'Đã từ chối lịch cố định',
      schedule: result.schedule
    });
  } catch (error) {
    return sendError(
      res,
      errorStatus(error, 400),
      error.message,
      errorCode(error, 'REJECT_ERROR')
    );
  }
};

const cancelFixedSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await fixedScheduleService.cancelFixedSchedule(id, req.user.id, req.user.role);
    const hasSuccessPayment = result.cancellationSummary?.successPayments > 0;

    return res.status(200).json({
      success: true,
      message: hasSuccessPayment
        ? 'Hủy đăng ký lịch cố định thành công. Có giao dịch đã thanh toán, cần xử lý hoàn tiền thủ công.'
        : 'Hủy đăng ký lịch cố định thành công',
      schedule: result.schedule,
      cancellationSummary: result.cancellationSummary
    });
  } catch (error) {
    return sendError(
      res,
      errorStatus(error, 400),
      error.message,
      errorCode(error, 'CANCEL_ERROR')
    );
  }
};

const cancelFixedMatchingOccurrence = async (req, res) => {
  try {
    const { id, date } = req.params;
    const result = await fixedScheduleService.cancelFixedMatchingOccurrence(
      id,
      date,
      req.user,
      req.body || {}
    );
    const hasSuccessPayment = result.cancellationSummary?.successPayments > 0;

    return res.status(200).json({
      success: true,
      message: hasSuccessPayment
        ? 'Đã hủy buổi ghép cố định. Có giao dịch đã thanh toán, cần xử lý hoàn tiền thủ công.'
        : 'Đã hủy buổi ghép cố định. Lịch cố định vẫn tiếp tục hoạt động.',
      schedule: result.schedule,
      occurrenceDate: result.occurrenceDate,
      cancellationSummary: result.cancellationSummary
    });
  } catch (error) {
    return sendError(
      res,
      errorStatus(error, 400),
      error.message,
      errorCode(error, 'FIXED_MATCHING_OCCURRENCE_CANCEL_ERROR')
    );
  }
};

const joinFixedMatchingSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await fixedScheduleService.joinFixedMatchingSchedule(id, req.user, req.body || {});

    return res.status(200).json({
      success: true,
      message: 'Tham gia đội cố định của lịch ghép thành công',
      schedule: result.schedule,
      joinMode: 'FIXED_TEAM_TEMPLATE'
    });
  } catch (error) {
    return sendError(
      res,
      errorStatus(error, 400),
      error.message,
      errorCode(error, 'FIXED_MATCHING_JOIN_ERROR')
    );
  }
};

const leaveFixedMatchingSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await fixedScheduleService.leaveFixedMatchingSchedule(id, req.user);
    const hasSuccessPayment = result.cancellationSummary?.successPayments > 0;

    return res.status(200).json({
      success: true,
      message: 'Rời lịch ghép cố định thành công',
      schedule: result.schedule,
      cancellationSummary: result.cancellationSummary,
      readinessChanged: result.readinessChanged,
      warning: hasSuccessPayment
        ? 'Có giao dịch đã thanh toán, cần xử lý hoàn tiền thủ công.'
        : null
    });
  } catch (error) {
    return sendError(
      res,
      errorStatus(error, 400),
      error.message,
      errorCode(error, 'FIXED_MATCHING_LEAVE_ERROR')
    );
  }
};

const pauseFixedSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await fixedScheduleService.pauseFixedSchedule(id, req.user);

    return res.status(200).json({
      success: true,
      message: 'Pause lịch cố định thành công',
      schedule: result.schedule
    });
  } catch (error) {
    return sendError(
      res,
      errorStatus(error, 400),
      error.message,
      errorCode(error, 'FIXED_SCHEDULE_PAUSE_ERROR')
    );
  }
};

const resumeFixedSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await fixedScheduleService.resumeFixedSchedule(id, req.user);

    return res.status(200).json({
      success: true,
      message: 'Resume lịch cố định thành công',
      schedule: result.schedule
    });
  } catch (error) {
    return sendError(
      res,
      errorStatus(error, 400),
      error.message,
      errorCode(error, 'FIXED_SCHEDULE_RESUME_ERROR')
    );
  }
};

module.exports = {
  createFixedSchedule,
  queryFixedSchedules,
  approveFixedSchedule,
  rejectFixedSchedule,
  cancelFixedSchedule,
  cancelFixedMatchingOccurrence,
  joinFixedMatchingSchedule,
  leaveFixedMatchingSchedule,
  pauseFixedSchedule,
  resumeFixedSchedule
};
