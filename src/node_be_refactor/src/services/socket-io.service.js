/**
 * Socket.IO Real-time Notification Service
 * Xử lý kết nối WebSocket, xác thực người dùng, và phát sóng thông báo real-time
 */

const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const Notification = require('../models/notification.model');

class SocketIOService {
  constructor() {
    this.io = null;
    this.userSockets = {}; // Map từ userId -> array of socket IDs
  }

  /**
   * Khởi tạo Socket.IO và cấu hình events
   * @param {Server} httpServer - Express server instance
   */
  initialize(httpServer) {
    this.io = new Server(httpServer, {
      allowEIO3: true, // Cho phép Engine.IO v3 (Socket.IO client v2) kết nối
      cors: {
        origin: '*',
        methods: ['GET', 'POST']
      }
    });

    // Middleware xác thực JWT token
    this.io.use((socket, next) => {
      try {
        const token = (socket.handshake.auth && socket.handshake.auth.token) || 
                      (socket.handshake.query && socket.handshake.query.token);
        
        if (!token) {
          return next(new Error('Authentication error: Missing token'));
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secret_key');
        socket.userId = decoded.id;
        socket.userEmail = decoded.email;
        socket.userRole = decoded.role;
        
        next();
      } catch (error) {
        console.error('Socket authentication error:', error.message);
        next(new Error('Authentication error: Invalid token'));
      }
    });

    // Xử lý kết nối
    this.io.on('connection', (socket) => {
      console.log(`[Socket] User ${socket.userId} connected: ${socket.id}`);

      // Người dùng tham gia vào phòng riêng của mình
      const userRoom = `user_${socket.userId}`;
      socket.join(userRoom);

      // Nếu là STAFF hoặc ADMIN, tham gia phòng chung
      if (socket.userRole === 'STAFF') {
        socket.join('room_staff');
      }
      if (socket.userRole === 'ADMIN' || socket.userRole === 'SUPER_ADMIN') {
        socket.join('room_admin');
      }

      // Lưu mapping userId -> socketId
      if (!this.userSockets[socket.userId]) {
        this.userSockets[socket.userId] = [];
      }
      this.userSockets[socket.userId].push(socket.id);

      // Xử lý ngắt kết nối
      socket.on('disconnect', () => {
        console.log(`[Socket] User ${socket.userId} disconnected: ${socket.id}`);
        
        // Gỡ bỏ socket khỏi mapping
        if (this.userSockets[socket.userId]) {
          this.userSockets[socket.userId] = this.userSockets[socket.userId].filter(
            id => id !== socket.id
          );
          if (this.userSockets[socket.userId].length === 0) {
            delete this.userSockets[socket.userId];
          }
        }
      });

      // Event: Join matching room
      socket.on('join_matching_room', ({ matchingSessionId }) => {
        socket.join(`room_matching_${matchingSessionId}`);
        console.log(`[Socket] User ${socket.userId} joined matching room: room_matching_${matchingSessionId}`);
      });

      // Event: Join custom room (e.g. personal notification room)
      socket.on('join', (roomName) => {
        socket.join(roomName);
        console.log(`[Socket] User ${socket.userId} joined room via 'join' event: ${roomName}`);
      });

      // Event: Leave matching room
      socket.on('leave_matching_room', ({ matchingSessionId }) => {
        socket.leave(`room_matching_${matchingSessionId}`);
        console.log(`[Socket] User ${socket.userId} left matching room: room_matching_${matchingSessionId}`);
      });

      // Event: Kiểm tra kết nối
      socket.on('ping', () => {
        socket.emit('pong');
      });
    });

    console.log('[Socket.IO] Initialized successfully');
    return this.io;
  }

  /**
   * Phát sóng sự kiện cập nhật trạng thái phòng ghép trận cho tất cả người trong phòng đó
   * @param {string} matchingSessionId - ID của phòng ghép trận
   * @param {object} updateData - Dữ liệu phòng ghép trận cập nhật
   */
  notifyMatchingUpdate(matchingSessionId, updateData) {
    if (!this.io) {
      console.warn('[Socket] IO not initialized');
      return false;
    }

    this.io.to(`room_matching_${matchingSessionId}`).emit('matching_session_updated', {
      matchingSessionId,
      data: updateData,
      timestamp: new Date().toISOString()
    });

    console.log(`[Socket] Matching update sent to room_matching_${matchingSessionId}`);
    return true;
  }

  /**
   * Gửi thông báo tới một người dùng cụ thể (Real-time)
   * @param {string} userId - ID người dùng nhận thông báo
   * @param {object} notification - Dữ liệu thông báo
   */
  notifyUser(userId, notification) {
    if (!this.io) {
      console.warn('[Socket] IO not initialized');
      return false;
    }

    const userRoom = `user_${userId}`;
    this.io.to(userRoom).emit('notification_received', {
      event: 'new_notification',
      data: notification,
      timestamp: new Date().toISOString()
    });
    this.io.to(userRoom).emit('new_notification', notification);

    console.log(`[Socket] Notification sent to user ${userId}`);
    return true;
  }

  /**
   * Gửi thông báo tới tất cả STAFF
   * @param {object} notification - Dữ liệu thông báo
   */
  notifyStaff(notification) {
    if (!this.io) {
      console.warn('[Socket] IO not initialized');
      return false;
    }

    this.io.to('room_staff').emit('notification_received', {
      event: 'new_notification',
      data: notification,
      timestamp: new Date().toISOString()
    });
    this.io.to('room_staff').emit('new_notification', notification);

    console.log('[Socket] Notification sent to all staff');
    return true;
  }

  /**
   * Gửi thông báo tới tất cả ADMIN
   * @param {object} notification - Dữ liệu thông báo
   */
  notifyAdmin(notification) {
    if (!this.io) {
      console.warn('[Socket] IO not initialized');
      return false;
    }

    this.io.to('room_admin').emit('notification_received', {
      event: 'new_notification',
      data: notification,
      timestamp: new Date().toISOString()
    });
    this.io.to('room_admin').emit('new_notification', notification);

    console.log('[Socket] Notification sent to all admin');
    return true;
  }

  /**
   * Phát sóng thông báo cho nhiều người dùng
   * @param {array} userIds - Mảng ID người dùng
   * @param {object} notification - Dữ liệu thông báo
   */
  broadcastToUsers(userIds, notification) {
    if (!this.io || !Array.isArray(userIds)) {
      return false;
    }

    userIds.forEach(userId => {
      this.notifyUser(userId, notification);
    });

    console.log(`[Socket] Notification broadcast to ${userIds.length} users`);
    return true;
  }

  /**
   * Lấy tổng số người dùng online
   */
  getOnlineUserCount() {
    return Object.keys(this.userSockets).length;
  }

  /**
   * Kiểm tra xem người dùng có online hay không
   */
  isUserOnline(userId) {
    return this.userSockets[userId] && this.userSockets[userId].length > 0;
  }
}

module.exports = new SocketIOService();
