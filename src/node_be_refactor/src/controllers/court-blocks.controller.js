const courtBlockService = require('../services/court-block.service');
const { sendError } = require('../utils/response.util');

const createCourtBlock = async (req, res) => {
  try {
    const block = await courtBlockService.create(req.body, req.user);
    return res.status(201).json({
      success: true,
      message: 'Court block created successfully',
      block
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

const queryCourtBlocks = async (req, res) => {
  try {
    const items = await courtBlockService.query(req.query, req.user);
    return res.status(200).json({
      success: true,
      message: 'Court blocks retrieved successfully',
      items,
      total: items.length
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

const updateCourtBlock = async (req, res) => {
  try {
    const block = await courtBlockService.update(
      req.params.id,
      req.body,
      req.user
    );
    return res.status(200).json({
      success: true,
      message: 'Court block updated successfully',
      block
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 500,
      error.message,
      error.code || 'UPDATE_ERROR'
    );
  }
};

const cancelCourtBlock = async (req, res) => {
  try {
    const block = await courtBlockService.cancel(req.params.id, req.user);
    return res.status(200).json({
      success: true,
      message: 'Court block cancelled successfully',
      block
    });
  } catch (error) {
    return sendError(
      res,
      error.statusCode || 500,
      error.message,
      error.code || 'CANCEL_ERROR'
    );
  }
};

module.exports = {
  createCourtBlock,
  queryCourtBlocks,
  updateCourtBlock,
  cancelCourtBlock
};
