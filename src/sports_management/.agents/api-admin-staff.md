# 🔌 API Documentation — Admin & Staff CRM Portal
## HỆ THỐNG QUẢN LÝ KHU LIÊN HỢP THỂ THAO (SPORT ENERGY)

> **Nguồn gốc tài liệu:** Trích xuất trực tiếp từ source code Flutter `server_module` (Dart/Dio).  
> **Cập nhật lần cuối:** 2026-05-28  
> **Base URL Mobile:** `http://10.0.2.2:3000/api/v1` (Android Emulator)  
> **Base URL CRM Web:** `http://localhost:3000/api/v1`  

---

## 📋 Mục Lục
1. [Quy ước Chung & Kiến trúc](#-quy-ước-chung--kiến-trúc)
2. [Error Code Reference](#-error-code-reference-toàn-diện)
3. [I. Auth APIs](#i-auth-apis)
4. [II. User APIs](#ii-user-apis)
5. [III. Facility APIs](#iii-facility-apis)
6. [IV. Court APIs](#iv-court-apis)
7. [V. Sport APIs](#v-sport-apis)
8. [VI. Booking APIs](#vi-booking-apis)
9. [VII. Payment APIs](#vii-payment-apis)
10. [VIII. Review APIs](#viii-review-apis)
11. [IX. Notification APIs](#ix-notification-apis)
12. [X. Upload APIs](#x-upload-apis)
13. [XI. Content APIs](#xi-content-apis)
14. [XII. Luồng Nghiệp vụ Đặc biệt](#xii-luồng-nghiệp-vụ-đặc-biệt)
15. [Health Check](#health-check)

---

## 🚦 Quy ước Chung & Kiến trúc

### Network Client (Dart — `DioClient`)
```dart
// lib/core/dio_client.dart
// BaseUrl: ApiConfig.baseUrl = 'http://10.0.2.2:3000/api/v1'
// connectTimeout: 30000ms
// receiveTimeout: 30000ms
// contentType: 'application/json'
// responseType: ResponseType.json

// Auth Interceptor tự động gắn Bearer token vào mọi request:
// options.headers['Authorization'] = 'Bearer $token';
```

### Cấu trúc Response Chuẩn (`BaseResponse<T>`)
```dart
class BaseResponse<T> {
  final bool success;   // true = thành công, false = thất bại
  final String? message; // Mô tả kết quả
  final T? data;         // Payload data (tuỳ endpoint)
}
```

> **Lưu ý quan trọng:** Các endpoint khác nhau sẽ đặt payload ở key khác nhau trong root JSON:
> - Ví dụ: `{ "success": true, "user": {...} }` — không phải `{ "data": { "user": {...} } }`
> - Mỗi endpoint dưới đây ghi rõ key payload ở Response.

### Request Headers Bắt buộc
```http
Authorization: Bearer <accessToken>
Content-Type: application/json
```
> Ngoại lệ: Upload API dùng `Content-Type: multipart/form-data`

### Quy ước Thời gian (Phút từ 00:00)
| Giá trị | Ý nghĩa |
|---------|---------|
| `420`   | 07:00 AM |
| `480`   | 08:00 AM |
| `720`   | 12:00 PM |
| `1020`  | 05:00 PM |
| `1320`  | 10:00 PM |

> **Công thức:** `minutes = hour * 60 + minute`

### Roles Hệ thống
| Role | Quyền hạn |
|------|-----------|
| `ADMIN` | Toàn quyền hệ thống |
| `STAFF` | Vận hành sân: booking, payment, view reports |
| `CUSTOMER` | Chỉ đặt sân & xem lịch sử cá nhân |

### Trạng thái Hệ thống
| Loại | Giá trị hợp lệ |
|------|----------------|
| Booking Status | `PENDING`, `CONFIRMED`, `COMPLETED`, `CANCELLED` |
| Payment Status | `PENDING`, `SUCCESS`, `FAILED` |
| User Status | `ACTIVE`, `INACTIVE` |
| Facility/Court Status | `ACTIVE`, `INACTIVE` |

---

## ❌ Error Code Reference Toàn diện

| HTTP Status | `code` | Mô tả | Nguyên nhân phổ biến |
|-------------|--------|--------|----------------------|
| 400 | `MISSING_FIELDS` | Thiếu trường bắt buộc | Request body không đủ field |
| 400 | `INVALID_RATING` | Rating không hợp lệ | Rating không nằm trong [1, 5] |
| 400 | `INVALID_STATUS` | Status không hợp lệ | Giá trị status không nằm trong enum |
| 400 | `CONFLICTED_SLOT` | Khung giờ đã bị đặt | Booking overlap với slot đã tồn tại |
| 400 | `MISSING_FILE` | Thiếu file upload | Không có file trong form-data |
| 400 | `MISSING_FILES` | Thiếu files upload | Không có files trong form-data |
| 401 | `AUTH_FAILED` | Đăng nhập thất bại | Sai email/password |
| 401 | `TOKEN_EXPIRED` | Access token hết hạn | Token đã quá hạn |
| 401 | `REFRESH_FAILED` | Refresh token không hợp lệ | Refresh token hết hạn hoặc bị thu hồi |
| 403 | `FORBIDDEN` | Không có quyền | Role không đủ quyền truy cập endpoint |
| 404 | `NOT_FOUND` | Không tìm thấy | Resource ID không tồn tại |
| 409 | `EMAIL_EXISTS` | Email đã tồn tại | Đăng ký với email đã dùng |
| 500 | `INTERNAL_ERROR` | Lỗi server | Lỗi không xác định |

> **Xử lý 401 tự động:** Client cần implement interceptor — khi nhận 401 `TOKEN_EXPIRED`, tự động gọi `/auth/refresh-token`, nếu thành công thì retry request gốc; nếu `REFRESH_FAILED` thì logout.

---

## I. Auth APIs

> **Lưu ý CRM:** Sau khi login thành công, CRM chỉ cho phép `role === "ADMIN"` hoặc `role === "STAFF"` vào dashboard. Nếu `role === "CUSTOMER"` → hiển thị lỗi "Tài khoản không có quyền truy cập CRM" và clear token.

---

### `POST /api/v1/auth/register`
**Service Dart:** `AuthService.register()`  
**Quyền hạn:** Public  
**Mô tả:** Đăng ký tài khoản mới (mặc định role = CUSTOMER)

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}
```

| Field | Type | Required | Constraint |
|-------|------|----------|------------|
| `email` | string | ✅ | Format email hợp lệ |
| `password` | string | ✅ | Tối thiểu 6 ký tự |

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
    "createdAt": "2026-05-28T10:30:00Z"
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

**Response Error (409):**
```json
{
  "success": false,
  "message": "Email already exists",
  "code": "EMAIL_EXISTS"
}
```

---

### `POST /api/v1/auth/sign-in`
**Service Dart:** `AuthService.signIn()`  
**Quyền hạn:** Public  
**Mô tả:** Đăng nhập hệ thống. Trả về `accessToken` + `refreshToken` + thông tin user cơ bản.

**Request Body:**
```json
{
  "email": "staff@example.com",
  "password": "SecurePassword123!"
}
```

| Field | Type | Required | Constraint |
|-------|------|----------|------------|
| `email` | string | ✅ | |
| `password` | string | ✅ | |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sign in successful",
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "507f1f77bcf86cd799439013",
    "email": "staff@example.com",
    "role": "STAFF",
    "status": "ACTIVE"
  }
}
```

> **Lưu ý:** Response chỉ chứa thông tin user cơ bản. Để lấy đầy đủ profile (fullName, phone, facilityId...), client phải gọi tiếp `GET /api/v1/user/:id` ngay sau khi sign-in thành công (xem `AuthRepositoryImpl.login()`).

**Response Error (401):**
```json
{
  "success": false,
  "message": "Invalid credentials",
  "code": "AUTH_FAILED"
}
```

**Response Error (403):**
```json
{
  "success": false,
  "message": "Account is inactive",
  "code": "FORBIDDEN"
}
```

---

### `POST /api/v1/auth/refresh-token`
**Service Dart:** `AuthService.refreshToken()`  
**Quyền hạn:** Public (không cần Bearer token)  
**Mô tả:** Làm mới access token. Gọi khi nhận được lỗi 401 `TOKEN_EXPIRED`.

**Request Body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

| Field | Type | Required | Constraint |
|-------|------|----------|------------|
| `refreshToken` | string | ✅ | JWT refresh token |

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

### `POST /api/v1/auth/sign-out`
**Service Dart:** `AuthService.signOut()`  
**Quyền hạn:** Authenticated  
**Mô tả:** Đăng xuất — thu hồi refresh token phía server.

**Request Body:**
```json
{
  "userId": "507f1f77bcf86cd799439013"
}
```

| Field | Type | Required |
|-------|------|----------|
| `userId` | string (ObjectId) | ✅ |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sign out successful",
  "code": "SIGNOUT_SUCCESS"
}
```

---

### `POST /api/v1/auth/reset-password`
**Service Dart:** `AuthService.resetPassword()`  
**Quyền hạn:** Public  
**Mô tả:** Đặt lại mật khẩu (không cần token xác thực email — chỉ cần biết email).

**Request Body:**
```json
{
  "email": "user@example.com",
  "newPassword": "NewPassword123!"
}
```

| Field | Type | Required | Constraint |
|-------|------|----------|------------|
| `email` | string | ✅ | Email đã đăng ký |
| `newPassword` | string | ✅ | Tối thiểu 6 ký tự |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Password reset successfully",
  "code": "PASSWORD_RESET"
}
```

---

## II. User APIs

> **Yêu cầu:** `Authorization: Bearer <accessToken>`

---

### `GET /api/v1/user/`
**Service Dart:** `UserService.getUsers()`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Lấy danh sách toàn bộ người dùng. Dùng để quản lý user, gán role, kích hoạt/vô hiệu hoá.

**Query Parameters (tùy chọn):**
| Param | Type | Mô tả | Ví dụ |
|-------|------|--------|-------|
| `skip` | number | Số bản ghi bỏ qua (offset) | `0` |
| `limit` | number | Số bản ghi trả về | `10` |
| `role` | string | Lọc theo role | `STAFF` |
| `status` | string | Lọc theo trạng thái | `ACTIVE` |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Users retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439011",
      "email": "customer@example.com",
      "role": "CUSTOMER",
      "status": "ACTIVE",
      "profile": {
        "fullName": "Nguyễn Văn A",
        "phone": "0912345678",
        "avatar": "https://example.com/uploads/avatar.jpg"
      },
      "facilityId": "507f1f77bcf86cd799439012",
      "facilityName": "Sân bóng Mỹ Đình",
      "createdAt": "2026-05-23T10:30:00Z"
    }
  ],
  "total": 100
}
```

**Mapping Dart → JSON key:**
| Dart Entity | JSON Response key |
|-------------|-------------------|
| `UserModel.id` | `_id` hoặc `id` (client đọc cả 2: `json['id'] ?? json['_id']`) |
| `UserModel.name` | `name` |
| `UserModel.avatar` | `avatar` |
| `UserModel.role` | `role` |
| `UserModel.status` | `status` |
| `UserModel.createdAt` | `createdAt` (ISO 8601 string) |

---

### `GET /api/v1/user/:id`
**Service Dart:** `UserService.getUserById(id)`  
**Quyền hạn:** Authenticated (bản thân hoặc ADMIN)  
**Mô tả:** Lấy chi tiết profile người dùng. Sau sign-in, client gọi ngay với userId từ response sign-in để lấy `profile.fullName`, `facilityId`.

**Path Parameter:**
| Param | Type | Required |
|-------|------|----------|
| `:id` | string (ObjectId) | ✅ |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Profile retrieved successfully",
  "user": {
    "_id": "507f1f77bcf86cd799439013",
    "email": "staff@example.com",
    "role": "STAFF",
    "status": "ACTIVE",
    "profile": {
      "fullName": "Trần Thị B",
      "phone": "0987654321",
      "avatar": "https://example.com/uploads/staff_avatar.jpg"
    },
    "facilityId": "507f1f77bcf86cd799439012",
    "facilityName": "Sân bóng Mỹ Đình",
    "createdAt": "2026-05-23T10:30:00Z",
    "updatedAt": "2026-05-23T10:30:00Z"
  }
}
```

> **Lưu ý trọng:** `auth.repository_impl.ts` (React) đọc: `profileResponse.data.user?.facilityId || profileResponse.data.user?.facilityName`. Tức là server có thể trả về `facilityId` hoặc `facilityName` hoặc cả hai.

**Response Error (404):**
```json
{
  "success": false,
  "message": "User not found",
  "code": "NOT_FOUND"
}
```

---

### `PUT /api/v1/user/:id`
**Service Dart:** `UserService.updateUser(id, data)`  
**Quyền hạn:** Bản thân hoặc ADMIN  
**Mô tả:** Cập nhật thông tin profile người dùng.

**Request Body:**
```json
{
  "profile": {
    "fullName": "Trần Thị B",
    "phone": "0987654321",
    "avatar": "https://example.com/uploads/new_avatar.jpg"
  },
  "facilityId": "507f1f77bcf86cd799439012"
}
```

| Field | Type | Required | Mô tả |
|-------|------|----------|-------|
| `profile.fullName` | string | ❌ | Tên đầy đủ |
| `profile.phone` | string | ❌ | Số điện thoại |
| `profile.avatar` | string (URL) | ❌ | URL ảnh avatar (từ Upload API) |
| `facilityId` | string (ObjectId) | ❌ | Chỉ ADMIN mới set được |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Profile updated successfully",
  "user": {
    "_id": "507f1f77bcf86cd799439013",
    "email": "staff@example.com",
    "profile": {
      "fullName": "Trần Thị B",
      "phone": "0987654321",
      "avatar": "https://example.com/uploads/new_avatar.jpg"
    },
    "updatedAt": "2026-05-28T08:00:00Z"
  }
}
```

---

### `PUT /api/v1/user/:id/role`
**Service Dart:** `UserService.updateUserRole(id, role)`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Thay đổi role của người dùng.

**Request Body:**
```json
{
  "role": "STAFF"
}
```

| Field | Type | Required | Giá trị hợp lệ |
|-------|------|----------|----------------|
| `role` | string | ✅ | `ADMIN`, `STAFF`, `CUSTOMER` |

**Response Success (200):**
```json
{
  "success": true,
  "message": "User role updated successfully",
  "code": "ROLE_UPDATED"
}
```

**Response Error (400):**
```json
{
  "success": false,
  "message": "Invalid role value",
  "code": "INVALID_STATUS"
}
```

---

### `PUT /api/v1/user/:id/status`
**Service Dart:** `UserService.updateUserStatus(id, status)`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Kích hoạt hoặc vô hiệu hoá tài khoản.

**Request Body:**
```json
{
  "status": "INACTIVE"
}
```

| Field | Type | Required | Giá trị hợp lệ |
|-------|------|----------|----------------|
| `status` | string | ✅ | `ACTIVE`, `INACTIVE` |

**Response Success (200):**
```json
{
  "success": true,
  "message": "User status updated successfully",
  "code": "STATUS_UPDATED"
}
```

---

### `POST /api/v1/user/:id/assign-facility`
**Service Dart:** `UserService.assignFacility(id, facilityId)`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Gán STAFF vào quản lý một Facility cụ thể.

**Request Body:**
```json
{
  "facilityId": "507f1f77bcf86cd799439012"
}
```

| Field | Type | Required |
|-------|------|----------|
| `facilityId` | string (ObjectId) | ✅ |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Facility assigned successfully",
  "code": "FACILITY_ASSIGNED"
}
```

**Response Error (404):**
```json
{
  "success": false,
  "message": "Facility not found",
  "code": "NOT_FOUND"
}
```

---

## III. Facility APIs

> **Yêu cầu:** `Authorization: Bearer <accessToken>`

---

### `GET /api/v1/facility/`
**Service Dart:** `FacilityService.getFacilities()`  
**Quyền hạn:** Authenticated (ADMIN/STAFF)  
**Mô tả:** Lấy danh sách tất cả cơ sở thể thao.

**Query Parameters (tùy chọn):**
| Param | Type | Mô tả |
|-------|------|-------|
| `skip` | number | Offset, default: 0 |
| `limit` | number | Page size, default: 10 |
| `name` | string | Tìm kiếm theo tên |
| `city` | string | Lọc theo thành phố |
| `active` | boolean | Lọc theo trạng thái |

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
      "description": "Khu liên hợp thể thao hiện đại",
      "ownerId": "507f1f77bcf86cd799439001",
      "staffIds": ["507f1f77bcf86cd799439013"],
      "active": true,
      "status": "ACTIVE",
      "createdAt": "2026-05-23T10:30:00Z"
    }
  ],
  "total": 5
}
```

**Mapping Dart `FacilityModel` → JSON:**
| Dart field | JSON key |
|-----------|---------|
| `id` | `_id` hoặc `id` |
| `name` | `name` |
| `address` | `address` / `fullAddress` |
| `description` | `description` |
| `ownerId` | `ownerId` |
| `status` | `status` |

---

### `POST /api/v1/facility/`
**Service Dart:** `FacilityService.createFacility(data)`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Tạo cơ sở thể thao mới.

**Request Body:**
```json
{
  "name": "Sân bóng Mỹ Đình",
  "city": "Hà Nội",
  "fullAddress": "P5, Mỹ Đình, Nam Từ Liêm, Hà Nội",
  "description": "Khu liên hợp thể thao hiện đại",
  "active": true,
  "staffIds": ["507f1f77bcf86cd799439013"]
}
```

| Field | Type | Required | Mô tả |
|-------|------|----------|-------|
| `name` | string | ✅ | Tên cơ sở |
| `city` | string | ✅ | Thành phố |
| `fullAddress` | string | ✅ | Địa chỉ đầy đủ |
| `description` | string | ❌ | Mô tả |
| `active` | boolean | ❌ | Mặc định: true |
| `staffIds` | string[] | ❌ | Danh sách Staff ID quản lý |

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
    "staffIds": ["507f1f77bcf86cd799439013"],
    "createdAt": "2026-05-28T11:00:00Z"
  }
}
```

---

### `PUT /api/v1/facility/:id`
**Service Dart:** `FacilityService.updateFacility(id, data)`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Cập nhật thông tin cơ sở.

**Path Parameter:** `:id` — Facility ID (ObjectId)

**Request Body:** Tương tự `POST /facility/` (các field muốn update)

**Response Success (200):**
```json
{
  "success": true,
  "message": "Facility updated successfully",
  "facility": {
    "_id": "507f1f77bcf86cd799439012",
    "name": "Sân bóng Mỹ Đình - Updated",
    "updatedAt": "2026-05-28T11:30:00Z"
  }
}
```

---

### `DELETE /api/v1/facility/:id`
**Service Dart:** `FacilityService.deleteFacility(id)`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Xóa cơ sở (soft delete hoặc hard delete tùy server).

**Response Success (200):**
```json
{
  "success": true,
  "message": "Facility deleted successfully",
  "code": "DELETE_SUCCESS"
}
```

**Response Error (404):**
```json
{
  "success": false,
  "message": "Facility not found",
  "code": "NOT_FOUND"
}
```

---

## IV. Court APIs

> **Yêu cầu:** `Authorization: Bearer <accessToken>`

---

### `GET /api/v1/court/`
**Service Dart:** `CourtService.getCourts()`  
**Quyền hạn:** Authenticated  
**Mô tả:** Lấy danh sách sân. Dùng để hiển thị danh sách sân cho customer đặt, hoặc admin/staff quản lý.

**Query Parameters (tùy chọn):**
| Param | Type | Mô tả |
|-------|------|-------|
| `skip` | number | Offset, default: 0 |
| `limit` | number | Page size, default: 10 |
| `facilityId` | string | Lọc theo facility |
| `sportId` | string | Lọc theo môn thể thao |
| `status` | string | Lọc theo trạng thái (`ACTIVE`/`INACTIVE`) |

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
  "total": 10
}
```

**Mapping Dart `CourtModel` → JSON:**
| Dart field | JSON key |
|-----------|---------|
| `id` | `_id` hoặc `id` |
| `facilityId` | `facilityId` |
| `sportId` | `sportId` |
| `name` | `name` |
| `status` | `status` |

---

### `POST /api/v1/court/`
**Service Dart:** `CourtService.createCourt(data)`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Tạo sân mới trong một facility.

**Request Body:**
```json
{
  "name": "Sân 1",
  "code": "COURT_001",
  "facilityId": "507f1f77bcf86cd799439012",
  "sportId": "507f1f77bcf86cd799439030",
  "status": "ACTIVE",
  "pricePerHour": 200000
}
```

| Field | Type | Required | Mô tả |
|-------|------|----------|-------|
| `name` | string | ✅ | Tên sân |
| `code` | string | ✅ | Mã sân (unique trong facility) |
| `facilityId` | string (ObjectId) | ✅ | ID cơ sở |
| `sportId` | string (ObjectId) | ✅ | ID môn thể thao |
| `status` | string | ❌ | Mặc định: `ACTIVE` |
| `pricePerHour` | number | ✅ | Giá thuê theo giờ (VND) |

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
    "createdAt": "2026-05-28T11:00:00Z"
  }
}
```

---

### `PUT /api/v1/court/:id`
**Service Dart:** `CourtService.updateCourt(id, data)`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Cập nhật thông tin sân (tên, giá, trạng thái...).

**Request Body:** Tương tự POST court (chỉ các field cần update)

**Response Success (200):**
```json
{
  "success": true,
  "message": "Court updated successfully",
  "court": {
    "_id": "507f1f77bcf86cd799439020",
    "name": "Sân 1 - Updated",
    "pricePerHour": 250000,
    "updatedAt": "2026-05-28T11:30:00Z"
  }
}
```

---

### `DELETE /api/v1/court/:id`
**Service Dart:** `CourtService.deleteCourt(id)`  
**Quyền hạn:** ADMIN only

**Response Success (200):**
```json
{
  "success": true,
  "message": "Court deleted successfully",
  "code": "DELETE_SUCCESS"
}
```

---

### `GET /api/v1/court/:id/slot-config`
**Service Dart:** `CourtService.getCourtSlotConfig(id)`  
**Quyền hạn:** Authenticated  
**Mô tả:** Lấy cấu hình khung giờ mở cửa/đóng cửa và các slot thời gian của sân. **Đây là API cốt lõi để hiển thị lịch đặt sân.**

**Path Parameter:** `:id` — Court ID

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
      },
      {
        "slotIndex": 3,
        "startMinutes": 540,
        "endMinutes": 600,
        "isAvailable": true
      }
    ]
  }
}
```

**Giải thích các field của `config`:**
| Field | Type | Mô tả |
|-------|------|-------|
| `openingMinutes` | number | Giờ mở cửa tính bằng phút từ 00:00. VD: 420 = 07:00 |
| `closingMinutes` | number | Giờ đóng cửa. VD: 1320 = 22:00 |
| `slotDurationMinutes` | number | Thời lượng mỗi slot (phút). VD: 60 = 1 tiếng |
| `slots[].slotIndex` | number | Thứ tự slot (bắt đầu từ 1) |
| `slots[].startMinutes` | number | Giờ bắt đầu slot |
| `slots[].endMinutes` | number | Giờ kết thúc slot |
| `slots[].isAvailable` | boolean | `true` = chưa đặt, `false` = đã đặt/không khả dụng |

> **Logic hiển thị tại client:**  
> - Slot `isAvailable: false` → hiển thị màu đỏ/xám + disabled.  
> - Slot `isAvailable: true` → hiển thị màu xanh + có thể click để đặt.  
> - Nếu `bookingDate` là hôm nay: ẩn/disabled các slot có `endMinutes < currentMinutesOfDay`.

---

### `PUT /api/v1/court/:id/slot-config`
**Service Dart:** `CourtService.updateCourtSlotConfig(id, data)`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Tạo mới hoặc cập nhật cấu hình slot của sân. Dùng khi admin cần đặt giờ hoạt động và chia slot.

**Request Body:**
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
    },
    {
      "slotIndex": 2,
      "startMinutes": 480,
      "endMinutes": 540,
      "isAvailable": true
    }
  ]
}
```

| Field | Type | Required | Constraint |
|-------|------|----------|------------|
| `openingMinutes` | number | ✅ | 0–1439 |
| `closingMinutes` | number | ✅ | > openingMinutes |
| `slotDurationMinutes` | number | ✅ | Thường là 30, 60, 90 |
| `slots` | array | ✅ | Danh sách slot |
| `slots[].slotIndex` | number | ✅ | Bắt đầu từ 1, tăng dần |
| `slots[].startMinutes` | number | ✅ | |
| `slots[].endMinutes` | number | ✅ | > startMinutes |
| `slots[].isAvailable` | boolean | ✅ | |

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
      { "slotIndex": 1, "startMinutes": 420, "endMinutes": 480, "isAvailable": true },
      { "slotIndex": 2, "startMinutes": 480, "endMinutes": 540, "isAvailable": true }
    ]
  }
}
```

---

## V. Sport APIs

> **Yêu cầu:** `Authorization: Bearer <accessToken>`

---

### `GET /api/v1/sport/`
**Service Dart:** `SportService.getSports()`  
**Quyền hạn:** Authenticated  
**Mô tả:** Lấy danh sách môn thể thao được hỗ trợ.

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sports retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439030",
      "name": "Bóng đá 5",
      "iconUrl": "https://example.com/icons/football.png",
      "description": "Bóng đá phòng, 5 người một bên",
      "teamSize": 5,
      "active": true,
      "createdAt": "2026-05-23T10:30:00Z"
    }
  ],
  "total": 5
}
```

**Mapping Dart `SportModel` → JSON:**
| Dart field | JSON key |
|-----------|---------|
| `id` | `_id` hoặc `id` |
| `name` | `name` |
| `iconUrl` | `iconUrl` |

---

### `POST /api/v1/sport/`
**Service Dart:** `SportService.createSport(data)`  
**Quyền hạn:** ADMIN only

**Request Body:**
```json
{
  "name": "Bóng đá 5",
  "iconUrl": "https://example.com/icons/football.png",
  "description": "Bóng đá phòng, 5 người một bên",
  "teamSize": 5,
  "active": true
}
```

| Field | Type | Required |
|-------|------|----------|
| `name` | string | ✅ |
| `iconUrl` | string (URL) | ❌ |
| `description` | string | ❌ |
| `teamSize` | number | ❌ |
| `active` | boolean | ❌ |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sport created successfully",
  "sport": {
    "_id": "507f1f77bcf86cd799439030",
    "name": "Bóng đá 5",
    "active": true,
    "createdAt": "2026-05-28T11:00:00Z"
  }
}
```

---

### `PUT /api/v1/sport/:id`
**Service Dart:** `SportService.updateSport(id, data)`  
**Quyền hạn:** ADMIN only

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sport updated successfully",
  "sport": {
    "_id": "507f1f77bcf86cd799439030",
    "name": "Bóng đá 5 - Updated",
    "updatedAt": "2026-05-28T11:30:00Z"
  }
}
```

---

### `DELETE /api/v1/sport/:id`
**Service Dart:** `SportService.deleteSport(id)`  
**Quyền hạn:** ADMIN only

**Response Success (200):**
```json
{
  "success": true,
  "message": "Sport deleted successfully",
  "code": "DELETE_SUCCESS"
}
```

---

## VI. Booking APIs

> **Yêu cầu:** `Authorization: Bearer <accessToken>`

---

### `GET /api/v1/booking/`
**Service Dart:** `BookingService.getBookings()`  
**Quyền hạn:** ADMIN/STAFF xem tất cả; CUSTOMER chỉ xem booking của mình  
**Mô tả:** Lấy danh sách tất cả lịch đặt sân.

**Query Parameters (tùy chọn):**
| Param | Type | Mô tả |
|-------|------|-------|
| `skip` | number | Offset |
| `limit` | number | Page size |
| `status` | string | `PENDING`, `CONFIRMED`, `COMPLETED`, `CANCELLED` |
| `bookingDate` | string | Định dạng `yyyy-MM-dd`, VD: `2026-06-15` |
| `courtId` | string | Lọc theo sân |
| `userId` | string | Lọc theo user (ADMIN/STAFF) |

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
      "createdAt": "2026-05-28T11:00:00Z"
    }
  ],
  "total": 50
}
```

**Mapping Dart `BookingModel` → JSON:**
| Dart field | JSON key | Ghi chú |
|-----------|---------|---------|
| `id` | `_id` hoặc `id` | |
| `userId` | `userId` | |
| `courtId` | `courtId` | |
| `startTime` | `startTime` (ISO 8601) | Model cũ dùng DateTime |
| `endTime` | `endTime` (ISO 8601) | Model cũ dùng DateTime |
| `status` | `status` | |
| `totalPrice` | `totalPrice` (number) | |

> **Lưu ý về `startMinutes`/`endMinutes` vs `startTime`/`endTime`:**  
> `BookingModel.dart` (server_module) hiện dùng `startTime`/`endTime` (DateTime). Tuy nhiên `json-in-out_single_line.txt` và React datasource dùng `startMinutes`/`endMinutes` (số nguyên). Backend cần support cả hai hoặc chỉ dùng một format nhất quán. **Khuyến nghị: dùng `startMinutes`/`endMinutes` + `bookingDate`.**

---

### `GET /api/v1/booking/:id`
**Service Dart:** `BookingService.getBookingById(id)`  
**Quyền hạn:** Authenticated (bản thân hoặc ADMIN/STAFF)  
**Mô tả:** Lấy chi tiết booking, bao gồm thông tin user và court được populate.

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
      "email": "customer@example.com",
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
    "createdAt": "2026-05-28T11:00:00Z"
  }
}
```

---

### `POST /api/v1/booking/`
**Service Dart:** `BookingService.createBooking(data)`  
**Quyền hạn:** Authenticated (CUSTOMER tự đặt, STAFF đặt hộ cho customer)  
**Mô tả:** Tạo lịch đặt sân mới. Server tự lấy `userId` từ access token. Staff đặt hộ phải truyền `userId` của customer.

**Request Body:**
```json
{
  "courtId": "507f1f77bcf86cd799439020",
  "bookingDate": "2026-06-15",
  "startMinutes": 420,
  "endMinutes": 480,
  "totalPrice": 200000,
  "userId": "507f1f77bcf86cd799439011"
}
```

| Field | Type | Required | Constraint |
|-------|------|----------|------------|
| `courtId` | string (ObjectId) | ✅ | Court phải có status `ACTIVE` |
| `bookingDate` | string | ✅ | Định dạng `yyyy-MM-dd`, không được là ngày quá khứ |
| `startMinutes` | number | ✅ | Trong khoảng `openingMinutes`–`closingMinutes` của slot config |
| `endMinutes` | number | ✅ | > `startMinutes`, bội số của `slotDurationMinutes` |
| `totalPrice` | number | ✅ | Phải khớp: `(endMinutes - startMinutes) / 60 * pricePerHour` |
| `userId` | string | ❌ | Chỉ ADMIN/STAFF mới được set. Nếu bỏ trống → server dùng userId từ token |

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
    "createdAt": "2026-05-28T11:00:00Z"
  }
}
```

**Response Error — Slot đã bị đặt (409):**
```json
{
  "success": false,
  "message": "This time slot is already booked",
  "code": "CONFLICTED_SLOT"
}
```

**Response Error — Thiếu field (400):**
```json
{
  "success": false,
  "message": "courtId, bookingDate, startMinutes, endMinutes and totalPrice are required",
  "code": "MISSING_FIELDS"
}
```

---

### `PUT /api/v1/booking/:id/status`
**Service Dart:** `BookingService.updateBookingStatus(id, status)`  
**Quyền hạn:** ADMIN/STAFF only  
**Mô tả:** Cập nhật trạng thái booking. Dùng khi staff xác nhận hoặc hủy đơn.

**Request Body:**
```json
{
  "status": "CONFIRMED"
}
```

| Field | Type | Required | Giá trị hợp lệ |
|-------|------|----------|----------------|
| `status` | string | ✅ | `PENDING`, `CONFIRMED`, `COMPLETED`, `CANCELLED` |

**Trạng thái hợp lệ theo luồng:**
```
PENDING → CONFIRMED → COMPLETED
PENDING → CANCELLED
CONFIRMED → CANCELLED (hoàn tiền cần xử lý thủ công)
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Booking status updated successfully",
  "booking": {
    "_id": "507f1f77bcf86cd799439040",
    "status": "CONFIRMED",
    "updatedAt": "2026-05-28T11:30:00Z"
  }
}
```

---

## VII. Payment APIs

> **Yêu cầu:** `Authorization: Bearer <accessToken>`

---

### `GET /api/v1/payment/`
**Service Dart:** `PaymentService.getPayments()`  
**Quyền hạn:** ADMIN/STAFF xem tất cả; CUSTOMER chỉ xem payment của mình  
**Mô tả:** Lấy danh sách thanh toán.

**Query Parameters (tùy chọn):**
| Param | Type | Mô tả |
|-------|------|-------|
| `skip` | number | Offset |
| `limit` | number | Page size |
| `status` | string | `PENDING`, `SUCCESS`, `FAILED` |
| `bookingId` | string | Lọc theo booking |

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
      "method": "CASH",
      "transactionId": "TXN_001_001_2026",
      "status": "PENDING",
      "createdAt": "2026-05-28T11:00:00Z"
    }
  ],
  "total": 25
}
```

**Mapping Dart `PaymentModel` → JSON:**
| Dart field | JSON key |
|-----------|---------|
| `id` | `_id` hoặc `id` |
| `bookingId` | `bookingId` |
| `amount` | `amount` (number/double) |
| `method` | `method` |
| `status` | `status` |

---

### `POST /api/v1/payment/`
**Service Dart:** `PaymentService.createPayment(data)`  
**Quyền hạn:** Authenticated (STAFF tạo payment khi thu tiền mặt)  
**Mô tả:** Tạo record thanh toán mới. Thường được gọi ngay sau khi booking được CONFIRMED.

**Request Body:**
```json
{
  "bookingId": "507f1f77bcf86cd799439040",
  "amount": 200000,
  "method": "CASH",
  "transactionId": "TXN_20260615_001"
}
```

| Field | Type | Required | Mô tả |
|-------|------|----------|-------|
| `bookingId` | string (ObjectId) | ✅ | Booking liên kết |
| `amount` | number | ✅ | Số tiền thanh toán (VND) |
| `method` | string | ✅ | `CASH`, `BANK_TRANSFER`, `MOMO`, `VNPAY` |
| `transactionId` | string | ❌ | Mã giao dịch (bắt buộc với BANK_TRANSFER/MOMO/VNPAY) |

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
    "method": "CASH",
    "transactionId": "TXN_20260615_001",
    "status": "PENDING",
    "createdAt": "2026-05-28T11:00:00Z"
  }
}
```

---

### `PUT /api/v1/payment/:id/status`
**Service Dart:** `PaymentService.updatePaymentStatus(id, status)`  
**Quyền hạn:** ADMIN/STAFF only  
**Mô tả:** Xác nhận hoặc từ chối thanh toán. Sau khi staff nhận tiền mặt → set `SUCCESS`.

**Request Body:**
```json
{
  "status": "SUCCESS",
  "transactionId": "TXN_20260615_001_CONFIRMED"
}
```

| Field | Type | Required | Giá trị hợp lệ |
|-------|------|----------|----------------|
| `status` | string | ✅ | `PENDING`, `SUCCESS`, `FAILED` |
| `transactionId` | string | ❌ | Cập nhật mã giao dịch nếu cần |

**Luồng trạng thái Payment:**
```
PENDING → SUCCESS (Staff xác nhận đã nhận tiền)
PENDING → FAILED  (Huỷ/từ chối)
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Payment status updated successfully",
  "payment": {
    "_id": "507f1f77bcf86cd799439050",
    "status": "SUCCESS",
    "updatedAt": "2026-05-28T11:30:00Z"
  }
}
```

---

## VIII. Review APIs

> **Yêu cầu:** `Authorization: Bearer <accessToken>`

---

### `GET /api/v1/review/`
**Service Dart:** `ReviewService.getReviews()`  
**Quyền hạn:** Authenticated  
**Mô tả:** Lấy danh sách đánh giá sân.

**Query Parameters (tùy chọn):**
| Param | Type | Mô tả |
|-------|------|-------|
| `skip` | number | Offset |
| `limit` | number | Page size |
| `courtId` | string | Lọc theo sân |
| `rating` | number | Lọc theo điểm đánh giá (1-5) |

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
      "facilityId": "507f1f77bcf86cd799439012",
      "courtId": "507f1f77bcf86cd799439020",
      "rating": 5,
      "comment": "Sân rất sạch, nhân viên thân thiện. Rất thích!",
      "createdAt": "2026-05-28T11:00:00Z"
    }
  ],
  "total": 30
}
```

**Mapping Dart `ReviewModel` → JSON:**
| Dart field | JSON key |
|-----------|---------|
| `id` | `_id` hoặc `id` |
| `userId` | `userId` |
| `facilityId` | `facilityId` |
| `rating` | `rating` (int, 1–5) |
| `comment` | `comment` |

---

### `POST /api/v1/review/`
**Service Dart:** `ReviewService.createReview(data)`  
**Quyền hạn:** CUSTOMER (chỉ được review sau khi booking COMPLETED)

**Request Body:**
```json
{
  "courtId": "507f1f77bcf86cd799439020",
  "rating": 5,
  "comment": "Sân rất sạch, nhân viên thân thiện. Rất thích!"
}
```

| Field | Type | Required | Constraint |
|-------|------|----------|------------|
| `courtId` | string (ObjectId) | ✅ | |
| `rating` | number | ✅ | Integer từ 1 đến 5 |
| `comment` | string | ❌ | Max 500 ký tự |

**Response Error (400) — Rating ngoài khoảng:**
```json
{
  "success": false,
  "message": "Rating must be between 1 and 5",
  "code": "INVALID_RATING"
}
```

---

### `DELETE /api/v1/review/:id`
**Service Dart:** `ReviewService.deleteReview(id)`  
**Quyền hạn:** ADMIN only

**Response Success (200):**
```json
{
  "success": true,
  "message": "Review deleted successfully",
  "code": "DELETE_SUCCESS"
}
```

---

## IX. Notification APIs

> **Yêu cầu:** `Authorization: Bearer <accessToken>`

---

### `GET /api/v1/notification/`
**Service Dart:** `NotificationService.getNotifications()`  
**Quyền hạn:** Authenticated  
**Mô tả:** Lấy thông báo của người dùng hiện tại (server lọc theo token).

**Response Success (200):**
```json
{
  "success": true,
  "message": "Notifications retrieved successfully",
  "items": [
    {
      "_id": "507f1f77bcf86cd799439070",
      "userId": "507f1f77bcf86cd799439013",
      "title": "Booking Confirmed",
      "content": "Booking #40 for Sân 1 on 2026-06-15 07:00-08:00 has been confirmed",
      "isRead": false,
      "createdAt": "2026-05-28T11:00:00Z"
    }
  ],
  "total": 10,
  "unreadCount": 3
}
```

**Mapping Dart `NotificationModel` → JSON:**
| Dart field | JSON key |
|-----------|---------|
| `id` | `_id` hoặc `id` |
| `userId` | `userId` |
| `title` | `title` |
| `content` | `content` |
| `isRead` | `isRead` (bool, default: false) |
| `createdAt` | `createdAt` (ISO 8601) |

---

### `POST /api/v1/notification/`
**Service Dart:** `NotificationService.createNotification(data)`  
**Quyền hạn:** ADMIN only  
**Mô tả:** Gửi thông báo tới một user.

**Request Body:**
```json
{
  "userId": "507f1f77bcf86cd799439011",
  "title": "Booking Reminder",
  "content": "Bạn có lịch đặt sân vào ngày mai lúc 07:00",
  "type": "BOOKING"
}
```

| Field | Type | Required | Giá trị hợp lệ |
|-------|------|----------|----------------|
| `userId` | string | ✅ | |
| `title` | string | ✅ | |
| `content` | string | ✅ | |
| `type` | string | ❌ | `BOOKING`, `PAYMENT`, `SYSTEM` |

---

### `PUT /api/v1/notification/:id/read`
**Service Dart:** `NotificationService.markAsRead(id)`  
**Quyền hạn:** Authenticated  
**Mô tả:** Đánh dấu một thông báo là đã đọc.

**Response Success (200):**
```json
{
  "success": true,
  "message": "Notification marked as read",
  "notification": {
    "_id": "507f1f77bcf86cd799439070",
    "isRead": true,
    "updatedAt": "2026-05-28T11:30:00Z"
  }
}
```

---

### `PUT /api/v1/notification/mark-all-read`
**Service Dart:** `NotificationService.markAllAsRead()`  
**Quyền hạn:** Authenticated  
**Mô tả:** Đánh dấu tất cả thông báo của user hiện tại là đã đọc.

**Response Success (200):**
```json
{
  "success": true,
  "message": "All notifications marked as read",
  "code": "MARK_ALL_SUCCESS"
}
```

---

## X. Upload APIs

> **Yêu cầu:**  
> - `Authorization: Bearer <accessToken>`  
> - `Content-Type: multipart/form-data`

---

### `POST /api/v1/upload/single`
**Service Dart:** `UploadService.uploadSingle(formData)`  
**Quyền hạn:** Authenticated  
**Mô tả:** Upload một ảnh. Dùng để upload avatar, ảnh sân, ảnh facility.

**Request:** `FormData` với field `file`
```
Content-Type: multipart/form-data
Body:
  file: <binary file>
```

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
    "uploadedAt": "2026-05-28T11:00:00Z"
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

> **Quy trình upload avatar:** Upload → lấy `data.url` → gọi `PUT /user/:id` với `profile.avatar = data.url`

---

### `POST /api/v1/upload/multiple`
**Service Dart:** `UploadService.uploadMultiple(formData)`  
**Quyền hạn:** Authenticated  
**Mô tả:** Upload nhiều ảnh cùng lúc. Dùng để upload ảnh gallery facility/court.

**Request:** `FormData` với field `files` (multiple)

**Response Success (200):**
```json
{
  "success": true,
  "message": "Tải các ảnh lên thành công",
  "data": [
    {
      "id": "507f1f77bcf86cd799439080",
      "filename": "img_1716455400123.jpg",
      "url": "https://example.com/uploads/img_1716455400123.jpg",
      "uploadedAt": "2026-05-28T11:00:00Z"
    }
  ]
}
```

---

## XI. Content APIs

> **Yêu cầu:** `Authorization: Bearer <accessToken>`

---

### `GET /api/v1/emoji`
**Service Dart:** `ContentService.getEmojis(queryParams)`  
**Quyền hạn:** Authenticated

**Response Success (200):**
```json
{
  "success": true,
  "items": [
    {
      "_id": "507f1f77bcf86cd799439090",
      "code": "THUMBS_UP",
      "unicode": "👍",
      "name": "Thumbs Up",
      "status": "ACTIVE"
    }
  ]
}
```

---

### `GET /api/v1/helpdesk`
**Service Dart:** `ContentService.getHelpdesks(queryParams)`  
**Quyền hạn:** Authenticated  
**Mô tả:** Lấy danh sách nội dung FAQ/Helpdesk.

**Response Success (200):**
```json
{
  "success": true,
  "items": [
    {
      "_id": "507f1f77bcf86cd799439091",
      "title": "Cách đặt sân",
      "content": "Để đặt sân, hãy làm theo các bước sau...",
      "status": "ACTIVE"
    }
  ]
}
```

---

## XII. Luồng Nghiệp vụ Đặc biệt

### Luồng 1: Staff đặt sân hộ customer
```
1. Staff tìm kiếm customer → GET /user/?role=CUSTOMER&name=...
2. Chọn sân → GET /court/?facilityId=...
3. Chọn ngày → GET /court/:id/slot-config (lấy slots, filter isAvailable=true)
4. Tạo booking hộ:
   POST /booking/ { courtId, bookingDate, startMinutes, endMinutes, totalPrice, userId: <customerId> }
5. Xác nhận booking:
   PUT /booking/:id/status { status: "CONFIRMED" }
6. Tạo payment (thu tiền mặt):
   POST /payment/ { bookingId, amount, method: "CASH" }
7. Xác nhận đã nhận tiền:
   PUT /payment/:id/status { status: "SUCCESS" }
```

### Luồng 2: Admin quản lý slot config sân
```
1. Lấy danh sách sân → GET /court/?facilityId=...
2. Xem config hiện tại → GET /court/:id/slot-config
3. Cập nhật giờ hoạt động:
   PUT /court/:id/slot-config {
     openingMinutes: 420,   // 07:00
     closingMinutes: 1320,  // 22:00
     slotDurationMinutes: 60,
     slots: [...]
   }
```

### Luồng 3: Token Refresh (tự động trong interceptor)
```
1. Gọi bất kỳ API → nhận 401 TOKEN_EXPIRED
2. POST /auth/refresh-token { refreshToken }
3a. Thành công → cập nhật accessToken mới → retry request gốc
3b. Thất bại (REFRESH_FAILED) → logout → redirect về trang login
```

### Luồng 4: Đăng nhập CRM (sign-in + fetch profile)
```
1. POST /auth/sign-in { email, password }
2. Kiểm tra role ở client:
   - role === "ADMIN" hoặc role === "STAFF" → tiếp tục
   - role === "CUSTOMER" → hiển thị lỗi, clear token
3. GET /user/:userId (userId từ response sign-in)
4. Lấy facilityId/facilityName từ user profile → lưu vào store
5. Redirect vào dashboard tương ứng với role
```

### Luồng 5: Lọc slot theo thời gian thực (hôm nay)
```
1. GET /court/:id/slot-config
2. Nếu bookingDate === hôm nay:
   - Tính currentMinutes = currentHour * 60 + currentMinute
   - Filter: slots.where((s) => s.endMinutes > currentMinutes && s.isAvailable)
   - Các slot đã qua (endMinutes <= currentMinutes) → hidden hoặc disabled
3. Nếu bookingDate > hôm nay:
   - Filter: slots.where((s) => s.isAvailable)
```

---

## Health Check

### `GET /api/v1/health`
**Quyền hạn:** Public  
**Mô tả:** Kiểm tra server đang hoạt động.

**Response Success (200):**
```json
{
  "success": true,
  "message": "API is running",
  "code": "OK"
}
```

---

## 📌 Bảng Tóm tắt Tất cả Endpoints

| Method | Endpoint | Role | Mô tả |
|--------|----------|------|-------|
| POST | `/auth/register` | Public | Đăng ký |
| POST | `/auth/sign-in` | Public | Đăng nhập |
| POST | `/auth/refresh-token` | Public | Refresh token |
| POST | `/auth/sign-out` | Auth | Đăng xuất |
| POST | `/auth/reset-password` | Public | Reset mật khẩu |
| GET | `/user/` | ADMIN | Danh sách user |
| GET | `/user/:id` | Auth | Chi tiết user |
| PUT | `/user/:id` | Auth | Cập nhật profile |
| PUT | `/user/:id/role` | ADMIN | Đổi role |
| PUT | `/user/:id/status` | ADMIN | Đổi status |
| POST | `/user/:id/assign-facility` | ADMIN | Gán facility |
| GET | `/facility/` | Auth | Danh sách facility |
| POST | `/facility/` | ADMIN | Tạo facility |
| PUT | `/facility/:id` | ADMIN | Sửa facility |
| DELETE | `/facility/:id` | ADMIN | Xóa facility |
| GET | `/court/` | Auth | Danh sách sân |
| POST | `/court/` | ADMIN | Tạo sân |
| PUT | `/court/:id` | ADMIN | Sửa sân |
| DELETE | `/court/:id` | ADMIN | Xóa sân |
| GET | `/court/:id/slot-config` | Auth | Cấu hình slot |
| PUT | `/court/:id/slot-config` | ADMIN | Cập nhật slot |
| GET | `/sport/` | Auth | Danh sách môn |
| POST | `/sport/` | ADMIN | Tạo môn |
| PUT | `/sport/:id` | ADMIN | Sửa môn |
| DELETE | `/sport/:id` | ADMIN | Xóa môn |
| GET | `/booking/` | ADMIN/STAFF | Danh sách booking |
| GET | `/booking/:id` | Auth | Chi tiết booking |
| POST | `/booking/` | Auth | Tạo booking |
| PUT | `/booking/:id/status` | ADMIN/STAFF | Đổi status booking |
| GET | `/payment/` | ADMIN/STAFF | Danh sách payment |
| POST | `/payment/` | Auth | Tạo payment |
| PUT | `/payment/:id/status` | ADMIN/STAFF | Xác nhận payment |
| GET | `/review/` | Auth | Danh sách review |
| POST | `/review/` | CUSTOMER | Tạo review |
| DELETE | `/review/:id` | ADMIN | Xóa review |
| GET | `/notification/` | Auth | Thông báo |
| POST | `/notification/` | ADMIN | Gửi thông báo |
| PUT | `/notification/:id/read` | Auth | Đánh dấu đã đọc |
| PUT | `/notification/mark-all-read` | Auth | Đánh dấu tất cả |
| POST | `/upload/single` | Auth | Upload 1 ảnh |
| POST | `/upload/multiple` | Auth | Upload nhiều ảnh |
| GET | `/emoji` | Auth | Danh sách emoji |
| GET | `/helpdesk` | Auth | Nội dung helpdesk |
| GET | `/health` | Public | Health check |

---

*Tài liệu này được trích xuất từ source code Flutter `server_module` (Dart/Dio) — phiên bản 2026-05-28*
