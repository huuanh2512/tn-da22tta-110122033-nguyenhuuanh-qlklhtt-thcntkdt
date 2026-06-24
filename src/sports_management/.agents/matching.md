# 🏟️ HỆ THỐNG GHÉP TRẬN THỂ THAO (MATCHMAKING SYSTEM SPECIFICATION)
## Dành cho Nền tảng Đặt sân & Kết nối Người chơi (Mobile App & Backend Core)

Tài liệu này đặc tả chi tiết kiến trúc, Database Schema, REST API, luồng Socket.IO và logic xử lý backend để xây dựng tính năng **Ghép trận (Matchmaking)** cho Khách hàng (`CUSTOMER`). 

Hệ thống được thiết kế đồng bộ với hệ thống hiện tại của backend (Sử dụng Node.js, Express, Mongoose, Socket.IO, và Firebase Cloud Messaging).

---

## 1. 📐 Kiến trúc & Giải pháp Ghép trận

Để giải quyết nhu cầu tìm người chơi cùng, hệ thống hỗ trợ 2 cơ chế ghép trận chính:

### 1️⃣ Ghép trận theo Phòng (Hosted Matches)
* **Khái niệm:** Một người chơi (Host) đã đặt sân thành công (hoặc dự định đặt) tạo một phòng ghép trận. Họ mô tả thông tin trận đấu (thời gian, địa điểm, chi phí) và số lượng thành viên còn thiếu. Các người chơi khác duyệt danh sách phòng và xin gia nhập.
* **Quy trình:**
  ```mermaid
  sequenceDiagram
      participant Host as Khách hàng A (Host)
      participant Server as Backend Server
      participant Guest as Khách hàng B (Guest)
      
      Host->>Server: POST /api/v1/matching (Tạo phòng ghép, số người cần Y)
      Server-->>Host: Trả về chi tiết phòng (Trạng thái OPEN)
      Note over Guest: Duyệt danh sách phòng theo Sân, Môn, Số chỗ trống...
      Guest->>Server: POST /api/v1/matching/:id/join (Xin tham gia)
      
      alt auto_approve = true
          Server->>Server: Duyệt tự động & thêm Guest vào members
          Server->>Host: Socket/FCM: "Khách hàng B đã tham gia trận đấu"
          Server->>Guest: Trả về trạng thái APPROVED
      else auto_approve = false
          Server->>Host: Socket/FCM: "Khách hàng B muốn tham gia trận đấu của bạn"
          Host->>Server: PUT /api/v1/matching/:id/members/:guestId (Duyệt)
          Server-->>Host: Cập nhật thành viên thành APPROVED
          Server->>Guest: Socket/FCM: "Yêu cầu tham gia trận đấu đã được duyệt"
      end
      
      Note over Server: Khi số APPROVED members đạt đủ Y
      Server->>Server: Cập nhật trạng thái Matching -> FULL
      Server->>Host: Socket/FCM: "Trận đấu của bạn đã đủ người!"
      Server->>Guest: Socket/FCM: "Trận đấu bạn tham gia đã gom đủ người!"
  ```

### 2️⃣ Hàng chờ Ghép trận Tự động (Auto-Matchmaking Queue)
* **Khái niệm:** Người chơi đơn lẻ hoặc nhóm nhỏ không muốn tìm phòng thủ công. Họ đăng ký vào hàng chờ (`MatchQueue`) với các tiêu chí: Môn thể thao, Cụm sân (Facility), Khung giờ rảnh, và số người của họ. 
* **Thuật toán ghép tự động (Cron-Job / Worker):** Định kỳ (ví dụ: mỗi 1 phút), hệ thống chạy tác vụ nền tìm kiếm các yêu cầu trong hàng chờ có cùng Môn thể thao, cùng Cơ sở sân, cùng ngày chơi, và có khoảng thời gian rảnh trùng nhau ít nhất 60 phút. Khi tổng số người (`group_size`) của nhóm trùng nhau đạt đúng/đủ điều kiện, hệ thống tự động tạo một `MatchingSession` cho họ và gửi thông báo.

---

## 2. 🗄️ Database Schemas (MongoDB / Mongoose)

Hệ thống cần 2 Schema mới lưu trong thư mục `src/models/`:
1. `matching.model.js`: Quản lý các phòng ghép trận đang hoạt động.
2. `match-queue.model.js`: Quản lý hàng chờ cho tính năng ghép tự động.

### 📁 Thêm mới: [matching.model.js](file:///d:/Source/node_be_refactor/src/models/matching.model.js)
```javascript
const mongoose = require('mongoose');

const matchingMemberSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  status: {
    type: String,
    enum: ['PENDING', 'APPROVED', 'REJECTED'],
    default: 'PENDING'
  },
  joined_at: {
    type: Date,
    default: Date.now
  }
}, { _id: false });

const matchingSessionSchema = new mongoose.Schema({
  host_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  sport_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Sport',
    required: true,
    index: true
  },
  facility_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Facility',
    required: true,
    index: true
  },
  court_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Court',
    default: null
  },
  booking_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking',
    default: null
  },
  booking_date: {
    type: String, // Định dạng "YYYY-MM-DD"
    required: true,
    index: true
  },
  start_minutes: {
    type: Number, // Số phút tính từ 00:00 (Ví dụ: 540 = 9:00 AM)
    required: true
  },
  end_minutes: {
    type: Number, // Ví dụ: 600 = 10:00 AM
    required: true
  },
  total_players_needed: {
    type: Number, // Số lượng chân cần tuyển thêm
    required: true,
    min: 1
  },
  description: {
    type: String,
    default: '',
    trim: true
  },
  auto_approve: {
    type: Boolean,
    default: true // Nếu true, người chơi tham gia sẽ tự động APPROVED
  },
  members: {
    type: [matchingMemberSchema],
    default: []
  },
  status: {
    type: String,
    enum: ['OPEN', 'FULL', 'CANCELLED', 'COMPLETED'],
    default: 'OPEN',
    index: true
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

// Chỉ cho phép Host có 1 trận đấu hoạt động tại cùng một khung giờ
matchingSessionSchema.index({ host_id: 1, booking_date: 1, start_minutes: 1 }, { unique: true });

const MatchingSession = mongoose.model('MatchingSession', matchingSessionSchema);

module.exports = MatchingSession;
```

### 📁 Thêm mới: [match-queue.model.js](file:///d:/Source/node_be_refactor/src/models/match-queue.model.js)
```javascript
const mongoose = require('mongoose');

const matchQueueSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  sport_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Sport',
    required: true,
    index: true
  },
  facility_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Facility',
    required: true,
    index: true
  },
  booking_date: {
    type: String, // "YYYY-MM-DD"
    required: true,
    index: true
  },
  start_minutes: {
    type: Number, // Giới hạn khung giờ sớm nhất có thể đá
    required: true
  },
  end_minutes: {
    type: Number, // Giới hạn khung giờ trễ nhất có thể đá
    required: true
  },
  group_size: {
    type: Number, // Số người đăng ký đi cùng nhóm này (ví dụ: đi 1 mình = 1, đi 2 mình = 2)
    default: 1,
    min: 1
  },
  status: {
    type: String,
    enum: ['SEARCHING', 'MATCHED', 'CANCELLED', 'EXPIRED'],
    default: 'SEARCHING',
    index: true
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

const MatchQueue = mongoose.model('MatchQueue', matchQueueSchema);

module.exports = MatchQueue;
```

---

## 3. 🌐 Danh sách REST API Endpoints

Các API ghép trận yêu cầu header `Authorization: Bearer <token>` và dành cho phân quyền `CUSTOMER`.

| Method | Endpoint | Mô tả | Vai trò |
|---|---|---|---|
| **POST** | `/api/v1/matching` | Tạo phòng ghép trận (Hosted Match) | Host |
| **GET** | `/api/v1/matching` | Truy vấn danh sách phòng ghép (Lọc theo Môn, Sân, Slot, Số người thiếu) | Guest |
| **GET** | `/api/v1/matching/:id` | Xem chi tiết phòng ghép trận và danh sách thành viên | Host / Guest |
| **POST** | `/api/v1/matching/:id/join` | Xin tham gia phòng ghép trận | Guest |
| **POST** | `/api/v1/matching/:id/leave` | Rời khỏi phòng ghép trận | Guest |
| **PUT** | `/api/v1/matching/:id/members/:userId` | Duyệt/Từ chối thành viên xin vào | Host |
| **PUT** | `/api/v1/matching/:id/status` | Hủy phòng hoặc chuyển trạng thái | Host |
| **POST** | `/api/v1/matching/queue/join` | Đăng ký vào hàng chờ ghép tự động | Solo/Group |
| **POST** | `/api/v1/matching/queue/leave` | Thoát khỏi hàng chờ ghép tự động | Solo/Group |
| **GET** | `/api/v1/matching/queue/status` | Kiểm tra trạng thái hiện tại trong hàng chờ | Solo/Group |

---

### Chi tiết các API chính

#### 1. Tạo phòng ghép trận (`POST /api/v1/matching`)
* **Request Body:**
  ```json
  {
    "sportId": "6a0f022b22c105b435bb0e11",
    "facilityId": "6a0f022b22c105b435bb0e22",
    "courtId": "6a0f022b22c105b435bb0e33", // Optional
    "bookingId": "6a0f022b22c105b435bb0e44", // Optional
    "bookingDate": "2026-06-05",
    "startMinutes": 1020, // 17:00 PM
    "endMinutes": 1140,   // 19:00 PM
    "totalPlayersNeeded": 3, // Cần tuyển thêm 3 người
    "description": "Tìm kèo giao lưu vui vẻ, chia tiền sân nhẹ nhàng.",
    "autoApprove": false // Cần host duyệt yêu cầu
  }
  ```
* **Response Success `200`:**
  ```json
  {
    "success": true,
    "message": "Matching session created successfully",
    "data": {
      "id": "6a0f022b22c105b435bb0eee",
      "hostId": "6a0f022b22c105b435bb0e00",
      "sportId": "6a0f022b22c105b435bb0e11",
      "facilityId": "6a0f022b22c105b435bb0e22",
      "courtId": "6a0f022b22c105b435bb0e33",
      "bookingId": "6a0f022b22c105b435bb0e44",
      "bookingDate": "2026-06-05",
      "startMinutes": 1020,
      "endMinutes": 1140,
      "totalPlayersNeeded": 3,
      "description": "Tìm kèo giao lưu vui vẻ, chia tiền sân nhẹ nhàng.",
      "autoApprove": false,
      "members": [],
      "status": "OPEN"
    }
  }
  ```

#### 2. Tìm kiếm phòng ghép trận (`GET /api/v1/matching`)
* **Query Parameters:**
  * `sportId`: Môn thể thao cần tìm.
  * `facilityId`: Địa điểm chơi mong muốn.
  * `bookingDate`: Ngày chơi ("YYYY-MM-DD").
  * `neededSpots`: Số chỗ trống tối thiểu (ví dụ: cần rủ thêm 2 đứa bạn đi cùng -> `neededSpots=2`).
  * `skip` / `limit`: Phân trang.
* **Response Success `200`:**
  ```json
  {
    "success": true,
    "message": "Matching sessions retrieved successfully",
    "items": [
      {
        "id": "6a0f022b22c105b435bb0eee",
        "host": {
          "id": "6a0f022b22c105b435bb0e00",
          "name": "Nguyễn Văn A",
          "avatarUrl": "http://..."
        },
        "sport": {
          "id": "6a0f022b22c105b435bb0e11",
          "name": "Badminton"
        },
        "facility": {
          "id": "6a0f022b22c105b435bb0e22",
          "name": "Sân Cầu Lông Kỳ Hòa"
        },
        "bookingDate": "2026-06-05",
        "startMinutes": 1020,
        "endMinutes": 1140,
        "totalPlayersNeeded": 3,
        "approvedCount": 1,
        "availableSpots": 2, // Tính toán động: totalPlayersNeeded - APPROVED members
        "status": "OPEN",
        "description": "..."
      }
    ],
    "total": 1
  }
  ```

#### 3. Duyệt/Từ chối thành viên tham gia (`PUT /api/v1/matching/:id/members/:userId`)
* **Request Body:**
  ```json
  {
    "status": "APPROVED" // Hoặc "REJECTED"
  }
  ```
* **Response Success `200`:**
  ```json
  {
    "success": true,
    "message": "Member status updated successfully",
    "data": {
      "id": "6a0f022b22c105b435bb0eee",
      "members": [
        {
          "userId": "6a0f022b22c105b435bb0ebb",
          "status": "APPROVED",
          "joinedAt": "2026-05-29T14:00:00Z"
        }
      ],
      "status": "OPEN" // Sẽ tự động chuyển thành "FULL" nếu số APPROVED đạt đủ totalPlayersNeeded
    }
  }
  ```

---

## 4. 💻 Cấu trúc Mã nguồn Triển khai

Dưới đây là mã nguồn đầy đủ, sẵn sàng tích hợp, tuân thủ đúng kiến trúc Repository - Service - Controller - Router của dự án.

### 📁 Thêm mới: [matching.repository.js](file:///d:/Source/node_be_refactor/src/repositories/matching.repository.js)
```javascript
const MatchingSession = require('../models/matching.model');

class MatchingRepository {
  async create(data) {
    const session = new MatchingSession(data);
    return await session.save();
  }

  async findById(id) {
    return await MatchingSession.findById(id)
      .populate('host_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate('court_id')
      .populate('members.user_id');
  }

  async findOne(query) {
    return await MatchingSession.findOne(query);
  }

  async findMany(query, skip, limit) {
    return await MatchingSession.find(query)
      .skip(skip)
      .limit(limit)
      .populate('host_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate('court_id')
      .sort({ created_at: -1 });
  }

  async count(query) {
    return await MatchingSession.countDocuments(query);
  }

  async updateById(id, updateData) {
    return await MatchingSession.findByIdAndUpdate(id, updateData, { new: true })
      .populate('host_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate('members.user_id');
  }
}

module.exports = new MatchingRepository();
```

### 📁 Thêm mới: [match-queue.repository.js](file:///d:/Source/node_be_refactor/src/repositories/match-queue.repository.js)
```javascript
const MatchQueue = require('../models/match-queue.model');

class MatchQueueRepository {
  async create(data) {
    const queue = new MatchQueue(data);
    return await queue.save();
  }

  async findActiveByUserId(userId) {
    return await MatchQueue.findOne({ user_id: userId, status: 'SEARCHING' })
      .populate('sport_id')
      .populate('facility_id');
  }

  async findActiveQueues(query = {}) {
    return await MatchQueue.find({ status: 'SEARCHING', ...query })
      .populate('user_id')
      .populate('sport_id')
      .populate('facility_id');
  }

  async updateStatus(id, status) {
    return await MatchQueue.findByIdAndUpdate(id, { status }, { new: true });
  }

  async updateMany(query, updateData) {
    return await MatchQueue.updateMany(query, updateData);
  }
}

module.exports = new MatchQueueRepository();
```

### 📁 Thêm mới: [matching.service.js](file:///d:/Source/node_be_refactor/src/services/matching.service.js)
```javascript
const matchingRepository = require('../repositories/matching.repository');
const matchQueueRepository = require('../repositories/match-queue.repository');
const notificationHelper = require('./notification.helper');
const socketIOService = require('./socket-io.service');

class MatchingService {
  _formatSessionResponse(session) {
    const approvedCount = session.members.filter(m => m.status === 'APPROVED').length;
    return {
      id: session._id.toString(),
      host: session.host_id ? {
        id: session.host_id._id?.toString() || session.host_id.toString(),
        name: session.host_id.profile?.name || '',
        avatarUrl: session.host_id.profile?.avatar_url || '',
        email: session.host_id.email || ''
      } : null,
      sport: session.sport_id ? {
        id: session.sport_id._id?.toString() || session.sport_id.toString(),
        name: session.sport_id.name || ''
      } : null,
      facility: session.facility_id ? {
        id: session.facility_id._id?.toString() || session.facility_id.toString(),
        name: session.facility_id.name || '',
        city: session.facility_id.city || ''
      } : null,
      courtId: session.court_id?._id?.toString() || session.court_id?.toString() || null,
      bookingId: session.booking_id?._id?.toString() || session.booking_id?.toString() || null,
      bookingDate: session.booking_date,
      startMinutes: session.start_minutes,
      endMinutes: session.end_minutes,
      totalPlayersNeeded: session.total_players_needed,
      approvedCount: approvedCount,
      availableSpots: Math.max(0, session.total_players_needed - approvedCount),
      description: session.description || '',
      autoApprove: session.auto_approve,
      status: session.status,
      members: session.members.map(m => ({
        user: {
          id: m.user_id?._id?.toString() || m.user_id.toString(),
          name: m.user_id?.profile?.name || '',
          avatarUrl: m.user_id?.profile?.avatar_url || ''
        },
        status: m.status,
        joinedAt: m.joined_at
      })),
      createdAt: session.created_at ? new Date(session.created_at).toISOString() : null
    };
  }

  async createSession(data, hostId) {
    // Kiểm tra trùng lịch ghép của host
    const duplicate = await matchingRepository.findOne({
      host_id: hostId,
      booking_date: data.bookingDate,
      start_minutes: data.startMinutes,
      status: 'OPEN'
    });

    if (duplicate) {
      throw new Error('Bạn đã có một phòng ghép khác hoạt động tại thời gian này');
    }

    const sessionData = {
      host_id: hostId,
      sport_id: data.sportId,
      facility_id: data.facilityId,
      court_id: data.courtId || null,
      booking_id: data.bookingId || null,
      booking_date: data.bookingDate,
      start_minutes: data.startMinutes,
      end_minutes: data.endMinutes,
      total_players_needed: data.totalPlayersNeeded,
      description: data.description || '',
      auto_approve: data.autoApprove !== undefined ? data.autoApprove : true,
      members: [],
      status: 'OPEN'
    };

    let session = await matchingRepository.create(sessionData);
    session = await matchingRepository.findById(session._id);

    return { session: this._formatSessionResponse(session) };
  }

  async querySessions(filters, skip = 0, limit = 20) {
    const query = { status: 'OPEN' };

    if (filters.sportId) query.sport_id = filters.sportId;
    if (filters.facilityId) query.facility_id = filters.facilityId;
    if (filters.bookingDate) query.booking_date = filters.bookingDate;

    // Lấy dữ liệu thô
    const [rawSessions, total] = await Promise.all([
      matchingRepository.findMany(query, parseInt(skip), parseInt(limit)),
      matchingRepository.count(query)
    ]);

    // Format và bổ sung dữ liệu động
    let sessions = rawSessions.map(s => this._formatSessionResponse(s));

    // Bộ lọc lọc số lượng chỗ trống còn lại trên RAM nếu cần
    if (filters.neededSpots) {
      const minSpots = parseInt(filters.neededSpots);
      sessions = sessions.filter(s => s.availableSpots >= minSpots);
    }

    return {
      items: sessions,
      total: sessions.length
    };
  }

  async getSessionDetail(id) {
    const session = await matchingRepository.findById(id);
    if (!session) throw new Error('Không tìm thấy phòng ghép trận');
    return { session: this._formatSessionResponse(session) };
  }

  async joinSession(id, userId) {
    const session = await matchingRepository.findById(id);
    if (!session) throw new Error('Không tìm thấy phòng ghép trận');
    if (session.status !== 'OPEN') throw new Error('Phòng ghép trận này đã đóng hoặc đã đầy');
    if (session.host_id._id.toString() === userId) throw new Error('Bạn là chủ phòng, không thể join');

    // Kiểm tra xem đã join chưa
    const isMemberExist = session.members.find(m => m.user_id._id.toString() === userId);
    if (isMemberExist) {
      throw new Error('Bạn đã đăng ký tham gia phòng này rồi');
    }

    const memberStatus = session.auto_approve ? 'APPROVED' : 'PENDING';
    
    session.members.push({
      user_id: userId,
      status: memberStatus,
      joined_at: new Date()
    });

    // Tự động kiểm tra nếu APPROVED đạt đủ số người cần tuyển -> chuyển FULL
    const approvedCount = session.members.filter(m => m.status === 'APPROVED').length;
    if (approvedCount >= session.total_players_needed) {
      session.status = 'FULL';
    }

    const updatedSession = await session.save();
    const formatted = this._formatSessionResponse(await matchingRepository.findById(updatedSession._id));

    // --- Xử lý Thông báo ---
    const hostName = session.host_id.profile?.name || 'Chủ phòng';
    
    if (memberStatus === 'APPROVED') {
      // 1. Gửi thông báo real-time socket & FCM cho Host biết có người vào phòng
      await notificationHelper.notifyUser({
        userId: session.host_id._id,
        title: 'Thành viên mới tham gia trận đấu',
        content: `Người chơi vừa tham gia trận đấu của bạn tại ${session.facility_id.name}`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: id }
      });

      // 2. Nếu phòng chuyển sang FULL, thông báo cho toàn bộ member
      if (formatted.status === 'FULL') {
        const approvedMemberIds = session.members
          .filter(m => m.status === 'APPROVED')
          .map(m => m.user_id._id.toString());
          
        // Thông báo Host
        await notificationHelper.notifyUser({
          userId: session.host_id._id,
          title: 'Trận đấu đã gom đủ người!',
          content: `Trận đấu ngày ${session.booking_date} tại ${session.facility_id.name} đã đủ số lượng người đăng ký.`,
          type: 'SYSTEM',
          metadata: { matchingSessionId: id }
        });

        // Thông báo cho các Guest
        for (const guestId of approvedMemberIds) {
          await notificationHelper.notifyUser({
            userId: guestId,
            title: 'Kèo đấu đã sẵn sàng!',
            content: `Trận đấu của bạn tại ${session.facility_id.name} vào ngày ${session.booking_date} đã đủ người. Chuẩn bị ra sân thôi!`,
            type: 'SYSTEM',
            metadata: { matchingSessionId: id }
          });
        }
      }
    } else {
      // Khi auto_approve = false, yêu cầu duyệt PENDING
      await notificationHelper.notifyUser({
        userId: session.host_id._id,
        title: 'Yêu cầu xin ghép trận mới',
        content: `Có người chơi đang chờ bạn duyệt để tham gia trận đấu ngày ${session.booking_date}`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: id }
      });
    }

    return { session: formatted };
  }

  async updateMemberStatus(id, targetUserId, status, hostId) {
    const session = await matchingRepository.findById(id);
    if (!session) throw new Error('Không tìm thấy phòng ghép trận');
    if (session.host_id._id.toString() !== hostId) throw new Error('Bạn không có quyền quản lý phòng này');

    const member = session.members.find(m => m.user_id._id.toString() === targetUserId);
    if (!member) throw new Error('Không tìm thấy người chơi này trong danh sách xin ghép');

    member.status = status;

    // Cập nhật trạng thái trận đấu
    const approvedCount = session.members.filter(m => m.status === 'APPROVED').length;
    if (approvedCount >= session.total_players_needed) {
      session.status = 'FULL';
    } else {
      session.status = 'OPEN';
    }

    const updatedSession = await session.save();
    const formatted = this._formatSessionResponse(await matchingRepository.findById(updatedSession._id));

    // Gửi thông báo cho thành viên được duyệt/từ chối
    if (status === 'APPROVED') {
      await notificationHelper.notifyUser({
        userId: targetUserId,
        title: 'Yêu cầu ghép trận được phê duyệt',
        content: `Yêu cầu gia nhập trận đấu của bạn tại ${session.facility_id.name} đã được Host chấp nhận!`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: id }
      });
    } else if (status === 'REJECTED') {
      await notificationHelper.notifyUser({
        userId: targetUserId,
        title: 'Yêu cầu ghép trận bị từ chối',
        content: `Rất tiếc, yêu cầu tham gia trận đấu tại ${session.facility_id.name} của bạn không được phê duyệt.`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: id }
      });
    }

    return { session: formatted };
  }

  async leaveSession(id, userId) {
    const session = await matchingRepository.findById(id);
    if (!session) throw new Error('Không tìm thấy phòng ghép trận');

    const initialLen = session.members.length;
    session.members = session.members.filter(m => m.user_id._id.toString() !== userId);
    
    if (session.members.length === initialLen) {
      throw new Error('Bạn chưa tham gia phòng này');
    }

    // Nếu đang FULL mà có người out -> quay về OPEN
    if (session.status === 'FULL') {
      session.status = 'OPEN';
    }

    const updatedSession = await session.save();
    
    // Thông báo cho Host biết có người rời phòng
    await notificationHelper.notifyUser({
      userId: session.host_id._id,
      title: 'Thành viên đã rời trận',
      content: `Một thành viên vừa rời phòng ghép của bạn. Trận đấu hiện mở lại tuyển thêm thành viên.`,
      type: 'SYSTEM',
      metadata: { matchingSessionId: id }
    });

    return { session: this._formatSessionResponse(await matchingRepository.findById(updatedSession._id)) };
  }

  async updateSessionStatus(id, status, hostId) {
    const session = await matchingRepository.findById(id);
    if (!session) throw new Error('Không tìm thấy phòng ghép trận');
    if (session.host_id._id.toString() !== hostId) throw new Error('Bạn không có quyền thao tác');

    session.status = status;
    const updatedSession = await session.save();

    // Nếu hủy phòng, thông báo cho toàn bộ các thành viên đã được duyệt
    if (status === 'CANCELLED') {
      const memberIds = session.members
        .filter(m => m.status === 'APPROVED')
        .map(m => m.user_id._id.toString());

      for (const memberId of memberIds) {
        await notificationHelper.notifyUser({
          userId: memberId,
          title: 'Kèo đấu đã bị hủy',
          content: `Rất tiếc, Host đã hủy trận đấu ngày ${session.booking_date} tại ${session.facility_id.name}.`,
          type: 'SYSTEM',
          metadata: { matchingSessionId: id }
        });
      }
    }

    return { session: this._formatSessionResponse(await matchingRepository.findById(updatedSession._id)) };
  }

  // --- AUTO-MATCHMAKING LOGIC (Hàng chờ tự động) ---

  async joinQueue(data, userId) {
    const active = await matchQueueRepository.findActiveByUserId(userId);
    if (active) {
      throw new Error('Bạn đang trong một hàng chờ ghép trận khác. Vui lòng thoát trước khi đăng ký mới.');
    }

    const queueData = {
      user_id: userId,
      sport_id: data.sportId,
      facility_id: data.facilityId,
      booking_date: data.bookingDate,
      start_minutes: data.startMinutes,
      end_minutes: data.endMinutes,
      group_size: data.groupSize || 1,
      status: 'SEARCHING'
    };

    const newQueue = await matchQueueRepository.create(queueData);
    
    // Kích hoạt tiến trình Matching chạy ngầm bất đồng bộ
    this.runMatchmakerAlgorithm(data.sportId, data.facilityId, data.bookingDate).catch(err => 
      console.error('[Matchmaker Engine Error]:', err.message)
    );

    return { queue: newQueue };
  }

  async leaveQueue(userId) {
    const active = await matchQueueRepository.findActiveByUserId(userId);
    if (!active) {
      throw new Error('Bạn không ở trong hàng chờ nào');
    }
    
    active.status = 'CANCELLED';
    await active.save();
    return { success: true };
  }

  async getQueueStatus(userId) {
    const active = await matchQueueRepository.findActiveByUserId(userId);
    return { active: active ? {
      id: active._id,
      sport: active.sport_id.name,
      facility: active.facility_id.name,
      bookingDate: active.booking_date,
      time: `${Math.floor(active.start_minutes/60)}h - ${Math.floor(active.end_minutes/60)}h`,
      groupSize: active.group_size,
      status: active.status
    } : null };
  }

  /**
   * Thuật toán Matchmaker tìm gom cụm người chơi trùng lịch
   */
  async runMatchmakerAlgorithm(sportId, facilityId, bookingDate) {
    console.log(`[Matchmaker] Bắt đầu quét hàng chờ: Sport=${sportId}, Facility=${facilityId}, Date=${bookingDate}`);

    // Lấy tất cả người chơi đang chờ ghép cho Môn - Sân - Ngày này
    const queues = await matchQueueRepository.findActiveQueues({
      sport_id: sportId,
      facility_id: facilityId,
      booking_date: bookingDate
    });

    if (queues.length < 2) return; // Cần tối thiểu 2 nhóm/người đăng ký

    // Lấy size trận đấu tiêu chuẩn từ cấu hình Sport
    const sport = queues[0].sport_id;
    const teamSize = sport.team_size || 4; // Ví dụ Cầu lông đôi = 4, Bóng đá 5 = 10 người sân

    // Duyệt qua và gom cụm các yêu cầu trùng khoảng thời gian (overlap >= 60 phút)
    // Thuật toán Greedy gom nhóm:
    let matchedGroup = [];
    let currentPlayersCount = 0;
    
    // Sắp xếp theo thời gian đăng ký sớm nhất để ưu tiên người chờ lâu
    queues.sort((a, b) => a.created_at - b.created_at);

    for (let i = 0; i < queues.length; i++) {
      const q = queues[i];
      
      if (matchedGroup.length === 0) {
        matchedGroup.push(q);
        currentPlayersCount += q.group_size;
      } else {
        // Kiểm tra xem q có overlap thời gian với tất cả các phần tử trong matchedGroup hay không
        const overlap = matchedGroup.every(member => {
          const maxStart = Math.max(member.start_minutes, q.start_minutes);
          const minEnd = Math.min(member.end_minutes, q.end_minutes);
          return (minEnd - maxStart) >= 60; // Trùng tối thiểu 60 phút
        });

        if (overlap) {
          matchedGroup.push(q);
          currentPlayersCount += q.group_size;
        }
      }

      // Đã đủ số lượng người chơi cho 1 trận đấu
      if (currentPlayersCount >= teamSize) {
        // Cắt bớt nếu vượt quá (ví dụ teamSize = 4, đi lẻ gom được 5 -> cắt người thứ 5 ra hàng chờ tiếp)
        let playersToMatch = [];
        let total = 0;
        
        for (const item of matchedGroup) {
          if (total + item.group_size <= teamSize) {
            playersToMatch.push(item);
            total += item.group_size;
          }
          if (total === teamSize) break;
        }

        if (total === teamSize) {
          // THÀNH CÔNG: Ghép trận thành công!
          await this.executeSuccessfulMatch(playersToMatch, sportId, facilityId, bookingDate);
          return; // Dừng quét (hoặc đệ quy chạy tiếp cho các người chơi còn lại)
        }
      }
    }
  }

  async executeSuccessfulMatch(matchedQueues, sportId, facilityId, bookingDate) {
    const hostQueue = matchedQueues[0]; // Chỉ định người đăng ký đầu làm Host tạm thời
    const guestQueues = matchedQueues.slice(1);

    // Tính toán khung giờ chung cho cả nhóm
    let startMins = Math.max(...matchedQueues.map(q => q.start_minutes));
    let endMins = Math.min(...matchedQueues.map(q => q.end_minutes));

    // Tạo MatchingSession phòng đấu ghép thành công
    const sessionData = {
      host_id: hostQueue.user_id._id,
      sport_id: sportId,
      facility_id: facilityId,
      booking_date: bookingDate,
      start_minutes: startMins,
      end_minutes: endMins,
      total_players_needed: matchedQueues.reduce((acc, q) => acc + q.group_size, 0) - hostQueue.group_size,
      description: 'Trận đấu được ghép tự động qua Hệ thống Matching.',
      auto_approve: true,
      status: 'FULL',
      members: guestQueues.map(g => ({
        user_id: g.user_id._id,
        status: 'APPROVED',
        joined_at: new Date()
      }))
    };

    const session = await matchingRepository.create(sessionData);

    // Cập nhật trạng thái của hàng chờ
    const queueIds = matchedQueues.map(q => q._id);
    await matchQueueRepository.updateMany({ _id: { $in: queueIds } }, { status: 'MATCHED' });

    // Gửi thông báo cho Host và tất cả các Guest
    const allUserIds = matchedQueues.map(q => q.user_id._id.toString());
    
    for (const userId of allUserIds) {
      await notificationHelper.notifyUser({
        userId: userId,
        title: '🎉 Ghép trận tự động THÀNH CÔNG!',
        content: `Hệ thống đã tự động tìm thấy kèo đấu trùng khớp cho bạn vào ngày ${bookingDate} lúc ${Math.floor(startMins/60)}:00!`,
        type: 'SYSTEM',
        metadata: { matchingSessionId: session._id.toString() }
      });
    }

    console.log(`[Matchmaker] Ghép thành công Session ID: ${session._id} cho các User: ${allUserIds.join(', ')}`);
  }
}

module.exports = new MatchingService();
```

### 📁 Thêm mới: [matching.controller.js](file:///d:/Source/node_be_refactor/src/controllers/matching.controller.js)
```javascript
const matchingService = require('../services/matching.service');
const { sendSuccess, sendError } = require('../utils/response.util');

const createSession = async (req, res) => {
  try {
    const { sportId, facilityId, bookingDate, startMinutes, endMinutes, totalPlayersNeeded } = req.body;
    
    if (!sportId || !facilityId || !bookingDate || startMinutes === undefined || endMinutes === undefined || !totalPlayersNeeded) {
      return sendError(res, 400, 'Thiếu thông tin bắt buộc để tạo phòng ghép trận', 'MISSING_FIELDS');
    }

    const result = await matchingService.createSession(req.body, req.user.id);
    return sendSuccess(res, result.session, 'Tạo phòng ghép trận thành công', 'CREATE_SUCCESS');
  } catch (error) {
    return sendError(res, 500, error.message, 'CREATE_ERROR');
  }
};

const querySessions = async (req, res) => {
  try {
    const { skip, limit, ...filters } = req.query;
    const result = await matchingService.querySessions(filters, skip, limit);
    return res.status(200).json({
      success: true,
      message: 'Lấy danh sách phòng ghép thành công',
      items: result.items,
      total: result.total
    });
  } catch (error) {
    return sendError(res, 500, error.message, 'QUERY_ERROR');
  }
};

const getSessionDetail = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await matchingService.getSessionDetail(id);
    return sendSuccess(res, result.session, 'Lấy chi tiết phòng ghép thành công');
  } catch (error) {
    return sendError(res, 404, error.message, 'NOT_FOUND');
  }
};

const joinSession = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await matchingService.joinSession(id, req.user.id);
    return sendSuccess(res, result.session, 'Đăng ký tham gia phòng ghép thành công', 'JOIN_SUCCESS');
  } catch (error) {
    return sendError(res, 400, error.message, 'JOIN_ERROR');
  }
};

const leaveSession = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await matchingService.leaveSession(id, req.user.id);
    return sendSuccess(res, result.session, 'Rời phòng ghép thành công', 'LEAVE_SUCCESS');
  } catch (error) {
    return sendError(res, 400, error.message, 'LEAVE_ERROR');
  }
};

const updateMemberStatus = async (req, res) => {
  try {
    const { id, userId } = req.params;
    const { status } = req.body;

    if (!status || !['APPROVED', 'REJECTED'].includes(status)) {
      return sendError(res, 400, 'Trạng thái duyệt không hợp lệ', 'INVALID_STATUS');
    }

    const result = await matchingService.updateMemberStatus(id, userId, status, req.user.id);
    return sendSuccess(res, result.session, 'Cập nhật trạng thái thành viên thành công');
  } catch (error) {
    return sendError(res, 400, error.message, 'UPDATE_ERROR');
  }
};

const updateSessionStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!status || !['OPEN', 'CANCELLED', 'COMPLETED'].includes(status)) {
      return sendError(res, 400, 'Trạng thái phòng không hợp lệ', 'INVALID_STATUS');
    }

    const result = await matchingService.updateSessionStatus(id, status, req.user.id);
    return sendSuccess(res, result.session, 'Cập nhật trạng thái phòng thành công');
  } catch (error) {
    return sendError(res, 400, error.message, 'UPDATE_ERROR');
  }
};

// --- CONTROLLERS FOR AUTO-MATCHMAKING QUEUE ---

const joinQueue = async (req, res) => {
  try {
    const { sportId, facilityId, bookingDate, startMinutes, endMinutes, groupSize } = req.body;

    if (!sportId || !facilityId || !bookingDate || startMinutes === undefined || endMinutes === undefined) {
      return sendError(res, 400, 'Thiếu thông tin đăng ký hàng chờ', 'MISSING_FIELDS');
    }

    const result = await matchingService.joinQueue(req.body, req.user.id);
    return sendSuccess(res, result.queue, 'Đăng ký vào hàng chờ ghép tự động thành công', 'QUEUE_JOIN_SUCCESS');
  } catch (error) {
    return sendError(res, 400, error.message, 'QUEUE_ERROR');
  }
};

const leaveQueue = async (req, res) => {
  try {
    await matchingService.leaveQueue(req.user.id);
    return sendSuccess(res, null, 'Hủy hàng chờ ghép tự động thành công', 'QUEUE_LEAVE_SUCCESS');
  } catch (error) {
    return sendError(res, 400, error.message, 'QUEUE_ERROR');
  }
};

const getQueueStatus = async (req, res) => {
  try {
    const result = await matchingService.getQueueStatus(req.user.id);
    return sendSuccess(res, result.active, 'Lấy trạng thái hàng chờ thành công');
  } catch (error) {
    return sendError(res, 500, error.message, 'QUEUE_ERROR');
  }
};

module.exports = {
  createSession,
  querySessions,
  getSessionDetail,
  joinSession,
  leaveSession,
  updateMemberStatus,
  updateSessionStatus,
  joinQueue,
  leaveQueue,
  getQueueStatus
};
```

### 📁 Thêm mới: [matching.routes.js](file:///d:/Source/node_be_refactor/src/routes/matching.routes.js)
```javascript
const express = require('express');
const matchingController = require('../controllers/matching.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const router = express.Router();

// Tất cả các APIs ghép trận yêu cầu đăng nhập
router.use(authMiddleware.verifyToken);

// --- APIs cho phòng ghép trận (Hosted Sessions) ---
router.post('/', authMiddleware.requireRole(['CUSTOMER']), matchingController.createSession);
router.get('/', matchingController.querySessions);
router.get('/:id', matchingController.getSessionDetail);
router.post('/:id/join', authMiddleware.requireRole(['CUSTOMER']), matchingController.joinSession);
router.post('/:id/leave', authMiddleware.requireRole(['CUSTOMER']), matchingController.leaveSession);
router.put('/:id/members/:userId', authMiddleware.requireRole(['CUSTOMER']), matchingController.updateMemberStatus);
router.put('/:id/status', authMiddleware.requireRole(['CUSTOMER']), matchingController.updateSessionStatus);

// --- APIs cho hàng chờ tự động (Auto-Matchmaking Queue) ---
router.post('/queue/join', authMiddleware.requireRole(['CUSTOMER']), matchingController.joinQueue);
router.post('/queue/leave', authMiddleware.requireRole(['CUSTOMER']), matchingController.leaveQueue);
router.get('/queue/status', authMiddleware.requireRole(['CUSTOMER']), matchingController.getQueueStatus);

module.exports = router;
```

---

## 5. ⚡ Tích hợp Real-time & Push Notification

Khi ghép trận diễn ra, người dùng cần nhận được cập nhật tức thì. Chúng ta tích hợp thêm các sự kiện Socket.IO và Firebase Cloud Messaging (FCM).

### 1️⃣ WebSocket Events (Socket.IO)

Trong file `src/services/socket-io.service.js`, thêm các luồng Join room và phát sự kiện sau:

* **Tham gia phòng chat/trận đấu:**
  Khi người chơi mở màn hình chi tiết phòng ghép trận `matchingSessionId`, client phát sự kiện join room để nhận tin nhắn/cập nhật cục bộ:
  ```javascript
  // Lắng nghe trên socket connection
  socket.on('join_matching_room', ({ matchingSessionId }) => {
    socket.join(`room_matching_${matchingSessionId}`);
    console.log(`User ${socket.userId} joined matching chat room: ${matchingSessionId}`);
  });

  socket.on('leave_matching_room', ({ matchingSessionId }) => {
    socket.leave(`room_matching_${matchingSessionId}`);
  });
  ```

* **Phát sự kiện cập nhật trạng thái trận:**
  Khi có thành viên mới `APPROVED` hoặc phòng chuyển sang `FULL`, phát tín hiệu cập nhật danh sách real-time đến tất cả người đang trong phòng:
  ```javascript
  // Thêm phương thức vào SocketIOService class:
  notifyMatchingUpdate(matchingSessionId, updateData) {
    if (!this.io) return;
    this.io.to(`room_matching_${matchingSessionId}`).emit('matching_session_updated', {
      matchingSessionId,
      data: updateData,
      timestamp: new Date().toISOString()
    });
  }
  ```

### 2️⃣ Firebase Cloud Messaging (FCM)
Hệ thống sử dụng module `NotificationHelper` để lưu vào DB và gọi `fcmService`. Bản tin thông báo sẽ được định tuyến với metadata để Flutter/React Native Client biết cần chuyển hướng (deep link) tới màn hình ghép trận:
* **Metadata structure:**
  ```json
  {
    "type": "MATCHING",
    "matchingSessionId": "6a0f022b22c105b435bb0eee"
  }
  ```

---

## 6. 🛠️ Hướng dẫn tích hợp vào Backend hiện tại

### Bước 1: Khai báo Routes mới
Mở file [src/routes/index.js](file:///d:/Source/node_be_refactor/src/routes/index.js), tìm phần import routes và đăng ký endpoint mới:

```javascript
// Import route
const matchingRoutes = require('./matching.routes');

// Đăng ký route trong hàm setup/export
router.use('/matching', matchingRoutes);
```

### Bước 2: Bổ sung Cron Job quét hàng chờ tự động
Để tính năng **Auto-Matchmaking Queue** chạy liên tục, thiết lập một job chạy định kỳ mỗi 1-2 phút quét cơ sở dữ liệu.

Tạo file `src/utils/cron-matchmaker.js` hoặc tích hợp vào file khởi động `src/main.js`:
```javascript
const cron = require('node-cron');
const Sport = require('../models/sport.model');
const Facility = require('../models/facility.model');
const matchingService = require('../services/matching.service');

// Quét hàng chờ ghép trận tự động mỗi 1 phút
cron.schedule('*/1 * * * *', async () => {
  console.log('[Cron Job] Bắt đầu quét hàng chờ ghép trận tự động...');
  try {
    // Lấy danh sách các cặp Sport và Facility đang hoạt động để quét
    const sports = await Sport.find({ active: true });
    const facilities = await Facility.find({ active: true });
    const today = new Date().toISOString().split('T')[0];

    for (const sport of sports) {
      for (const facility of facilities) {
        // Chạy thuật toán matching cho từng cụm sân và môn thể thao cho ngày hôm nay
        await matchingService.runMatchmakerAlgorithm(
          sport._id.toString(),
          facility._id.toString(),
          today
        );
      }
    }
  } catch (error) {
    console.error('[Cron Job Error] Lỗi trong tiến trình quét hàng chờ:', error.message);
  }
});
```

Sau đó `require('./utils/cron-matchmaker')` trong `src/main.js` để chạy nền.

---

## 7. 🧪 Kiểm thử Hệ thống (Test Cases)

Để kiểm tra hệ thống ghép trận hoạt động đúng đắn, thực hiện các kịch bản kiểm thử sau:

1. **Test Case 1: Đăng ký Hosted Match thành công**
   - Tài khoản A gọi `POST /api/v1/matching` với các thông số sân, ngày giờ hợp lệ.
   - Kết quả: Trả về trạng thái `OPEN`, trong `members` trống.
2. **Test Case 2: Đăng ký Hosted Match trùng giờ**
   - Tài khoản A gọi lại API đó với khung giờ trùng.
   - Kết quả: Trả về lỗi `400` với thông báo trùng lịch.
3. **Test Case 3: Guest join phòng có chế độ Auto Approve = True**
   - Tài khoản B gọi `POST /api/v1/matching/:id/join`.
   - Kết quả: Thành viên được thêm trực tiếp vào danh sách với status `APPROVED`. Cập nhật `availableSpots` giảm đi 1.
4. **Test Case 4: Gom đủ người (Full Match)**
   - Các tài khoản tiếp theo join cho đến khi đạt đủ `totalPlayersNeeded`.
   - Kết quả: Trạng thái phòng chuyển sang `FULL`. Host và toàn bộ thành viên APPROVED nhận được thông báo socket và FCM "Trận đấu đã gom đủ người!".
5. **Test Case 5: Auto-Matchmaking hoạt động đồng bộ**
   - Tài khoản C đăng ký hàng chờ lúc 17h-19h (`group_size = 2`).
   - Tài khoản D đăng ký hàng chờ lúc 18h-20h (`group_size = 2`).
   - Môn Badminton (`team_size = 4`), cùng cơ sở sân Quận 10, cùng ngày.
   - Kết quả: Trùng giờ (18h-19h, đủ 60 phút), tổng group_size = 4. Sau 1 phút Cron job quét -> Tạo thành công MatchingSession mới ở trạng thái `FULL` cho cả 2 người, cập nhật Queue thành `MATCHED`. Gửi thông báo chúc mừng tới cả hai.
