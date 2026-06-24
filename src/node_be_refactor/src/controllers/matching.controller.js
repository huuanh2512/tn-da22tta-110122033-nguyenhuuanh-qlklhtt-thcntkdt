const matchingService = require('../services/matching.service');
const { sendSuccess, sendError } = require('../utils/response.util');

const createSession = async (req, res) => {
  try {
    const { sportId, facilityId, bookingDate, startMinutes, endMinutes, totalPlayersNeeded } = req.body;
    const isTeamMode = ['TEAM_FILL', 'TEAM_VS_TEAM'].includes(req.body.teamMode);
    
    if (
      !sportId
      || !facilityId
      || !bookingDate
      || startMinutes === undefined
      || endMinutes === undefined
      || (!isTeamMode && !totalPlayersNeeded)
      || (isTeamMode && !req.body.teamSize)
    ) {
      return sendError(res, 400, 'Thiếu thông tin bắt buộc để tạo phòng ghép trận', 'MISSING_FIELDS');
    }

    const result = await matchingService.createSession(req.body, req.user.id);
    return sendSuccess(res, result.session, 'Tạo phòng ghép trận thành công', 'CREATE_SUCCESS');
  } catch (error) {
    return sendError(res, error.statusCode || 500, error.message, error.code || 'CREATE_ERROR');
  }
};

const querySessions = async (req, res) => {
  try {
    const { skip, limit, ...filters } = req.query;
    const result = await matchingService.querySessions(filters, skip, limit, req.user?.id);
    return res.status(200).json({
      success: true,
      message: 'Lấy danh sách phòng ghép thành công',
      items: result.items,
      total: result.total
    });
  } catch (error) {
    return sendError(res, error.statusCode || 500, error.message, error.code || 'QUERY_ERROR');
  }
};

const getSessionDetail = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await matchingService.getSessionDetail(id, req.user?.id);
    return sendSuccess(res, result.session, 'Lấy chi tiết phòng ghép thành công');
  } catch (error) {
    return sendError(res, error.statusCode || 404, error.message, error.code || 'NOT_FOUND');
  }
};

const joinSession = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await matchingService.joinSession(id, req.user.id, req.body || {});
    return sendSuccess(res, result.session, 'Đăng ký tham gia phòng ghép thành công', 'JOIN_SUCCESS');
  } catch (error) {
    return sendError(res, error.statusCode || 400, error.message, error.code || 'JOIN_ERROR');
  }
};

const leaveSession = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await matchingService.leaveSession(id, req.user.id);
    return sendSuccess(res, result.session, 'Rời phòng ghép thành công', 'LEAVE_SUCCESS');
  } catch (error) {
    return sendError(res, error.statusCode || 400, error.message, error.code || 'LEAVE_ERROR');
  }
};

const updateMemberStatus = async (req, res) => {
  try {
    const { id, userId } = req.params;
    const { status } = req.body;

    if (!status || !['APPROVED', 'REJECTED'].includes(status)) {
      return sendError(res, 400, 'Trạng thái duyệt không hợp lệ', 'INVALID_STATUS');
    }

    const result = await matchingService.updateMemberStatus(id, userId, status, req.user.id);
    return sendSuccess(res, result.session, 'Cập nhật trạng thái thành viên thành công');
  } catch (error) {
    return sendError(res, error.statusCode || 400, error.message, error.code || 'UPDATE_ERROR');
  }
};

const updateSessionStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!status || !['OPEN', 'CANCELLED', 'COMPLETED'].includes(status)) {
      return sendError(res, 400, 'Trạng thái phòng không hợp lệ', 'INVALID_STATUS');
    }

    const result = await matchingService.updateSessionStatus(id, status, req.user.id);
    if (status === 'CANCELLED') {
      const hasSuccessPayment = result.cancellationSummary?.successPayments > 0;
      return res.status(200).json({
        success: true,
        message: hasSuccessPayment
          ? 'Hủy phòng ghép thành công. Có giao dịch đã thanh toán, cần xử lý hoàn tiền thủ công.'
          : 'Hủy phòng ghép thành công',
        code: 'UPDATE_SUCCESS',
        data: result.session,
        cancellationSummary: result.cancellationSummary,
        warning: result.warning
      });
    }

    return sendSuccess(res, result.session, 'Cập nhật trạng thái phòng thành công');
  } catch (error) {
    return sendError(res, error.statusCode || 400, error.message, error.code || 'UPDATE_ERROR');
  }
};

// --- CONTROLLERS FOR AUTO-MATCHMAKING QUEUE ---

const joinQueue = async (req, res) => {
  try {
    const { sportId, facilityId, bookingDate, startMinutes, endMinutes } = req.body;

    if (!sportId || !facilityId || !bookingDate || startMinutes === undefined || endMinutes === undefined) {
      return sendError(res, 400, 'Thiếu thông tin đăng ký hàng chờ', 'MISSING_FIELDS');
    }

    const result = await matchingService.joinQueue(req.body, req.user.id);
    return sendSuccess(res, result.queue, 'Đăng ký vào hàng chờ ghép tự động thành công', 'QUEUE_JOIN_SUCCESS');
  } catch (error) {
    return sendError(res, error.statusCode || 400, error.message, error.code || 'QUEUE_ERROR');
  }
};

const leaveQueue = async (req, res) => {
  try {
    await matchingService.leaveQueue(req.user.id);
    return sendSuccess(res, null, 'Hủy hàng chờ ghép tự động thành công', 'QUEUE_LEAVE_SUCCESS');
  } catch (error) {
    return sendError(res, error.statusCode || 400, error.message, error.code || 'QUEUE_ERROR');
  }
};

const getQueueStatus = async (req, res) => {
  try {
    const result = await matchingService.getQueueStatus(req.user.id);
    return sendSuccess(res, result.active, 'Lấy trạng thái hàng chờ thành công');
  } catch (error) {
    return sendError(res, error.statusCode || 500, error.message, error.code || 'QUEUE_ERROR');
  }
};

module.exports = {
  createSession,
  querySessions,
  getSessionDetail,
  joinSession,
  leaveSession,
  updateMemberStatus,
  updateSessionStatus,
  joinQueue,
  leaveQueue,
  getQueueStatus
};
