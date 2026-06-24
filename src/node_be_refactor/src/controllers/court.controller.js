const courtService = require('../services/court.service');
const { sendSuccess, sendError } = require('../utils/response.util');

const queryCourts = async (req, res) => {
  try {
    const { skip, limit, ...filters } = req.query;
    const result = await courtService.queryCourts(filters, skip, limit);
    return res.status(200).json({
      success: true,
      message: 'Courts retrieved successfully',
      items: result.items,
      total: result.total
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 500,
      error.message,
      error.code || 'QUERY_ERROR'
    );
  }
};

const createCourt = async (req, res) => {
  try {
    const { name, code, facilityId, sportId, status, pricePerHour } = req.body;
    if (!name || !facilityId || !sportId) {
      return sendError(res, 400, 'Name, facilityId, and sportId are required', 'MISSING_FIELDS');
    }

    const result = await courtService.createCourt({ name, code, facilityId, sportId, status, pricePerHour });
    return res.status(200).json({
      success: true,
      message: 'Court created successfully',
      court: result.court
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 500,
      error.message,
      error.code || 'CREATE_ERROR'
    );
  }
};

const updateCourt = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, code, facilityId, sportId, status, pricePerHour } = req.body;
    
    const result = await courtService.updateCourt(id, { name, code, facilityId, sportId, status, pricePerHour });
    return res.status(200).json({
      success: true,
      message: 'Court updated successfully',
      court: result.court,
      ...(result.warning && { warning: result.warning })
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 400,
      error.message,
      error.code || 'UPDATE_ERROR'
    );
  }
};

const deleteCourt = async (req, res) => {
  try {
    const { id } = req.params;
    await courtService.deleteCourt(id);
    return sendSuccess(res, null, 'Court deleted successfully', 'DELETE_SUCCESS');
  } catch (error) {
    return sendError(res, 400, error.message, 'DELETE_ERROR');
  }
};

const getCourtSlotConfig = async (req, res) => {
  try {
    const { id } = req.params;
    const bookingDate = req.query.bookingDate || req.query.date || null;
    const result = await courtService.getCourtSlotConfig(id, bookingDate);
    return res.status(200).json({
      success: true,
      message: 'Slot config retrieved successfully',
      config: result.config
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 404,
      error.message,
      error.code || 'NOT_FOUND'
    );
  }
};

const upsertCourtSlotConfig = async (req, res) => {
  try {
    const { id } = req.params;
    const { openingMinutes, closingMinutes, slotDurationMinutes, slots } = req.body;
    
    if (openingMinutes === undefined || closingMinutes === undefined || slotDurationMinutes === undefined) {
      return sendError(res, 400, 'Missing slot config parameters', 'MISSING_FIELDS');
    }

    const result = await courtService.upsertCourtSlotConfig(id, { openingMinutes, closingMinutes, slotDurationMinutes, slots });
    return res.status(200).json({
      success: true,
      message: 'Slot config updated successfully',
      config: result.config
    });
  } catch (error) {
    return sendError(res, 400, error.message, 'UPDATE_ERROR');
  }
};

module.exports = {
  queryCourts,
  createCourt,
  updateCourt,
  deleteCourt,
  getCourtSlotConfig,
  upsertCourtSlotConfig
};
