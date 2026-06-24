# 🚀 Sport Facility Booking & Real-Time Matching Backend API System

Hệ thống RESTful API kết hợp WebSocket hỗ trợ quản lý, đặt sân thể thao (Cầu lông, Bóng đá, Tennis, v.v.), tích hợp công cụ tự động ghép trận (Auto-Matchmaking) và lập lịch cố định (Fixed Schedule) thời gian thực.

> [!NOTE]  
> Hệ thống được xây dựng trên nền tảng **Node.js**, **Express.js**, **MongoDB** (Mongoose ORM) và **Socket.IO** cho các tính năng tương tác thời gian thực.

---

## 🗺️ Sơ đồ Kiến trúc & Luồng Xử lý

```mermaid
graph TD
    Client[Client Mobile / Web App] -->|HTTPS REST Request| Express[Express Server]
    Client -->|WebSocket Connection| SocketIO[Socket.IO Service]
    
    subgraph Express [Express JS Application]
        Routes[Dynamic Router Autoloader] --> Middlewares[Auth & Validation Middlewares]
        Middlewares --> Controllers[Controllers]
        Controllers --> Services[Business Services]
        Services --> Repositories[Repository Pattern]
    end

    subgraph Database & Cloud
        Repositories --> MongoDB[(MongoDB Atlas)]
        Services --> Firebase[Firebase Admin SDK / FCM]
    end

    subgraph Background Jobs (Cron)
        Matchmaker[Matchmaker Engine] -->|Quét hàng chờ tự động / 1 phút| Services
        FixedScheduler[Fixed Scheduler] -->|Tự động sinh lịch / Hàng ngày| Services
    end

    Firebase -->|Push Notification| Client
    SocketIO -->|Real-time Events| Client
```

---

## ✨ Các Tính Năng Cốt Lõi

### 1. 🔄 Cơ Chế Nạp Route Tự Động & Bảng Theo Dõi API (API Tracker)
- **Tự động tải Router**: Toàn bộ routes trong thư mục `src/routes/*.routes.js` được quét và tải tự động lúc khởi động.
- **Visual Progress Tracker**: Tích hợp giao diện web `/api/v1/tracker` cho phép các lập trình viên theo dõi tiến độ hoàn thiện của từng endpoint API (lưu trạng thái trong `localStorage`).
- **Export tài liệu tự động**: Cung cấp API `/api/v1/export` tự động kết xuất danh sách API đang hoạt động thành định dạng Markdown chuẩn để lập tài liệu dự án nhanh chóng.

### 2. ⚡ Hệ Thống Khớp Lệnh Ghép Trận Tự Động (Auto-Matchmaking Engine)
- **Hàng chờ ghép trận**: Người dùng đăng ký vào hàng chờ (`MatchQueue`) chọn môn thể thao, cơ sở, ngày chơi và khung giờ mong muốn (start/end).
- **Thuật toán Matching (Cron Job mỗi phút)**: 
  - Tự động quét và nhóm các người chơi có thời gian chồng lấn trùng khớp từ **60 phút trở lên**.
  - Kiểm tra trạng thái sân trống khả dụng tại cơ sở (`_findAvailableCourt`) trong khung giờ đó.
  - Tự động book sân, tạo phòng ghép đấu (`MatchingSession`) với trạng thái `FULL`.
  - Hủy trạng thái hàng chờ cũ (`MATCHED`) và gửi thông báo real-time cho các thành viên.

### 3. 📅 Lập Lịch Khung Giờ Cố Định (Fixed Scheduling System)
- Hỗ trợ người dùng/chủ sân đăng ký khung giờ cố định (`DAILY` hoặc `WEEKLY` theo các thứ được chỉ định trong tuần).
- **Tránh xung đột lịch (Conflict Resolution)**: Tự động đối chiếu chéo thời gian chồng lấn với các lịch cố định khác đang hoạt động và các lịch đặt sân đơn lẻ trước khi chấp nhận đăng ký.
- **Tiến trình sinh lịch tự động (Self-Healing Cron)**:
  - Chạy lúc **00:05 hàng ngày** (và tự kích hoạt quét bù sau 5 giây khi server vừa khởi động).
  - Tự động sinh trước lịch đặt sân (`Booking`) và phòng ghép đấu tương ứng cho **7 ngày tiếp theo**.

### 4. 🔔 Thông Báo Đa Kênh Thời Gian Thực (Hybrid Notification System)
- **Socket.IO (WebSocket)**: Định tuyến thông báo real-time qua Room cá nhân (`user_${userId}`) hoặc các Room nghiệp vụ (`room_staff`, `room_admin`) xác thực bằng Token JWT.
- **FCM (Firebase Cloud Messaging)**: Hỗ trợ đăng ký thiết bị di động, tự động dọn dẹp các token hết hạn và đẩy Push Notification trên nền thiết bị di động khi người dùng offline.

### 5. 🛡️ Bảo Mật & Phân Quyền Hạt Nhân
- Xác thực Stateless thông qua JWT kép (**Access Token** & **Refresh Token**).
- Phân quyền người dùng chặt chẽ trên từng API: `CUSTOMER`, `STAFF`, và `ADMIN`.
- **Tự động khởi tạo Quản trị viên tối cao**: Khi kết nối database thành công, nếu hệ thống chưa có tài khoản ADMIN, hệ thống sẽ tự động provision tài khoản Super Admin mặc định:
  - **Email**: `admin.system@gmail.com`
  - **Password**: `123456`

---

## 📂 Cấu Trúc Thư Mục Dự Án

```
node_be_refactor/
├── public/                     # Thư mục chứa tài nguyên tĩnh của hệ thống
│   └── uploads/                # Ảnh đại diện, ảnh sân bóng tải lên
├── src/
│   ├── config/                 # Cấu hình kết nối DB (Mongo) & Firebase templates
│   ├── controllers/            # Tầng xử lý Request & Response HTTP
│   ├── middlewares/            # Middleware xác thực JWT, phân quyền, xử lý lỗi chung
│   ├── models/                 # Mẫu Schema Mongoose (Database models)
│   ├── repositories/           # Tầng truy xuất dữ liệu trực tiếp từ Database (DAL)
│   ├── routes/                 # Định nghĩa các Route endpoint theo tài nguyên
│   ├── services/               # Tầng xử lý Logic nghiệp vụ (Business Logic Layer)
│   ├── utils/                  # Cron jobs ghép trận, sinh lịch, helper chung
│   └── main.js                 # Điểm khởi chạy ứng dụng (Entry point)
├── .env                        # File biến môi trường dự án
├── .gitignore                  # Chỉ định các thư mục/file không đẩy lên Git
├── package.json                # Danh sách các thư viện phụ thuộc & Script khởi chạy
└── package-lock.json           # Khóa phiên bản cài đặt của thư viện
```

---

## 🛠️ Cài Đặt & Chạy Dự Án

### 1. Yêu cầu hệ thống
- **Node.js**: Phiên bản `>= 18.x.x`
- **MongoDB**: MongoDB Atlas hoặc MongoDB chạy cục bộ (Local).

### 2. Thiết lập Biến môi trường (`.env`)
Tạo một file `.env` nằm tại thư mục gốc của dự án với nội dung như dưới đây:
```env
PORT=3000
MONGODB_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/dbname
JWT_SECRET=your_jwt_access_secret_key_very_long_string
JWT_REFRESH_SECRET=your_jwt_refresh_secret_key_very_long_string
```

### 3. Cài đặt thư viện phụ thuộc
Chạy lệnh sau tại thư mục gốc dự án:
```bash
npm install
```

### 4. Khởi chạy server

- **Chế độ phát triển (Development Mode)**: Server tự động tải lại khi có thay đổi mã nguồn bằng `nodemon`.
  ```bash
  npm run dev
  ```

- **Chế độ chạy chính thức (Production Mode)**:
  ```bash
  npm start
  ```

---

## 📊 Bảng Danh Sách API Endpoints Chính

Dưới đây là một số API chính được phân nhóm theo nghiệp vụ. Bạn có thể xem danh sách đầy đủ trực tiếp qua giao diện **API Tracker** của server.

| Nhóm | Method | API Path | Quyền truy cập | Mô tả |
| :--- | :---: | :--- | :---: | :--- |
| **Hệ thống** | `GET` | `/api/v1/health` | Public | Kiểm tra trạng thái hoạt động của Server |
| | `GET` | `/api/v1/tracker` | Public | Giao diện Web kiểm tra danh sách và tiến độ API |
| | `GET` | `/api/v1/export` | Public | Xuất file Markdown danh sách API |
| **Auth** | `POST` | `/api/v1/auth/register` | Public | Đăng ký tài khoản người dùng mới |
| | `POST` | `/api/v1/auth/sign-in` | Public | Đăng nhập hệ thống (Lấy Access & Refresh Token) |
| | `POST` | `/api/v1/auth/refresh-token` | Public | Cấp lại Access Token mới bằng Refresh Token |
| | `POST` | `/api/v1/auth/sign-out` | Bearer Token | Đăng xuất và dọn dẹp phiên kết nối |
| **User** | `GET` | `/api/v1/user/:id` | Bearer Token | Xem chi tiết thông tin cá nhân |
| | `PUT` | `/api/v1/user/:id` | Bearer Token | Cập nhật hồ sơ (Tên, Số điện thoại, Sân) |
| | `PUT` | `/api/v1/user/:id/role` | `ADMIN` | Phân quyền vai trò mới cho tài khoản |
| **Facility** | `GET` | `/api/v1/facility` | Bearer Token | Truy vấn danh sách cơ sở thể thao (Phân trang) |
| | `POST` | `/api/v1/facility` | `ADMIN` | Tạo cơ sở thể thao mới |
| **Court** | `POST` | `/api/v1/court` | `ADMIN` | Tạo sân thể thao thuộc một cơ sở |
| | `GET` | `/api/v1/court/:id/slot-config` | Bearer Token | Lấy cấu hình các khung giờ chơi của sân |
| **Booking** | `POST` | `/api/v1/booking` | Bearer Token | Đặt lịch chơi (Book sân) |
| | `PUT` | `/api/v1/booking/:id/status`| `ADMIN`/`STAFF` | Phê duyệt hoặc hủy đặt sân |
| **Matching** | `POST` | `/api/v1/matching` | Bearer Token | Chủ động mở phòng ghép đấu (Host) |
| | `POST` | `/api/v1/matching/join-queue` | Bearer Token | Đăng ký hàng chờ ghép trận tự động |
| | `POST` | `/api/v1/matching/leave-queue` | Bearer Token | Rời khỏi hàng chờ ghép trận tự động |
| **Notify** | `GET` | `/api/v1/notification` | Bearer Token | Lấy danh sách thông báo cá nhân |
| | `PUT` | `/api/v1/notification/mark-all-read` | Bearer Token | Đánh dấu đọc tất cả thông báo |

---

## 📡 Tương Tác Thời Gian Thực (Socket.IO Events)

Để lắng nghe các sự kiện thời gian thực (Real-time), Client cần kết nối WebSocket tới Server kèm theo Bearer Token:

```javascript
import io from 'socket.io-client';

const socket = io('http://localhost:3000', {
  auth: {
    token: 'YOUR_JWT_ACCESS_TOKEN'
  }
});

// Lắng nghe sự kiện thông báo mới
socket.on('notification_received', (payload) => {
  console.log('Thông báo mới:', payload.data.title);
  console.log('Nội dung:', payload.data.content);
});

// Lắng nghe thay đổi của phòng ghép trận mà bạn đang tham gia
socket.on('matching_session_updated', (updatedSession) => {
  console.log('Phòng ghép cập nhật:', updatedSession);
});
```

---

## 🧪 Tài Liệu Kiểm Thử Với Postman

Dự án đi kèm bộ tài liệu Postman chi tiết giúp bạn bắt đầu kiểm thử các luồng chức năng (đăng nhập, book sân, phê duyệt, gửi thông báo) trong chưa đầy 1 phút.

- **File Collection**: [Notification_System_API.postman_collection.json](file:///d:/Source/node_be_refactor/Notification_System_API.postman_collection.json)
- **Tài liệu hướng dẫn chi tiết**:
  - Hướng dẫn nhập Collection & Test luồng cơ bản: [POSTMAN_GUIDE.md](file:///d:/Source/node_be_refactor/POSTMAN_GUIDE.md)
  - Biểu đồ ASCII mô tả kịch bản test trực quan: [POSTMAN_VISUAL_GUIDE.md](file:///d:/Source/node_be_refactor/POSTMAN_VISUAL_GUIDE.md)
  - Trục định tuyến các hướng dẫn kiểm thử: [POSTMAN_INDEX.md](file:///d:/Source/node_be_refactor/POSTMAN_INDEX.md)
  - Tóm tắt hướng dẫn nhanh: [README_POSTMAN.md](file:///d:/Source/node_be_refactor/README_POSTMAN.md)
