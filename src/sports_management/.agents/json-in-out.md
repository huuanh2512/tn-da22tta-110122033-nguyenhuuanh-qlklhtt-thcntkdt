# 📚 API Documentation - JSON Input/Output

**Hệ thống Booking Sân Thể Thao**
> Generated: May 23, 2026

---

## 📋 Mục Lục
1. [Auth APIs](#auth-apis)
2. [User APIs](#user-apis)
3. [Facility APIs](#facility-apis)
4. [Court APIs](#court-apis)
5. [Sport APIs](#sport-apis)
6. [Booking APIs](#booking-apis)
7. [Payment APIs](#payment-apis)
8. [Review APIs](#review-apis)
9. [Notification APIs](#notification-apis)
10. [Upload APIs](#upload-apis)
11. [Health Check](#health-check)

---

## 🔐 Auth APIs

### 1️⃣ POST /api/v1/auth/register
**Mô tả:** Đăng ký tài khoản mới

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Registration successful",
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "email": "user@example.com",
    "role": "CUSTOMER",
    "status": "ACTIVE",
    "createdAt": "2026-05-23T10:30:00Z"
  }
}
```

**Response Error (400):**
```json
{
  "success": false,
  "message": "Email and password are required",
  "code": "MISSING_FIELDS"
}
```

---

### 2️⃣ POST /api/v1/auth/sign-in
**Mô tả:** Đăng nhập hệ thống

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sign in successful",
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "email": "user@example.com",
    "role": "CUSTOMER",
    "status": "ACTIVE"
  }
}
```

**Response Error (401):**
```json
{
  "success": false,
  "message": "Invalid credentials",
  "code": "AUTH_FAILED"
}
```

---

### 3️⃣ POST /api/v1/auth/refresh-token
**Mô tả:** Làm mới access token bằng refresh token

**Request:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Token refreshed successfully",
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response Error (401):**
```json
{
  "success": false,
  "message": "Invalid refresh token",
  "code": "REFRESH_FAILED"
}
```

---

### 4️⃣ POST /api/v1/auth/sign-out
**Mô tả:** Đăng xuất hệ thống

**Request:**
```json
{
  "userId": "507f1f77bcf86cd799439011"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sign out successful",
  "code": "SIGNOUT_SUCCESS"
}
```

**Response Error (400):**
```json
{
  "success": false,
  "message": "User ID is required",
  "code": "MISSING_FIELDS"
}
```

---

### 5️⃣ POST /api/v1/auth/reset-password
**Mô tả:** Đặt lại mật khẩu

**Request:**
```json
{
  "email": "user@example.com",
  "newPassword": "NewPassword123!"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Password reset successfully",
  "code": "PASSWORD_RESET"
}
```

**Response Error (400):**
```json
{
  "success": false,
  "message": "Email and new password are required",
  "code": "MISSING_FIELDS"
}
```

---

## 👥 User APIs
*⚠️ **Yêu cầu:** Tất cả endpoint cần `Authorization: Bearer <accessToken>`*

### 1️⃣ GET /api/v1/user/:id
**Mô tả:** Lấy thông tin profile người dùng

**Parameters:**
- `:id` (string) - User ID

**Response Success (200):**
```json
{
  "success": true,
  "message": "Profile retrieved successfully",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "email": "user@example.com",
    "role": "CUSTOMER",
    "status": "ACTIVE",
    "profile": {
      "fullName": "Nguyễn Văn A",
      "phone": "0912345678",
      "avatar": "https://example.com/avatar.jpg"
    },
    "facilityName": "Sân bóng Mỹ Đình",
    "createdAt": "2026-05-23T10:30:00Z",
    "updatedAt": "2026-05-23T10:30:00Z"
  }
}
```

**Response Error (404):**
```json
{
  "success": false,
  "message": "User not found",
  "code": "NOT_FOUND"
}
```

---

### 2️⃣ PUT /api/v1/user/:id
**Mô tả:** Cập nhật thông tin profile người dùng

**Request:**
```json
{
  "profile": {
    "fullName": "Nguyễn Văn A",
    "phone": "0912345678",
    "avatar": "https://example.com/avatar.jpg"
  },
  "facilityName": "Sân bóng Mỹ Đình"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Profile updated successfully",
  "user": {
    "_id": "507f1f77bcf86cd799439011",
    "email": "user@example.com",
    "profile": {
      "fullName": "Nguyễn Văn A",
      "phone": "0912345678",
      "avatar": "https://example.com/avatar.jpg"
    },
    "facilityName": "Sân bóng Mỹ Đình",
    "updatedAt": "2026-05-23T11:00:00Z"
  }
}
```

**Response Error (403):**
```json
{
  "success": false,
  "message": "Forbidden: You can only update your own profile",
  "code": "FORBIDDEN"
}
```

---

### 3️⃣ GET /api/v1/user/
**Mô tả:** Lấy danh sách người dùng (ADMIN ONLY)

**Query Parameters:**
- `skip` (number) - Số bản ghi bỏ qua, default: 0
- `limit` (number) - Số bản ghi trả về, default: 10
- `role` (string) - Lọc theo role (CUSTOMER, ADMIN, STAFF)
- `status` (string) - Lọc theo status (ACTIVE, INACTIVE)

**Response Success (200):**
```json
{
  "success": true,
  "message": "Users retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439011",
      "email": "user@example.com",
      "role": "CUSTOMER",
      "status": "ACTIVE",
      "profile": {
        "fullName": "Nguyễn Văn A",
        "phone": "0912345678"
      },
      "facilityName": "Sân bóng Mỹ Đình"
    }
  ],
  "total": 1
}
```

---

### 4️⃣ PUT /api/v1/user/:id/role
**Mô tả:** Cập nhật role của người dùng (ADMIN ONLY)

**Request:**
```json
{
  "role": "STAFF"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "User role updated successfully",
  "code": "ROLE_UPDATED"
}
```

---

### 5️⃣ PUT /api/v1/user/:id/status
**Mô tả:** Cập nhật status người dùng (ADMIN ONLY)

**Request:**
```json
{
  "status": "INACTIVE"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "User status updated successfully",
  "code": "STATUS_UPDATED"
}
```

---

### 6️⃣ POST /api/v1/user/:id/assign-facility
**Mô tả:** Gán facility cho người dùng (ADMIN ONLY)

**Request:**
```json
{
  "facilityId": "507f1f77bcf86cd799439012"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Facility assigned successfully",
  "code": "FACILITY_ASSIGNED"
}
```

---

## 🏢 Facility APIs
*⚠️ **Yêu cầu:** Tất cả endpoint cần `Authorization: Bearer <accessToken>`*

### 1️⃣ GET /api/v1/facility/
**Mô tả:** Lấy danh sách cơ sở thể thao

**Query Parameters:**
- `skip` (number) - Số bản ghi bỏ qua, default: 0
- `limit` (number) - Số bản ghi trả về, default: 10
- `name` (string) - Tìm kiếm theo tên
- `city` (string) - Lọc theo thành phố
- `active` (boolean) - Lọc theo trạng thái

**Response Success (200):**
```json
{
  "success": true,
  "message": "Facilities retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439012",
      "name": "Sân bóng Mỹ Đình",
      "city": "Hà Nội",
      "fullAddress": "P5, Mỹ Đình, Nam Từ Liêm, Hà Nội",
      "active": true,
      "staffIds": ["507f1f77bcf86cd799439013"],
      "createdAt": "2026-05-23T10:30:00Z"
    }
  ],
  "total": 1
}
```

---

### 2️⃣ POST /api/v1/facility/
**Mô tả:** Tạo cơ sở thể thao mới (ADMIN ONLY)

**Request:**
```json
{
  "name": "Sân bóng Mỹ Đình",
  "city": "Hà Nội",
  "fullAddress": "P5, Mỹ Đình, Nam Từ Liêm, Hà Nội",
  "active": true,
  "staffIds": ["507f1f77bcf86cd799439013", "507f1f77bcf86cd799439014"]
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Facility created successfully",
  "facility": {
    "_id": "507f1f77bcf86cd799439012",
    "name": "Sân bóng Mỹ Đình",
    "city": "Hà Nội",
    "fullAddress": "P5, Mỹ Đình, Nam Từ Liêm, Hà Nội",
    "active": true,
    "staffIds": ["507f1f77bcf86cd799439013", "507f1f77bcf86cd799439014"],
    "createdAt": "2026-05-23T11:00:00Z"
  }
}
```

---

### 3️⃣ PUT /api/v1/facility/:id
**Mô tả:** Cập nhật thông tin cơ sở (ADMIN ONLY)

**Request:**
```json
{
  "name": "Sân bóng Mỹ Đình - Updated",
  "city": "Hà Nội",
  "fullAddress": "P5, Mỹ Đình, Nam Từ Liêm, Hà Nội",
  "active": true,
  "staffIds": ["507f1f77bcf86cd799439013"]
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Facility updated successfully",
  "facility": {
    "_id": "507f1f77bcf86cd799439012",
    "name": "Sân bóng Mỹ Đình - Updated",
    "city": "Hà Nội",
    "fullAddress": "P5, Mỹ Đình, Nam Từ Liêm, Hà Nội",
    "active": true,
    "staffIds": ["507f1f77bcf86cd799439013"],
    "updatedAt": "2026-05-23T11:30:00Z"
  }
}
```

---

### 4️⃣ DELETE /api/v1/facility/:id
**Mô tả:** Xóa cơ sở (ADMIN ONLY)

**Parameters:**
- `:id` (string) - Facility ID

**Response Success (200):**
```json
{
  "success": true,
  "message": "Facility deleted successfully",
  "code": "DELETE_SUCCESS"
}
```

---

## 🏀 Court APIs
*⚠️ **Yêu cầu:** Tất cả endpoint cần `Authorization: Bearer <accessToken>`*

### 1️⃣ GET /api/v1/court/
**Mô tả:** Lấy danh sách sân

**Query Parameters:**
- `skip` (number) - Số bản ghi bỏ qua, default: 0
- `limit` (number) - Số bản ghi trả về, default: 10
- `facilityId` (string) - Lọc theo facility
- `sportId` (string) - Lọc theo môn thể thao
- `status` (string) - Lọc theo trạng thái

**Response Success (200):**
```json
{
  "success": true,
  "message": "Courts retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439020",
      "name": "Sân 1",
      "code": "COURT_001",
      "facilityId": "507f1f77bcf86cd799439012",
      "sportId": "507f1f77bcf86cd799439030",
      "status": "ACTIVE",
      "pricePerHour": 200000,
      "createdAt": "2026-05-23T10:30:00Z"
    }
  ],
  "total": 1
}
```

---

### 2️⃣ POST /api/v1/court/
**Mô tả:** Tạo sân mới (ADMIN ONLY)

**Request:**
```json
{
  "name": "Sân 1",
  "facilityId": "507f1f77bcf86cd799439012",
  "sportId": "507f1f77bcf86cd799439030",
  "code": "COURT_001",
  "status": "ACTIVE",
  "pricePerHour": 200000
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Court created successfully",
  "court": {
    "_id": "507f1f77bcf86cd799439020",
    "name": "Sân 1",
    "code": "COURT_001",
    "facilityId": "507f1f77bcf86cd799439012",
    "sportId": "507f1f77bcf86cd799439030",
    "status": "ACTIVE",
    "pricePerHour": 200000,
    "createdAt": "2026-05-23T11:00:00Z"
  }
}
```

---

### 3️⃣ PUT /api/v1/court/:id
**Mô tả:** Cập nhật thông tin sân (ADMIN ONLY)

**Request:**
```json
{
  "name": "Sân 1 - Updated",
  "facilityId": "507f1f77bcf86cd799439012",
  "sportId": "507f1f77bcf86cd799439030",
  "code": "COURT_001",
  "status": "ACTIVE",
  "pricePerHour": 250000
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Court updated successfully",
  "court": {
    "_id": "507f1f77bcf86cd799439020",
    "name": "Sân 1 - Updated",
    "pricePerHour": 250000,
    "updatedAt": "2026-05-23T11:30:00Z"
  }
}
```

---

### 4️⃣ DELETE /api/v1/court/:id
**Mô tả:** Xóa sân (ADMIN ONLY)

**Parameters:**
- `:id` (string) - Court ID

**Response Success (200):**
```json
{
  "success": true,
  "message": "Court deleted successfully",
  "code": "DELETE_SUCCESS"
}
```

---

### 5️⃣ GET /api/v1/court/:id/slot-config
**Mô tả:** Lấy cấu hình slot thời gian của sân

**Parameters:**
- `:id` (string) - Court ID

**Response Success (200):**
```json
{
  "success": true,
  "message": "Slot config retrieved successfully",
  "config": {
    "_id": "507f1f77bcf86cd799439021",
    "courtId": "507f1f77bcf86cd799439020",
    "openingMinutes": 420,
    "closingMinutes": 1320,
    "slotDurationMinutes": 60,
    "slots": [
      {
        "slotIndex": 1,
        "startMinutes": 420,
        "endMinutes": 480,
        "isAvailable": true
      },
      {
        "slotIndex": 2,
        "startMinutes": 480,
        "endMinutes": 540,
        "isAvailable": false
      }
    ]
  }
}
```

---

### 6️⃣ PUT /api/v1/court/:id/slot-config
**Mô tả:** Cập nhật hoặc tạo slot config (ADMIN ONLY)

**Request:**
```json
{
  "openingMinutes": 420,
  "closingMinutes": 1320,
  "slotDurationMinutes": 60,
  "slots": [
    {
      "slotIndex": 1,
      "startMinutes": 420,
      "endMinutes": 480,
      "isAvailable": true
    }
  ]
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Slot config updated successfully",
  "config": {
    "_id": "507f1f77bcf86cd799439021",
    "courtId": "507f1f77bcf86cd799439020",
    "openingMinutes": 420,
    "closingMinutes": 1320,
    "slotDurationMinutes": 60,
    "slots": [
      {
        "slotIndex": 1,
        "startMinutes": 420,
        "endMinutes": 480,
        "isAvailable": true
      }
    ]
  }
}
```

---

## ⚽ Sport APIs
*⚠️ **Yêu cầu:** Tất cả endpoint cần `Authorization: Bearer <accessToken>`*

### 1️⃣ GET /api/v1/sport/
**Mô tả:** Lấy danh sách môn thể thao

**Query Parameters:**
- `skip` (number) - Số bản ghi bỏ qua, default: 0
- `limit` (number) - Số bản ghi trả về, default: 10
- `name` (string) - Tìm kiếm theo tên
- `active` (boolean) - Lọc theo trạng thái

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sports retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439030",
      "name": "Bóng đá 5",
      "description": "Bóng đá phòng, 5 người một bên",
      "teamSize": 5,
      "active": true,
      "createdAt": "2026-05-23T10:30:00Z"
    }
  ],
  "total": 1
}
```

---

### 2️⃣ POST /api/v1/sport/
**Mô tả:** Tạo môn thể thao mới (ADMIN ONLY)

**Request:**
```json
{
  "name": "Bóng đá 5",
  "description": "Bóng đá phòng, 5 người một bên",
  "teamSize": 5,
  "active": true
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sport created successfully",
  "sport": {
    "_id": "507f1f77bcf86cd799439030",
    "name": "Bóng đá 5",
    "description": "Bóng đá phòng, 5 người một bên",
    "teamSize": 5,
    "active": true,
    "createdAt": "2026-05-23T11:00:00Z"
  }
}
```

---

### 3️⃣ PUT /api/v1/sport/:id
**Mô tả:** Cập nhật môn thể thao (ADMIN ONLY)

**Request:**
```json
{
  "name": "Bóng đá 5 - Updated",
  "description": "Bóng đá phòng, 5 người một bên, dành cho all level",
  "teamSize": 5,
  "active": true
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sport updated successfully",
  "sport": {
    "_id": "507f1f77bcf86cd799439030",
    "name": "Bóng đá 5 - Updated",
    "description": "Bóng đá phòng, 5 người một bên, dành cho all level",
    "teamSize": 5,
    "active": true,
    "updatedAt": "2026-05-23T11:30:00Z"
  }
}
```

---

### 4️⃣ DELETE /api/v1/sport/:id
**Mô tả:** Xóa môn thể thao (ADMIN ONLY)

**Parameters:**
- `:id` (string) - Sport ID

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sport deleted successfully",
  "code": "DELETE_SUCCESS"
}
```

---

## 📅 Booking APIs
*⚠️ **Yêu cầu:** Tất cả endpoint cần `Authorization: Bearer <accessToken>`*

### 1️⃣ POST /api/v1/booking/
**Mô tả:** Tạo lịch đặt sân

**Request:**
```json
{
  "courtId": "507f1f77bcf86cd799439020",
  "bookingDate": "2026-06-15",
  "startMinutes": 420,
  "endMinutes": 480,
  "totalPrice": 200000
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Booking created successfully",
  "booking": {
    "_id": "507f1f77bcf86cd799439040",
    "userId": "507f1f77bcf86cd799439011",
    "courtId": "507f1f77bcf86cd799439020",
    "bookingDate": "2026-06-15",
    "startMinutes": 420,
    "endMinutes": 480,
    "totalPrice": 200000,
    "status": "PENDING",
    "createdAt": "2026-05-23T11:00:00Z"
  }
}
```

---

### 2️⃣ GET /api/v1/booking/
**Mô tả:** Lấy danh sách lịch đặt sân

**Query Parameters:**
- `skip` (number) - Số bản ghi bỏ qua, default: 0
- `limit` (number) - Số bản ghi trả về, default: 10
- `status` (string) - Lọc theo trạng thái (PENDING, CONFIRMED, CANCELLED, COMPLETED)
- `bookingDate` (string) - Lọc theo ngày đặt

**Note:** CUSTOMER chỉ có thể xem booking của chính họ

**Response Success (200):**
```json
{
  "success": true,
  "message": "Bookings retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439040",
      "userId": "507f1f77bcf86cd799439011",
      "courtId": "507f1f77bcf86cd799439020",
      "bookingDate": "2026-06-15",
      "startMinutes": 420,
      "endMinutes": 480,
      "totalPrice": 200000,
      "status": "PENDING",
      "createdAt": "2026-05-23T11:00:00Z"
    }
  ],
  "total": 1
}
```

---

### 3️⃣ GET /api/v1/booking/:id
**Mô tả:** Lấy chi tiết lịch đặt sân

**Parameters:**
- `:id` (string) - Booking ID

**Response Success (200):**
```json
{
  "success": true,
  "message": "Booking detail retrieved successfully",
  "booking": {
    "_id": "507f1f77bcf86cd799439040",
    "userId": "507f1f77bcf86cd799439011",
    "user": {
      "_id": "507f1f77bcf86cd799439011",
      "email": "user@example.com",
      "profile": {
        "fullName": "Nguyễn Văn A",
        "phone": "0912345678"
      }
    },
    "courtId": "507f1f77bcf86cd799439020",
    "court": {
      "_id": "507f1f77bcf86cd799439020",
      "name": "Sân 1",
      "code": "COURT_001",
      "pricePerHour": 200000
    },
    "bookingDate": "2026-06-15",
    "startMinutes": 420,
    "endMinutes": 480,
    "totalPrice": 200000,
    "status": "PENDING",
    "createdAt": "2026-05-23T11:00:00Z"
  }
}
```

---

### 4️⃣ PUT /api/v1/booking/:id/status
**Mô tả:** Cập nhật trạng thái booking (ADMIN/STAFF ONLY)

**Request:**
```json
{
  "status": "CONFIRMED"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Booking status updated successfully",
  "booking": {
    "_id": "507f1f77bcf86cd799439040",
    "status": "CONFIRMED",
    "updatedAt": "2026-05-23T11:30:00Z"
  }
}
```

---

## 💳 Payment APIs
*⚠️ **Yêu cầu:** Tất cả endpoint cần `Authorization: Bearer <accessToken>`*

### 1️⃣ GET /api/v1/payment/
**Mô tả:** Lấy danh sách thanh toán

**Query Parameters:**
- `skip` (number) - Số bản ghi bỏ qua, default: 0
- `limit` (number) - Số bản ghi trả về, default: 10
- `status` (string) - Lọc theo trạng thái (PENDING, SUCCESS, FAILED)
- `bookingId` (string) - Lọc theo booking ID

**Note:** CUSTOMER chỉ có thể xem thanh toán của chính họ

**Response Success (200):**
```json
{
  "success": true,
  "message": "Payments retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439050",
      "userId": "507f1f77bcf86cd799439011",
      "bookingId": "507f1f77bcf86cd799439040",
      "amount": 200000,
      "method": "BANK_TRANSFER",
      "transactionId": "TXN_001_001_2026",
      "status": "PENDING",
      "createdAt": "2026-05-23T11:00:00Z"
    }
  ],
  "total": 1
}
```

---

### 2️⃣ POST /api/v1/payment/
**Mô tả:** Tạo thanh toán mới

**Request:**
```json
{
  "bookingId": "507f1f77bcf86cd799439040",
  "amount": 200000,
  "method": "BANK_TRANSFER",
  "transactionId": "TXN_001_001_2026"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Payment created successfully",
  "payment": {
    "_id": "507f1f77bcf86cd799439050",
    "userId": "507f1f77bcf86cd799439011",
    "bookingId": "507f1f77bcf86cd799439040",
    "amount": 200000,
    "method": "BANK_TRANSFER",
    "transactionId": "TXN_001_001_2026",
    "status": "PENDING",
    "createdAt": "2026-05-23T11:00:00Z"
  }
}
```

---

### 3️⃣ PUT /api/v1/payment/:id/status
**Mô tả:** Cập nhật trạng thái thanh toán (ADMIN/STAFF ONLY)

**Request:**
```json
{
  "status": "SUCCESS",
  "transactionId": "TXN_001_001_2026_CONFIRMED"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Payment status updated successfully",
  "payment": {
    "_id": "507f1f77bcf86cd799439050",
    "status": "SUCCESS",
    "transactionId": "TXN_001_001_2026_CONFIRMED",
    "updatedAt": "2026-05-23T11:30:00Z"
  }
}
```

---

## ⭐ Review APIs
*⚠️ **Yêu cầu:** Tất cả endpoint cần `Authorization: Bearer <accessToken>`*

### 1️⃣ GET /api/v1/review/
**Mô tả:** Lấy danh sách review

**Query Parameters:**
- `skip` (number) - Số bản ghi bỏ qua, default: 0
- `limit` (number) - Số bản ghi trả về, default: 10
- `courtId` (string) - Lọc theo court ID
- `rating` (number) - Lọc theo rating

**Response Success (200):**
```json
{
  "success": true,
  "message": "Reviews retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439060",
      "userId": "507f1f77bcf86cd799439011",
      "user": {
        "fullName": "Nguyễn Văn A"
      },
      "courtId": "507f1f77bcf86cd799439020",
      "rating": 5,
      "comment": "Sân rất sạch, nhân viên thân thiện. Rất thích!",
      "createdAt": "2026-05-23T11:00:00Z"
    }
  ],
  "total": 1
}
```

---

### 2️⃣ POST /api/v1/review/
**Mô tả:** Tạo review sân

**Request:**
```json
{
  "courtId": "507f1f77bcf86cd799439020",
  "rating": 5,
  "comment": "Sân rất sạch, nhân viên thân thiện. Rất thích!"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Review created successfully",
  "review": {
    "_id": "507f1f77bcf86cd799439060",
    "userId": "507f1f77bcf86cd799439011",
    "courtId": "507f1f77bcf86cd799439020",
    "rating": 5,
    "comment": "Sân rất sạch, nhân viên thân thiện. Rất thích!",
    "createdAt": "2026-05-23T11:00:00Z"
  }
}
```

**Response Error (400):**
```json
{
  "success": false,
  "message": "Rating must be between 1 and 5",
  "code": "INVALID_RATING"
}
```

---

### 3️⃣ DELETE /api/v1/review/:id
**Mô tả:** Xóa review (ADMIN ONLY)

**Parameters:**
- `:id` (string) - Review ID

**Response Success (200):**
```json
{
  "success": true,
  "message": "Review deleted successfully",
  "code": "DELETE_SUCCESS"
}
```

---

## 🔔 Notification APIs
*⚠️ **Yêu cầu:** Tất cả endpoint cần `Authorization: Bearer <accessToken>`*

### 1️⃣ GET /api/v1/notification/
**Mô tả:** Lấy thông báo của người dùng hiện tại

**Query Parameters:**
- `skip` (number) - Số bản ghi bỏ qua, default: 0
- `limit` (number) - Số bản ghi trả về, default: 10

**Response Success (200):**
```json
{
  "success": true,
  "message": "Notifications retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439070",
      "userId": "507f1f77bcf86cd799439011",
      "title": "Booking Confirmation",
      "body": "Your booking for Court 1 on 2026-06-15 has been confirmed",
      "type": "BOOKING",
      "isRead": false,
      "createdAt": "2026-05-23T11:00:00Z"
    }
  ],
  "total": 5,
  "unreadCount": 3
}
```

---

### 2️⃣ POST /api/v1/notification/
**Mô tả:** Tạo thông báo hệ thống (ADMIN ONLY)

**Request:**
```json
{
  "userId": "507f1f77bcf86cd799439011",
  "title": "System Maintenance",
  "body": "The system will be under maintenance on 2026-06-20",
  "type": "SYSTEM"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Notification created successfully",
  "notification": {
    "_id": "507f1f77bcf86cd799439071",
    "userId": "507f1f77bcf86cd799439011",
    "title": "System Maintenance",
    "body": "The system will be under maintenance on 2026-06-20",
    "type": "SYSTEM",
    "isRead": false,
    "createdAt": "2026-05-23T11:00:00Z"
  }
}
```

---

### 3️⃣ PUT /api/v1/notification/:id/read
**Mô tả:** Đánh dấu thông báo là đã đọc

**Parameters:**
- `:id` (string) - Notification ID

**Response Success (200):**
```json
{
  "success": true,
  "message": "Notification marked as read",
  "notification": {
    "_id": "507f1f77bcf86cd799439070",
    "isRead": true,
    "updatedAt": "2026-05-23T11:30:00Z"
  }
}
```

---

### 4️⃣ PUT /api/v1/notification/mark-all-read
**Mô tả:** Đánh dấu tất cả thông báo là đã đọc

**Response Success (200):**
```json
{
  "success": true,
  "message": "All notifications marked as read",
  "code": "MARK_ALL_SUCCESS"
}
```

---

## 📸 Upload APIs
*⚠️ **Yêu cầu:** Tất cả endpoint cần `Authorization: Bearer <accessToken>`*

### 1️⃣ POST /api/v1/upload/single
**Mô tả:** Tải lên một ảnh đơn

**Request:** Form-data
- `file` (file) - File ảnh cần tải lên

**Response Success (200):**
```json
{
  "success": true,
  "message": "Tải ảnh lên thành công",
  "data": {
    "id": "507f1f77bcf86cd799439080",
    "filename": "avatar_1716455400123.jpg",
    "originalName": "avatar.jpg",
    "mimetype": "image/jpeg",
    "size": 245600,
    "url": "https://example.com/uploads/avatar_1716455400123.jpg",
    "uploadedAt": "2026-05-23T11:00:00Z"
  }
}
```

**Response Error (400):**
```json
{
  "success": false,
  "message": "Vui lòng chọn một file để tải lên",
  "code": "MISSING_FILE"
}
```

---

### 2️⃣ POST /api/v1/upload/multiple
**Mô tả:** Tải lên nhiều ảnh cùng lúc

**Request:** Form-data
- `files` (files) - Nhiều file ảnh cần tải lên

**Response Success (200):**
```json
{
  "success": true,
  "message": "Tải các ảnh lên thành công",
  "data": [
    {
      "id": "507f1f77bcf86cd799439080",
      "filename": "image_1_1716455400123.jpg",
      "originalName": "image_1.jpg",
      "mimetype": "image/jpeg",
      "size": 245600,
      "url": "https://example.com/uploads/image_1_1716455400123.jpg",
      "uploadedAt": "2026-05-23T11:00:00Z"
    },
    {
      "id": "507f1f77bcf86cd799439081",
      "filename": "image_2_1716455400124.jpg",
      "originalName": "image_2.jpg",
      "mimetype": "image/jpeg",
      "size": 312850,
      "url": "https://example.com/uploads/image_2_1716455400124.jpg",
      "uploadedAt": "2026-05-23T11:00:00Z"
    }
  ]
}
```

**Response Error (400):**
```json
{
  "success": false,
  "message": "Vui lòng chọn ít nhất một file",
  "code": "MISSING_FILES"
}
```

---

## ✅ Health Check

### GET /api/v1/health
**Mô tả:** Kiểm tra trạng thái API

**Response Success (200):**
```json
{
  "success": true,
  "message": "API is running",
  "code": "OK"
}
```

---

## 📌 Notes - Các Ghi Chú Quan Trọng

### Các HTTP Status Code Thường Dùng:
- **200 OK** - Yêu cầu thành công
- **400 Bad Request** - Dữ liệu đầu vào không hợp lệ
- **401 Unauthorized** - Token không hợp lệ hoặc hết hạn
- **403 Forbidden** - Không có quyền truy cập
- **404 Not Found** - Tài nguyên không tìm thấy
- **500 Internal Server Error** - Lỗi server

### Headers Bắt Buộc:
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

### Các Roles Hệ Thống:
- **ADMIN** - Quản trị viên hệ thống
- **STAFF** - Nhân viên sân
- **CUSTOMER** - Khách hàng

### Các Status Phổ Biến:
- **Booking Status:** PENDING, CONFIRMED, CANCELLED, COMPLETED
- **Payment Status:** PENDING, SUCCESS, FAILED
- **User Status:** ACTIVE, INACTIVE
- **Facility/Court Status:** ACTIVE, INACTIVE

### Ký Hiệu Thời Gian:
- `startMinutes`, `endMinutes` = Số phút tính từ 00:00
  - Ví dụ: 420 = 7:00 AM, 1320 = 10:00 PM

---

## 📞 Support & Contact
For any issues or questions, please contact the development team at: support@example.com

---

*Last Updated: May 23, 2026*
