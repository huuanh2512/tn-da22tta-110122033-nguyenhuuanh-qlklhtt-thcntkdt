const multer = require('multer');
const path = require('path');
const fs = require('fs');

// ─── Cloudinary (nếu có cấu hình) ──────────────────────────────────────────
const useCloudinary = !!(
  process.env.CLOUDINARY_CLOUD_NAME &&
  process.env.CLOUDINARY_API_KEY &&
  process.env.CLOUDINARY_API_SECRET
);

let storage;

if (useCloudinary) {
  const cloudinary = require('cloudinary').v2;
  const { CloudinaryStorage } = require('multer-storage-cloudinary');

  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
  });

  storage = new CloudinaryStorage({
    cloudinary,
    params: {
      folder: 'sports_management',
      allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
      // Trả về URL https ổn định, không bị xoá khi restart
      transformation: [{ quality: 'auto', fetch_format: 'auto' }],
    },
  });

  console.log('[Upload] Sử dụng Cloudinary storage');
} else {
  // ─── Fallback: local disk (chỉ dùng khi dev local) ──────────────────────
  const uploadDir = path.join(__dirname, '../../public/uploads');
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
  }

  storage = multer.diskStorage({
    destination: function (req, file, cb) {
      cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
      const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
      const ext = path.extname(file.originalname).toLowerCase();
      cb(null, file.fieldname + '-' + uniqueSuffix + ext);
    },
  });

  console.log('[Upload] Cloudinary chưa cấu hình – dùng local disk storage');
}

const fileFilter = (req, file, cb) => {
  const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
  if (allowedMimeTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Chỉ cho phép tải lên định dạng hình ảnh (jpeg, jpg, png, webp)'), false);
  }
};

const uploadSingle = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: fileFilter,
}).single('file');

const uploadMultiple = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: fileFilter,
}).array('files', 5); // Tối đa 5 file cùng lúc

const handleUploadError = (err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    return res.status(400).json({ success: false, message: `Lỗi Multer: ${err.message}`, code: 'UPLOAD_ERROR' });
  } else if (err) {
    return res.status(400).json({ success: false, message: err.message, code: 'UPLOAD_ERROR' });
  }
  next();
};

module.exports = {
  uploadSingle,
  uploadMultiple,
  handleUploadError,
};