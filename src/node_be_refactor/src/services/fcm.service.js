const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const User = require('../models/user.model');

require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const serviceAccountPath = path.join(__dirname, '../config/serviceAccountKey.json');

let firebaseAdminInitialized = false;

function getFirebaseServiceAccount() {
  const base64Credentials = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;

  if (base64Credentials && base64Credentials.trim()) {
    const decodedCredentials = Buffer.from(base64Credentials.trim(), 'base64').toString('utf8');
    return {
      serviceAccount: JSON.parse(decodedCredentials),
      source: 'FIREBASE_SERVICE_ACCOUNT_BASE64'
    };
  }

  if (fs.existsSync(serviceAccountPath)) {
    return {
      serviceAccount: require(serviceAccountPath),
      source: 'src/config/serviceAccountKey.json'
    };
  }

  return null;
}

try {
  const credentials = getFirebaseServiceAccount();

  if (credentials) {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(credentials.serviceAccount)
      });
    }

    firebaseAdminInitialized = true;
    console.log(`[FCM] Firebase Admin SDK initialized successfully using ${credentials.source}.`);
  } else {
    console.warn('[FCM] Warning: Firebase credentials not configured. Set FIREBASE_SERVICE_ACCOUNT_BASE64 or place serviceAccountKey.json in src/config/. Push notifications will be mocked.');
  }
} catch (error) {
  console.error('[FCM] Error initializing Firebase Admin SDK:', error);
}

class FCMService {
  /**
   * Đăng ký hoặc cập nhật FCM token cho người dùng
   * @param {string} userId - ID người dùng
   * @param {string} token - FCM token từ thiết bị mobile
   */
  async registerFCMToken(userId, token) {
    if (!userId || !token) {
      throw new Error('User ID and FCM token are required');
    }

    // Thêm token vào mảng nếu chưa tồn tại
    const user = await User.findByIdAndUpdate(
      userId,
      { $addToSet: { fcmTokens: token } },
      { new: true }
    );

    if (!user) {
      throw new Error('User not found');
    }

    return { 
      success: true, 
      message: 'FCM token registered successfully',
      fcmTokenCount: user.fcmTokens ? user.fcmTokens.length : 0
    };
  }

  /**
   * Gỡ bỏ FCM token (khi người dùng logout hoặc gỡ cài đặt app)
   * @param {string} userId - ID người dùng
   * @param {string} token - FCM token cần xóa
   */
  async removeFCMToken(userId, token) {
    if (!userId || !token) {
      throw new Error('User ID and FCM token are required');
    }

    const user = await User.findByIdAndUpdate(
      userId,
      { $pull: { fcmTokens: token } },
      { new: true }
    );

    if (!user) {
      throw new Error('User not found');
    }

    return { 
      success: true, 
      message: 'FCM token removed successfully'
    };
  }

  /**
   * Gỡ bỏ token không hợp lệ (expire, unregistered)
   * @param {string} userId - ID người dùng
   * @param {array} invalidTokens - Mảng token không hợp lệ
   */
  async removeInvalidTokens(userId, invalidTokens) {
    if (!userId || !invalidTokens || invalidTokens.length === 0) {
      return { success: false, message: 'Invalid parameters' };
    }

    await User.findByIdAndUpdate(
      userId,
      { $pull: { fcmTokens: { $in: invalidTokens } } }
    );

    return { success: true, message: 'Invalid tokens removed' };
  }

  /**
   * Lấy danh sách FCM tokens của người dùng
   * @param {string} userId - ID người dùng
   */
  async getUserFCMTokens(userId) {
    const user = await User.findById(userId).select('fcmTokens');
    
    if (!user) {
      throw new Error('User not found');
    }

    return user.fcmTokens || [];
  }

  /**
   * Gửi push notification qua Firebase Admin SDK tới các token của người dùng
   */
  async sendPushNotification(userId, title, body, payload = {}) {
    if (!firebaseAdminInitialized) {
      console.log(`[FCM] (Mock) Push notification to user ${userId}: "${title}" - "${body}"`);
      return { 
        success: true, 
        message: 'Push notification simulated (Firebase Admin SDK not initialized)',
        note: 'Set FIREBASE_SERVICE_ACCOUNT_BASE64 or place serviceAccountKey.json in src/config/ to enable real push notifications.'
      };
    }

    const tokens = await this.getUserFCMTokens(userId);
    if (!tokens || tokens.length === 0) {
      console.log(`No FCM tokens for user ${userId}`);
      return { success: false, message: 'No FCM tokens found' };
    }

    // Convert all payload values to strings as FCM data payload only supports string values
    const stringPayload = {};
    for (const key in payload) {
      if (payload[key] !== undefined && payload[key] !== null) {
        stringPayload[key] = String(payload[key]);
      }
    }

    const message = {
      notification: { title, body },
      data: { 
        ...stringPayload, 
        click_action: "FLUTTER_NOTIFICATION_CLICK" 
      },
      tokens: tokens
    };

    try {
      let response;
      if (typeof admin.messaging().sendEachForMulticast === 'function') {
        response = await admin.messaging().sendEachForMulticast(message);
      } else {
        response = await admin.messaging().sendMulticast(message);
      }
      
      // Dọn dẹp token hết hạn
      if (response.failureCount > 0) {
        const invalidTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errorCode = resp.error.code;
            if (errorCode === 'messaging/invalid-registration-token' || 
                errorCode === 'messaging/registration-token-not-registered') {
              invalidTokens.push(tokens[idx]);
            }
          }
        });
        
        if (invalidTokens.length > 0) {
          await this.removeInvalidTokens(userId, invalidTokens);
        }
      }

      return { 
        success: true, 
        message: 'Push notification sent',
        successCount: response.successCount,
        failureCount: response.failureCount
      };
    } catch (error) {
      console.error('Error sending push notification:', error);
      throw error;
    }
  }
}

module.exports = new FCMService();
