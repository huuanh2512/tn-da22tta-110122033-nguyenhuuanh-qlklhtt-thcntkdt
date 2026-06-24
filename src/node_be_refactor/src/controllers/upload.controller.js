const uploadService = require('../services/upload.service');
const { sendError } = require('../utils/response.util');

const uploadSingleImage = async (req, res) => {
  try {
    if (!req.file) {
      return sendError(res, 400, 'Vui lòng chọn một file để tải lên', 'MISSING_FILE');
    }
    const result = await uploadService.processSingleUpload(req.file, req);
    return res.status(200).json({
      success: true,
      message: 'Tải ảnh lên thành công',
      data: result.file
    });
  } catch (error) {
    return sendError(res, 500, error.message, 'SERVER_ERROR');
  }
};

const uploadMultipleImages = async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return sendError(res, 400, 'Vui lòng chọn ít nhất một file', 'MISSING_FILES');
    }
    const result = await uploadService.processMultipleUpload(req.files, req);
    return res.status(200).json({
      success: true,
      message: 'Tải các ảnh lên thành công',
      data: result.files
    });
  } catch (error) {
    return sendError(res, 500, error.message, 'SERVER_ERROR');
  }
};

module.exports = {
  uploadSingleImage,
  uploadMultipleImages
};