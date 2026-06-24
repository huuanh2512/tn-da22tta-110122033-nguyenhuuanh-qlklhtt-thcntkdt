const jwt = require('jsonwebtoken');
const { sendError } = require('../utils/response.util');
const User = require('../models/user.model');

const verifyToken = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return sendError(res, 401, 'Unauthorized: Missing or invalid token format', 'UNAUTHORIZED');
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // Gắn thông tin user (id, role) vào req để các controller sau dùng
    const user = await User.findById(decoded.id).select('status emailVerifiedAt role firebaseUid');
    if (!user || user.status !== 'ACTIVE' || !user.emailVerifiedAt) {
      return sendError(res, 403, 'Email chưa được xác thực', 'EMAIL_NOT_VERIFIED');
    }
    if (decoded.firebaseUid && decoded.firebaseUid !== user.firebaseUid) {
      return sendError(res, 401, 'Unauthorized: Firebase identity no longer matches user', 'FIREBASE_IDENTITY_MISMATCH');
    }
    req.user = { ...decoded, role: user.role };
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return sendError(res, 401, 'Unauthorized: Token has expired', 'TOKEN_EXPIRED');
    }
    return sendError(res, 401, 'Unauthorized: Invalid token', 'UNAUTHORIZED');
  }
};

const requireRole = (roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return sendError(res, 403, 'Forbidden: You do not have permission', 'FORBIDDEN');
    }
    next();
  };
};

module.exports = {
  verifyToken,
  requireRole
};
