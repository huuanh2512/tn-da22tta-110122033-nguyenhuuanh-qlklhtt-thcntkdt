const sportService = require('../services/sport.service');
const { sendSuccess, sendError } = require('../utils/response.util');

const querySports = async (req, res) => {
  try {
    const { skip, limit, ...filters } = req.query;
    const result = await sportService.querySports(filters, skip, limit);
    return res.status(200).json({
      success: true,
      message: 'Sports retrieved successfully',
      items: result.items,
      total: result.total
    });
  } catch (error) {
    return sendError(res, 500, error.message, 'QUERY_ERROR');
  }
};

const createSport = async (req, res) => {
  try {
    const { name, description, teamSize, active, iconUrl } = req.body;
    if (!name) {
      return sendError(res, 400, 'Sport name is required', 'MISSING_FIELDS');
    }

    const result = await sportService.createSport({
      name,
      description,
      teamSize,
      active,
      iconUrl
    });
    return res.status(200).json({
      success: true,
      message: 'Sport created successfully',
      sport: result.sport
    });
  } catch (error) {
    return sendError(res, 500, error.message, 'CREATE_ERROR');
  }
};

const updateSport = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, teamSize, active, iconUrl } = req.body;
    
    const result = await sportService.updateSport(id, {
      name,
      description,
      teamSize,
      active,
      iconUrl
    });
    return res.status(200).json({
      success: true,
      message: 'Sport updated successfully',
      sport: result.sport
    });
  } catch (error) {
    return sendError(res, 400, error.message, 'UPDATE_ERROR');
  }
};

const deleteSport = async (req, res) => {
  try {
    const { id } = req.params;
    await sportService.deleteSport(id);
    return sendSuccess(res, null, 'Sport deleted successfully', 'DELETE_SUCCESS');
  } catch (error) {
    return sendError(res, 400, error.message, 'DELETE_ERROR');
  }
};

module.exports = {
  querySports,
  createSport,
  updateSport,
  deleteSport
};
