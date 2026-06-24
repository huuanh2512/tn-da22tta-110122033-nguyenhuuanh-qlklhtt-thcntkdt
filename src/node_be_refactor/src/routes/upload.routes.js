const express = require('express');
const uploadController = require('../controllers/upload.controller');
const { uploadSingle, uploadMultiple, handleUploadError } = require('../middlewares/upload.middleware');
const authMiddleware = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(authMiddleware.verifyToken);

router.post('/single', uploadSingle, handleUploadError, uploadController.uploadSingleImage);
router.post('/multiple', uploadMultiple, handleUploadError, uploadController.uploadMultipleImages);

module.exports = router;