# 🖥️ CRM Web Specification: Admin & Staff Portal
## DỰ ÁN: HỆ THỐNG QUẢN LÝ KHU LIÊN HỢP THỂ THAO (SPORT ENERGY)
**Mục đích:** Tài liệu đặc tả chức năng, luồng giao diện (UX/UI), cấu trúc thư mục Clean Architecture, cấu hình Design Tokens (Theme) và tích hợp API để phát triển Website CRM bằng **ReactJS** dành cho **Admin** và **Staff**, đồng bộ 100% nghiệp vụ & thiết kế với phiên bản Mobile hiện tại.

---

## 1. 🏗️ Tổ chức Dự án theo Kiến trúc Clean Architecture (ReactJS - TS)
Để đảm bảo dự án web CRM dễ bảo trì, dễ mở rộng và đồng bộ kiến trúc với dự án Mobile Flutter, cấu trúc mã nguồn ReactJS sẽ được tổ chức theo mô hình **Strict Clean Architecture** chia theo **Features** (Phân hệ).

### 1.1. Sơ đồ Cấu trúc Thư mục Tổng quan (`/src`)
```text
src/
├── core/                       # Lớp cốt lõi dùng chung (không chứa business logic của feature)
│   ├── components/             # UI Components dùng chung (Button, Input, Table, Modal, Toast)
│   ├── theme/                  # Cấu hình màu sắc, typography (Light/Dark Mode, TailwindConfig)
│   ├── network/                # Axios Client, HTTP Interceptors (JWT Token & Auto-Refresh)
│   ├── routes/                 # Cấu hình React Router (Route Guards phân quyền Admin/Staff)
│   ├── errors/                 # Định nghĩa các lớp lỗi hệ thống (Failure, ServerError)
│   └── utils/                  # Các hàm tiện ích dùng chung (Format currency, Format date)
│
├── features/                   # Thư mục chứa các phân hệ nghiệp vụ chính
│   ├── auth/                   # Phân hệ Authentication (Đăng nhập, Reset Password)
│   ├── booking/                # Phân hệ Đặt sân (Danh sách ca đặt, Đặt lịch quầy, Duyệt lịch)
│   ├── facility/               # Phân hệ Cơ sở & Sân bãi (Quản lý sân, Môn thể thao, Cấu hình Slot)
│   ├── payment/                # Phân hệ Hóa đơn & Thu ngân (Cashier)
│   ├── user_management/        # Phân hệ Quản trị thành viên (User list, Gán vai trò, Gán cơ sở)
│   └── report/                 # Phân hệ Báo cáo thống kê
│
├── App.tsx                     # Entry point của ứng dụng
└── main.tsx                    # React DOM Render & Global Providers
```

---

### 1.2. Cấu trúc một Phân hệ Nghiệp vụ (`features/feature_name/`)
Mỗi feature BẮT BUỘC phải chia làm 3 lớp riêng biệt: **Domain**, **Data**, và **Presentation**.

```text
features/booking/
├── domain/                     # LỚP NGHIỆP VỤ (Pure JS/TS - Tuyệt đối không import React hoặc Hook)
│   ├── entities/               # Định nghĩa Model dữ liệu dạng TypeScript Interface/Type
│   │   ├── booking.entity.ts
│   │   └── slot.entity.ts
│   ├── repositories/           # Định nghĩa Interface (hợp đồng giao tiếp) của Repository
│   │   └── booking.repository.ts
│   └── usecases/               # Các nghiệp vụ đơn nhiệm (Single responsibility)
│       ├── create_booking.usecase.ts
│       ├── get_court_slots.usecase.ts
│       └── confirm_booking_status.usecase.ts
│
├── data/                       # LỚP DỮ LIỆU (Gọi API, Parse dữ liệu, Xử lý JSON)
│   ├── datasources/            # Các cuộc gọi HTTP API trực tiếp sử dụng Axios
│   │   └── booking.remote_datasource.ts
│   ├── models/                 # Chứa Data Transfer Objects (DTO) và hàm mappers từ JSON sang Entity
│   │   └── booking.model.ts
│   └── repositories/           # Hiện thực (Implementation) cụ thể của Repository từ Domain
│       └── booking.repository_impl.ts
│
└── presentation/               # LỚP GIAO DIỆN (React UI & Quản lý State UI)
    ├── hooks/                  # Custom React Hooks hoặc React Query (thay thế Bloc/Cubit)
    │   ├── use_booking_list.ts
    │   └── use_create_booking.ts
    ├── components/             # Sub-components dùng riêng cho phân hệ này
    │   ├── walkin_booking_dialog.tsx
    │   └── booking_row_item.tsx
    └── pages/                  # Các màn hình chính (Dựng layout)
        └── booking_list_page.tsx
```

#### Quy tắc phụ thuộc (Dependency Rule) trên ReactJS:
*   **Presentation** và **Data** được phụ thuộc vào **Domain**.
*   **Domain** là trung tâm nghiệp vụ: **Không** import React, **Không** dùng Hooks (`useState`, `useEffect`), **Không** gọi trực tiếp Axios. Mọi tương tác dữ liệu phải thông qua Repository Interface.

---

## 2. 🎨 Đặc tả Thiết kế & Design Tokens (Đồng bộ 100% Mobile Theme)

Để đảm bảo Website có giao diện nhất quán với ứng dụng Mobile, lập trình viên Frontend cần sử dụng chính xác hệ thống Token thiết kế sau:

### 2.1. Bảng màu hệ thống (Colors)

| Tên Màu (Flutter Token) | Mã Hex Light Mode | Mã Hex Dark Mode | Vai trò sử dụng |
| :--- | :--- | :--- | :--- |
| **Primary (Ink)** | `#111111` | `#FFFFFF` | Chữ chính, tiêu đề, nút bấm chính. |
| **Canvas (Background)** | `#F5F1EC` | `#121212` | Màu nền của trang (Scaffold Background). |
| **Surface 1** | `#FFFFFF` | `#1E1E1E` | Màu nền của Card, Input, Modal, Dropdown. |
| **Surface 2** | `#EDE9E3` | `#2C2C2C` | Màu nền của Chips, phân vùng phụ. |
| **Accent (finOrange)** | `#FF5600` | `#FF5600` | Màu cam thương hiệu (Nút bấm nổi bật, Active states). |
| **Muted Ink (inkMuted)** | `#626260` | `#9E9E9E` | Chữ phụ, icon phụ, nhãn miêu tả. |
| **Subtle Ink (inkSubtle)** | `#7B7B78` | `#BDBDBD` | Văn bản bổ sung, placeholder. |
| **Hairline (Border)** | `#D3CEC6` | `#2C2C2C` | Đường viền ngăn cách nhẹ, border của Card/Table. |
| **Hairline Soft** | `#E3DED7` | `#2C2C2C` | Divider thanh mảnh. |
| **Success (semanticSuccess)** | `#1E8A44` | `#30D158` | Trạng thái đặt thành công, slot còn trống. |
| **Error (semanticError)** | `#D93025` | `#D93025` | Trạng thái lỗi, slot không khả dụng. |
| **Warning (semanticWarning)**| `#F59E0B` | `#F59E0B` | Trạng thái chờ, cảnh báo. |

---

### 2.2. Quy chuẩn Typography (Font chữ mặc định: `Inter`)
Tất cả font chữ trên web CRM sử dụng font **Inter** được thừa hưởng các cấu hình tỷ lệ chiều cao (line-height) và khoảng cách chữ (letter-spacing) như sau:

*   **Display XL:** `font-size: 72px`, `font-weight: 500`, `line-height: 1.05`, `letter-spacing: -2px`
*   **Display LG:** `font-size: 56px`, `font-weight: 500`, `line-height: 1.10`, `letter-spacing: -1.4px`
*   **Display MD:** `font-size: 40px`, `font-weight: 500`, `line-height: 1.15`, `letter-spacing: -0.8px`
*   **Headline:** `font-size: 28px`, `font-weight: 500`, `line-height: 1.20`, `letter-spacing: -0.5px`
*   **Card Title / Table Header:** `font-size: 22px`, `font-weight: 500`, `line-height: 1.25`, `letter-spacing: -0.3px`
*   **Subhead:** `font-size: 20px`, `font-weight: 400`, `line-height: 1.40`, `letter-spacing: -0.2px`
*   **Body Large:** `font-size: 18px`, `font-weight: 400`, `line-height: 1.50`, `letter-spacing: -0.1px`
*   **Body Medium (Mặc định):** `font-size: 16px`, `font-weight: 400`, `line-height: 1.50`
*   **Body Small:** `font-size: 14px`, `font-weight: 400`, `line-height: 1.50`
*   **Button Text:** `font-size: 15px`, `font-weight: 500`, `line-height: 1.20`
*   **Caption:** `font-size: 12px`, `font-weight: 400`, `line-height: 1.40`

---

### 2.3. Quy chuẩn Khoảng cách (Spacing) & Bo góc (Radius)
*   **Radius (Bo góc):**
    *   `xs`: 4px | `sm`: 6px | `md`: 8px (Border radius của Input, Button nhỏ).
    *   `lg`: 12px (Border radius của Sân Card, Table Row).
    *   `xl`: 16px (Border radius của Card chính, Slot Card, Modal).
    *   `xxl`: 24px (Border radius của Banner chào mừng).
    *   `pill`: 9999px (Tròn trịa cho Badge, User Avatar).
*   **Spacing (Khoảng cách căn lề):**
    *   `xxs`: 4px | `xs`: 8px | `sm`: 12px | `md`: 16px | `lg`: 24px | `xl`: 32px | `xxl`: 48px
    *   *Padding của Nút bấm:* Trên-Dưới: 10px, Trái-Phải: 18px.
    *   *Padding của Thẻ Card/Bảng:* 24px.

---

### 2.4. File cấu hình mẫu Tailwind CSS (`tailwind.config.js`)
Lập trình viên Frontend có thể sao chép trực tiếp cấu hình này vào dự án ReactJS:

```javascript
module.exports = {
  darkMode: 'class', // Hỗ trợ chuyển đổi Light/Dark mode qua class 'dark' ở thẻ html
  theme: {
    extend: {
      colors: {
        canvas: {
          DEFAULT: '#F5F1EC',
          dark: '#121212',
        },
        surface: {
          1: '#FFFFFF',
          2: '#EDE9E3',
          dark1: '#1E1E1E',
          dark2: '#2C2C2C',
        },
        ink: {
          DEFAULT: '#111111',
          muted: '#626260',
          subtle: '#7B7B78',
          tertiary: '#9C9FA5',
          darkMuted: '#9E9E9E',
          darkSubtle: '#BDBDBD',
        },
        brand: {
          orange: '#FF5600',
        },
        semantic: {
          success: '#1E8A44',
          successDark: '#30D158',
          error: '#D93025',
          warning: '#F59E0B',
          border: '#D3CEC6',
          borderDark: '#2C2C2C',
        }
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      borderRadius: {
        'xs': '4px',
        'sm': '6px',
        'md': '8px',
        'lg': '12px',
        'xl': '16px',
        'xxl': '24px',
      },
      spacing: {
        'button-v': '10px',
        'button-h': '18px',
        'card-p': '24px',
      }
    },
  },
  plugins: [],
}
```

---

### 2.5. Cấu hình Theme Ant Design (React `ConfigProvider` Theme Config)
Nếu đội Frontend sử dụng Ant Design (v5+), cấu hình token sau sẽ map khớp giao diện:

```typescript
import { ThemeConfig } from 'antd';

export const getAntdTheme = (isDarkMode: boolean): ThemeConfig => ({
  token: {
    fontFamily: 'Inter, sans-serif',
    colorPrimary: '#FF5600', // finOrange accent
    colorBgLayout: isDarkMode ? '#121212' : '#F5F1EC', // Canvas
    colorBgContainer: isDarkMode ? '#1E1E1E' : '#FFFFFF', // Surface 1
    colorText: isDarkMode ? '#FFFFFF' : '#111111', // Ink
    colorTextDescription: isDarkMode ? '#9E9E9E' : '#626260', // Ink Muted
    colorBorder: isDarkMode ? '#2C2C2C' : '#D3CEC6', // Hairline
    borderRadius: 8, // md
  },
  components: {
    Button: {
      controlHeight: 40,
      paddingContentHorizontal: 18,
      borderRadius: 8,
      colorBgContainer: isDarkMode ? '#1E1E1E' : '#FFFFFF',
    },
    Card: {
      borderRadiusLG: 16, // xl
      colorBorderSecondary: isDarkMode ? '#2C2C2C' : '#EDE9E3',
    },
    Table: {
      borderRadius: 12, // lg
      colorBgHeader: isDarkMode ? '#2C2C2C' : '#EDE9E3',
    }
  }
});
```

---

## 3. 🛠️ Tech Stack & Kiến trúc khuyến nghị cho Frontend Web
*   **Thư viện UI chính:** **Ant Design** (khuyên dùng cho hệ thống CRM/Dashboard quản trị vì hỗ trợ Grid, Table, Modal mạnh mẽ) hoặc **Shadcn UI** kết hợp **TailwindCSS**.
*   **Quản lý State:** React Query (TanStack Query) để quản lý cache API và đồng bộ hóa trạng thái server.
*   **Routing:** React Router v6 (Hỗ trợ Nested Routes và Route Guards phân quyền).
*   **Quản lý HTTP:** Axios (hỗ trợ interceptors tự động đính kèm JWT Token và refresh token).
*   **Biểu đồ thống kê:** Recharts hoặc Chart.js.

---

## 4. 🔐 Hệ thống Xác thực & Quản lý Token (Authentication)
Website CRM kế thừa cơ chế xác thực tập trung từ Backend JWT:
*   **Bộ lưu trữ:** Access Token và Refresh Token lưu trong `localStorage` hoặc `HTTP-only Cookie`.
*   **Cơ chế Auto-Refresh:**
    *   Hệ thống thiết lập một background timer hoặc dùng Axios Interceptor bắt mã lỗi `401`.
    *   If Access Token gần hết hạn (dưới 1 tiếng) hoặc trả về `401`, gọi API `POST /api/v1/auth/refresh-token` để lấy cặp token mới.
    *   If Refresh Token hết hạn (7 ngày), tự động xóa bộ nhớ, hiển thị thông báo Popup và chuyển hướng về trang `/sign-in`.
*   **Phân vai trò (Role-based Route Guards):**
    *   `/sign-in`: Public Route.
    *   `/admin/*`: Private Route chỉ dành cho vai trò `ADMIN`.
    *   `/staff/*`: Private Route dành cho vai trò `STAFF` (và `ADMIN` nếu muốn truy cập).
    *   Nếu cố tình vào route sai phân quyền, redirect sang trang `/403-forbidden`.

---

## 5. 🗺️ Sơ đồ Định tuyến & Bố cục Trang (Routing & Layouts)

### Bố cục cơ bản (Main Layout):
*   **Sidebar (Thanh điều hướng trái):** Logo hệ thống, menu các tính năng theo vai trò.
*   **Header (Thanh đầu trang):** Hiển thị tên cơ sở làm việc hiện tại, Tên/Avatar user đăng nhập, Nút Đăng xuất, Khay thông báo (Notification Tray) thời gian thực.
*   **Content Area:** Vùng hiển thị nội dung động của từng màn hình.

### Sơ đồ Route của STAFF:
```text
/staff
  ├── /overview (Tab 0: Tổng quan sơ đồ sân và lượt đặt hôm nay)
  ├── /bookings (Tab 2: Quản lý lịch đặt, duyệt & đặt lịch tại quầy)
  ├── /cashier  (Tab 3: Thu ngân, thanh toán offline)
  ├── /operations
  │     ├── /slots (Cấu hình khung giờ các sân - Court Slot Config)
  │     ├── /courts (Xem danh sách sân)
  │     └── /sports (Xem danh mục môn thể thao)
  ├── /report   (Báo cáo doanh thu & ca đấu của cơ sở)
  └── /profile  (Thông tin cá nhân & cơ sở phụ trách)
```

### Sơ đồ Route của ADMIN:
```text
/admin
  ├── /overview    (Tổng quan hệ thống, thống kê doanh thu toàn bộ)
  ├── /facilities  (Quản lý danh sách Cơ sở / Khu liên hợp)
  ├── /courts      (Quản lý danh sách Sân đấu và Đơn giá giờ)
  ├── /sports      (Quản lý danh mục Môn thể thao)
  ├── /users       (Quản lý Thành viên, phân quyền ADMIN/STAFF/CUSTOMER)
  ├── /supervision (Giám sát toàn bộ Booking & Payment của toàn hệ thống)
  └── /profile     (Thông tin cá nhân)
```

---

## 6. 📋 Đặc tả Chi tiết các Chức năng dành cho STAFF

### 6.1. Trang chủ & Tổng quan (Staff Overview)
*   **UX/UI:**
    *   Hiển thị thông số tổng quát ngày hôm nay của cơ sở được gán: **Tổng doanh thu**, **Tổng số ca đấu đã đặt**, **Tỷ lệ lấp đầy sân (%)**.
    *   Thanh Chọn ngày: Dùng DatePicker để đổi ngày (mặc định là ngày hôm nay).
    *   **Lưới Sơ đồ Sân & Khung giờ (Timeline Board):**
        *   Cột bên trái: Danh sách các Sân (Court).
        *   Hàng bên phải: Các khung giờ tương ứng dưới dạng các hộp ô thời gian (Slot Cards) xếp ngang (hỗ trợ cuộn ngang mượt mà hoặc hiển thị dạng bảng thời gian).
*   **Quy tắc hiển thị của ô Khung giờ (Slot Card):**
    *   **Còn trống (Available):** Màu xanh lá (Light Green background, Green border). Hiển thị nhãn **"Còn trống"**. Cho phép click vào.
    *   **Không khả dụng (Unavailable):** Màu xám (Light grey background). Hiển thị nhãn **"Không khả dụng"** (bao gồm các slot đã bị đặt `CONFIRMED`, đang chờ duyệt `PENDING`, bảo trì `isAvailable = false`, hoặc giờ bắt đầu của slot nhỏ hơn thời gian hiện tại - `isPast`). Khóa tương tác, không cho click.
*   **Hành động tương tác:**
    *   Khi Staff bấm vào ô **"Còn trống"**, hệ thống tự động mở Form đặt lịch (Dialog hoặc chuyển sang trang `/staff/bookings` kèm theo các thông số `courtId` và `startMinutes` chọn sẵn).
    *   Nhân viên bấm vào Card Sân ở cột trái để xem chi tiết hoặc chuyển sang cấu hình khung giờ sân đó.

---

### 6.2. Quản lý Đặt lịch & Đặt lịch tại quầy (Staff Booking Management)
*   **UX/UI:**
    *   Thanh tìm kiếm: Tìm theo Mã đặt lịch, Tên khách hàng, Số điện thoại.
    *   Bộ lọc trạng thái (Tab): Tất cả, Chờ duyệt (`PENDING`), Đã xác nhận (`CONFIRMED`), Hoàn thành (`COMPLETED`), Đã hủy (`CANCELLED`).
    *   Danh sách dạng Table (Bảng) hiển thị: Khách hàng (Avatar + Tên + SĐT), Sân đấu, Ngày đặt, Khung giờ, Thành tiền, Trạng thái, Thao tác nhanh.
*   **Nghiệp vụ đặc thù:**
    *   **Prefetch User Profile:** API danh sách booking chỉ trả về `userId`. Web Frontend bắt buộc phải lấy danh sách người dùng (`GET /api/v1/user/`) lưu vào cache, sau đó map `userId` để hiển thị đầy đủ tên thật, SĐT và ảnh đại diện của khách hàng trên bảng.
    *   **Xử lý Lịch đặt:**
        *   Nút **Duyệt đặt sân / Check-in:** Dành cho booking `PENDING` -> Chuyển sang `CONFIRMED`.
        *   Nút **Kết thúc ca đấu:** Dành cho booking `CONFIRMED` -> Chuyển sang `COMPLETED`.
        *   Nút **Từ chối / Hủy lịch:** Chuyển trạng thái sang `CANCELLED`.
*   **Đặt lịch tại quầy (Walk-in Booking Dialog):**
    *   Staff bấm nút **"Đặt lịch mới"** -> Mở Dialog Form.
    *   **Các trường dữ liệu nhập:**
        *   *Cơ sở:* Tự động khóa và hiển thị cơ sở của Staff đang đăng nhập.
        *   *Môn thể thao:* Dropdown chọn môn.
        *   *Sân đấu:* Dropdown chọn sân (lọc theo môn).
        *   *Ngày đặt:* DatePicker (mặc định hôm nay).
        *   *Khung giờ:* Grid hiển thị các slot của sân trong ngày đó (lọc giờ quá khứ và giờ đã đặt).
        *   *Phương thức thanh toán:* Radio chọn **Tiền mặt (Offline)** hoặc **Chuyển khoản (Online)**.
    *   **Quy trình gọi API liên tục (Chỉ 1 lần Click "Xác nhận"):**
        1. Gọi API tạo booking (`POST /api/v1/booking/`).
        2. Lấy `bookingId` trả về, gọi tiếp API tạo payment (`POST /api/v1/payment/`) với method tương ứng (`offline` hoặc `online`).
        3. Lấy `paymentId` trả về, gọi tiếp API duyệt payment thành công (`PUT /api/v1/payment/:id/status` với body `{"status": "SUCCESS"}`).
        4. Gọi API duyệt booking thành công (`PUT /api/v1/booking/:bookingId/status` với body `{"status": "CONFIRMED"}`).
        5. Đóng dialog, hiển thị SnackBar thành công và tự động tải lại danh sách.

---

### 6.3. Thu ngân & Thanh toán tại quầy (Staff Cashier)
*   **UX/UI:**
    *   Danh sách hóa đơn dạng Bảng chia làm 2 Tab: **Chờ thu tiền tại quầy** và **Hóa đơn đã xử lý**.
    *   Mỗi dòng hiển thị: Mã hóa đơn (Payment ID), Tên khách hàng (đối soát qua `bookingId`), Sân đấu, Số tiền cần thu, Phương thức (`BANK_TRANSFER` / `CASH`), Thời gian tạo, Trạng thái.
*   **Hành động tương tác:**
    *   Đối với hóa đơn chờ thu tiền, Staff có nút **"Xác nhận đã thu tiền"**.
    *   Khi bấm vào, gọi API cập nhật trạng thái thanh toán lên `SUCCESS`. Hệ thống sẽ tự động gửi thông báo Real-time cho Khách hàng trên Mobile.

---

### 6.4. Cấu hình Khung giờ Sân (Court Slot Configuration)
*   **UX/UI:**
    *   Chọn Sân đấu để cấu hình qua Dropdown.
    *   Chọn **Giờ mở cửa** & **Giờ đóng cửa** bằng TimePicker.
    *   Chọn **Độ dài 1 ca (Slot Duration)**: 30, 45, 60, hoặc 90 phút.
    *   **Bảng xem trước slot (Slot Grid Preview):**
        *   Hệ thống tự động chia khoảng thời gian từ giờ mở đến giờ đóng cửa thành các ô thời gian tương ứng.
        *   Mỗi ô có thể click để đổi trạng thái: **Khả dụng** (Xanh) $\leftrightarrow$ **Tắt hoạt động/Bảo trì** (Đỏ).
*   **Quy tắc Validation nghiêm ngặt (Phải kiểm tra ở Client trước khi submit):**
    1. Giờ đóng cửa bắt buộc phải sau giờ mở cửa.
    2. Tổng thời gian vận hành tối thiểu phải đạt **120 phút** (2 tiếng).
    3. **Tổng số phút vận hành** (Giờ đóng - Giờ mở) **phải chia hết cho Độ dài 1 ca**. Nếu không chia hết, khóa nút lưu và hiển thị cảnh báo lỗi (Ví dụ: Mở từ 6h - 22h30 = 990 phút, slot 60 phút sẽ bị dư 30 phút $\rightarrow$ Không hợp lệ).
*   **API tích hợp:** Gọi `PUT /api/v1/court/:id/slot-config`.

---

### 6.5. Báo cáo & Thống kê cơ sở (Staff Court Report)
*   **UX/UI:**
    *   Hiển thị biểu đồ cột (Bar Chart) doanh thu theo ngày/tháng của cơ sở.
    *   Biểu đồ tròn (Pie Chart) phân bổ ca đấu theo môn thể thao hoặc theo từng sân.
    *   Thống kê giờ cao điểm (khung giờ được đặt nhiều nhất).
    *   Bảng xếp hạng: Danh sách Top 5 khách hàng thân thiết đặt sân nhiều nhất.

---

## 7. 👑 Đặc tả Chi tiết các Chức năng dành cho ADMIN

### 7.1. Quản lý Cơ sở (Facility Management)
*   **UX/UI:**
    *   Bảng hiển thị: Tên Cơ sở, Thành phố, Địa chỉ đầy đủ, Trạng thái (Hoạt động/Ngừng), Nhân viên quản lý phụ trách (Owner), Ngày tạo.
    *   Nút Thêm cơ sở / Sửa cơ sở mở ra Modal Form.
*   **Nghiệp vụ đặc thù:**
    *   **Smart Address Parser (Phân tích địa chỉ thông minh):**
        *   Khi tạo/sửa cơ sở, Form cần có ô nhập **Thành phố** và ô nhập **Địa chỉ chi tiết**.
        *   Khi gửi API, gộp lại thành chuỗi JSON địa chỉ hoặc map đúng định dạng.
        *   Khi nhận dữ liệu từ API, nếu trường `city` hoặc `fullAddress` trả về dưới dạng JSON String trong DB, Client ReactJS phải viết hàm parser để hiển thị đúng dữ liệu trên giao diện.
    *   **Gán nhân viên phụ trách:**
        *   Dropdown hiển thị danh sách các tài khoản có vai trò `STAFF` (gọi từ API get users).
        *   Admin chọn 1 staff để gán phụ trách cơ sở. Helper phân tích ID nhân viên phải bóc tách chính xác từ trường `staffIds` của response.

---

### 7.2. Quản lý Sân đấu (Court Management)
*   **UX/UI:**
    *   Bảng hiển thị: Mã sân, Tên sân, Cơ sở thuộc về, Môn thể thao, Đơn giá/giờ (định dạng tiền tệ VNĐ), Trạng thái (ACTIVE/MAINTENANCE).
    *   Modal Form Thêm/Sửa sân đấu:
        *   Nhập tên sân, mã sân.
        *   Dropdown chọn Cơ sở (load từ danh sách cơ sở).
        *   Dropdown chọn Môn thể thao (load từ danh sách môn).
        *   Nhập đơn giá mỗi giờ (chỉ cho phép nhập số).
        *   Dropdown chọn Trạng thái.

---

### 7.3. Quản lý Môn Thể thao (Sport Catalog Management)
*   **UX/UI:**
    *   Bảng hiển thị: Tên môn, Mô tả, Quy mô đội hình (Số người đấu, e.g. 5, 7, 11), Trạng thái kích hoạt.
    *   Modal Form tạo/sửa môn thể thao: Validate các thông số bắt buộc, đặc biệt `teamSize` phải là số nguyên dương $> 0$.

---

### 7.4. Quản lý Thành viên & Phân quyền (User Management)
*   **UX/UI:**
    *   Bảng hiển thị danh sách tài khoản: Email, Họ tên, SĐT, Vai trò (CUSTOMER, STAFF, ADMIN), Trạng thái tài khoản (ACTIVE, INACTIVE), Cơ sở làm việc (nếu là Staff).
*   **Nghiệp vụ đặc thù:**
    *   **Đổi vai trò:** Cho phép chuyển quyền nhanh giữa CUSTOMER, STAFF, ADMIN.
    *   **Gán cơ sở cho STAFF:** Nếu chọn vai trò là STAFF, hiển thị thêm Dropdown danh sách Cơ sở để gán trực tiếp.
    *   **Khóa tài khoản:** Chuyển trạng thái tài khoản sang `INACTIVE` để cấm đăng nhập.
    *   **Tạo tài khoản Nhân viên mới (Quick Register):**
        *   Form nhập: Email, Họ tên, SĐT, Cơ sở gán phụ trách.
        *   Khi submit, gọi API đăng ký user. Backend Firebase sẽ tự động tạo tài khoản với mật khẩu mặc định là `123456`.
        *   Gọi tiếp API gán vai trò `STAFF` và gán `facilityId`.

---

### 5.5. Giám sát Toàn hệ thống (Supervision Panel)
*   **UX/UI:**
    *   Xem toàn bộ lịch sử đặt lịch (Booking) và các giao dịch thanh toán (Payment) của toàn hệ thống (không bị giới hạn bởi cơ sở).
    *   Bộ lọc tìm kiếm và bộ lọc nâng cao để đối soát kế toán doanh thu tổng.

---

## 8. 🔌 Đặc tả Hợp đồng API chi tiết (JSON Payloads Mapped)

### 8.1. Xác thực & Profile
*   **Đăng nhập:** `POST /api/v1/auth/sign-in`
    *   *Request:* `{"email": "...", "password": "..."}`
    *   *Response (200):* `{"success": true, "accessToken": "...", "refreshToken": "...", "user": {"_id": "...", "role": "STAFF", "status": "ACTIVE"}}`
*   **Làm mới Token:** `POST /api/v1/auth/refresh-token`
    *   *Request:* `{"refreshToken": "..."}`
*   **Lấy Profile:** `GET /api/v1/user/:id`
    *   *Response (200):* `{"success": true, "user": {"_id": "...", "email": "...", "role": "...", "profile": {"fullName": "...", "phone": "...", "avatar": "..."}}}`

### 8.2. Nghiệp vụ Đặt lịch (Staff/Admin)
*   **Lấy cấu hình slot:** `GET /api/v1/court/:id/slot-config`
*   **Tạo đặt lịch:** `POST /api/v1/booking/`
    *   *Request:* `{"courtId": "...", "bookingDate": "yyyy-MM-dd", "startMinutes": 420, "endMinutes": 480, "totalPrice": 200000}`
*   **Duyệt/Đổi trạng thái booking:** `PUT /api/v1/booking/:id/status`
    *   *Request:* `{"status": "CONFIRMED"}` (Các trạng thái: `CONFIRMED`, `COMPLETED`, `CANCELLED`)

### 8.3. Nghiệp vụ Hóa đơn & Thanh toán (Cashier)
*   **Lấy danh sách thanh toán:** `GET /api/v1/payment/?status=PENDING`
*   **Tạo thanh toán quầy:** `POST /api/v1/payment/`
    *   *Request:* `{"bookingId": "...", "amount": 200000, "method": "CASH", "transactionId": "..."}`
*   **Xác nhận thanh toán thành công:** `PUT /api/v1/payment/:id/status`
    *   *Request:* `{"status": "SUCCESS", "transactionId": "..."}`

### 8.4. Cấu hình vận hành (Staff Slot Config)
*   **Lưu cấu hình slot:** `PUT /api/v1/court/:id/slot-config`
    *   *Request:*
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

### 8.5. Quản lý danh mục (Admin CRUD)
*   **Tạo cơ sở:** `POST /api/v1/facility/`
    *   *Request:* `{"name": "...", "city": "...", "fullAddress": "...", "active": true, "staffIds": ["..."]}`
*   **Tạo sân:** `POST /api/v1/court/`
    *   *Request:* `{"name": "Sân 1", "facilityId": "...", "sportId": "...", "code": "...", "status": "ACTIVE", "pricePerHour": 200000}`
*   **Tạo môn thể thao:** `POST /api/v1/sport/`
    *   *Request:* `{"name": "...", "description": "...", "teamSize": 5, "active": true}`
*   **Tạo User mới & Gán quyền:**
    1. Đăng ký auth: `POST /api/v1/auth/register` $\rightarrow$ sinh tài khoản.
    2. Gán quyền: `PUT /api/v1/user/:id/role` $\rightarrow$ `{"role": "STAFF"}`
    3. Gán cơ sở: `POST /api/v1/user/:id/assign-facility` $\rightarrow$ `{"facilityId": "..."}`
