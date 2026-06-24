const express = require('express');
const cors = require('cors');
const http = require('http');
require('dotenv').config();
const connectDB = require('./config/mongo');
const routes = require('./routes/index');
const path = require('path');
const socketIOService = require('./services/socket-io.service');
const cronStatus = require('./utils/cron-status');

const app = express();
const httpServer = http.createServer(app);
const port = process.env.PORT || 3000;
const host = process.env.HOST || '0.0.0.0';
const dns = require('node:dns');

dns.setDefaultResultOrder('ipv4first');
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api/v1', routes);
app.use('/uploads', express.static(path.join(__dirname, '../public/uploads')));

// Health check endpoint — dùng cho Render/UptimeRobot/cron-job.org ping giữ service không bị sleep
app.get('/health', (req, res) => {
    const timestamp = new Date().toISOString();
    console.log('[HEALTH] Ping received at', timestamp);

    res.status(200).json({
        status: 'ok',
        message: 'Server is running',
        service: 'sport-energy-backend',
        uptime: process.uptime(),
        timestamp
    });
});

app.get('/health/cron', (req, res) => {
    res.status(200).json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        cron: cronStatus.getStatus()
    });
});

// Khởi tạo Socket.IO
socketIOService.initialize(httpServer);

// Lưu socket service vào app để các modules khác có thể sử dụng
app.socketIO = socketIOService.io;

app.use((req, res, next) => {
    res.status(404).json({
        success: false,
        message: 'API endpoint not found',
        code: 'NOT_FOUND'
    });
});

app.use((error, req, res, next) => {
    console.error(error.stack);
    res.status(500).json({
        success: false,
        message: 'Internal Server Error',
        code: 'SERVER_ERROR'
    });
});

connectDB().then(() => {
    httpServer.listen(port, host, () => {
    console.log(`Server is running at http://${host}:${port}`);
    console.log(`Android emulator API URL: http://10.0.2.2:${port}/api/v1`);
    console.log(`WebSocket (Socket.IO) is ready for real-time notifications`);

    // Khởi chạy Cron Job ghép trận tự động
    require('./utils/cron-matchmaker');
    // Khởi chạy Cron Job sinh lịch cố định (Giờ chết) tự động
    require('./utils/cron-fixed-scheduler');
    require('./utils/cron-auto-cancel-bookings');
    require('./utils/cron-auto-complete-bookings');
    });
}).catch((error) => {
    console.error('Failed to start server:', error);
    process.exit(1);
});
