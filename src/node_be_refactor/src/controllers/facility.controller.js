const facilityService = require('../services/facility.service');
const { sendSuccess, sendError } = require('../utils/response.util');

const queryFacilities = async (req, res) => {
  try {
    const { skip, limit, ...filters } = req.query;
    const result = await facilityService.queryFacilities(filters, skip, limit);
    return res.status(200).json({
      success: true,
      message: 'Facilities retrieved successfully',
      items: result.items,
      total: result.total
    });
  } catch (error) {
    return sendError(res, 500, error.message, 'QUERY_ERROR');
  }
};

const createFacility = async (req, res) => {
  try {
    const { name, city, fullAddress, active, staffIds } = req.body;
    if (!name) {
      return sendError(res, 400, 'Facility name is required', 'MISSING_FIELDS');
    }

    const result = await facilityService.createFacility({ name, city, fullAddress, active, staffIds });
    return res.status(200).json({
      success: true,
      message: 'Facility created successfully',
      facility: result.facility
    });
  } catch (error) {
    return sendError(res, 500, error.message, 'CREATE_ERROR');
  }
};

const getFacilityById = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await facilityService.getFacilityById(id);
    return res.status(200).json({
      success: true,
      message: 'Facility retrieved successfully',
      facility: result.facility
    });
  } catch (error) {
    return sendError(res, 404, error.message, 'NOT_FOUND');
  }
};

const updateFacility = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, city, fullAddress, active, staffIds } = req.body;
    
    const result = await facilityService.updateFacility(
      id,
      { name, city, fullAddress, active, staffIds },
      req.user
    );
    return res.status(200).json({
      success: true,
      message: 'Facility updated successfully',
      facility: result.facility
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

const deleteFacility = async (req, res) => {
  try {
    const { id } = req.params;
    await facilityService.deleteFacility(id);
    return sendSuccess(res, null, 'Facility deleted successfully', 'DELETE_SUCCESS');
  } catch (error) {
    return sendError(res, 400, error.message, 'DELETE_ERROR');
  }
};

module.exports = {
  queryFacilities,
  createFacility,
  getFacilityById,
  updateFacility,
  deleteFacility
};
