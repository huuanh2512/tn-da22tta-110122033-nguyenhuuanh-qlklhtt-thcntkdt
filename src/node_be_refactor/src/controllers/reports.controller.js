const reportService = require('../services/report.service');
const { sendError } = require('../utils/response.util');

const getCourtPerformance = async (req, res) => {
  try {
    const report = await reportService.getCourtPerformance(req.query, req.user);
    return res.status(200).json({
      success: true,
      message: 'Court performance report retrieved successfully',
      report
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 500,
      error.message,
      error.code || 'REPORT_ERROR'
    );
  }
};

const getAdvancedPerformance = async (req, res) => {
  try {
    const report = await reportService.getAdvancedPerformance(req.query, req.user);
    return res.status(200).json({
      success: true,
      message: 'Advanced performance report retrieved successfully',
      report
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 500,
      error.message,
      error.code || 'REPORT_ERROR'
    );
  }
};

module.exports = {
  getCourtPerformance,
  getAdvancedPerformance
};
