# 📱 Navigation Flow - Dự án khulienhopthethao (Sport Energy)

## 🗺️ Sơ đồ tổng quan

```
[SignInPage] (/sign-in)
  ├─→ [SignUpPage] (/sign-up)
  │     └─→ [VerifyEmailPage] (/verify-email)
  │           └─→ [HomePage] (/home)
  └─→ [HomePage] (/home)
        ├─→ [AdminDashboardSection] (Màn hình Admin)
        │     ├─→ [UserListPage] (/users)
        │     │     └─→ [UserDetailPage] (/users/:userId)
        │     │           └─→ [UserNotificationPage] (/users/:userId/notifications)
        │     ├─→ [FacilityListPage] (/catalog/facilities)
        │     ├─→ [CourtListPage] (/catalog/courts)
        │     │     └─→ [StaffCourtSlotConfigPage] (/staff/court-slot-config)
        │     ├─→ [SportListPage] (/catalog/sports)
        │     ├─→ [BookingListPage] (/bookings)
        │     │     └─→ [BookingDetailPage] (/bookings/:bookingId)
        │     └─→ [PaymentListPage] (/payments)
        │           ├─→ [PaymentDetailPage] (/payments/:paymentId)
        │           └─→ [InvoiceListPage] (/payments/invoices)
        │                 └─→ [InvoiceDetailPage] (/payments/invoices/:invoiceId)
        │
        ├─→ [StaffDashboardSection] (Màn hình Staff)
        │     ├─→ Tab 0: Tổng quan (CustomerBookingCatalogSection)
        │     ├─→ Tab 1: Vận hành sân (Staff Action Cards)
        │     │     ├─→ [StaffCourtSlotConfigPage] (/staff/court-slot-config)
        │     │     ├─→ [CourtListPage] (/catalog/courts)
        │     │     └─→ [SportListPage] (/catalog/sports)
        │     ├─→ Tab 2: Đặt lịch (_StaffBookingInlineSection)
        │     ├─→ Tab 3: Thanh toán (_StaffPaymentInlineSection)
        │     └─→ Tab 4: Tài khoản (_StaffAccountInlineSection)
        │
        ├─→ [CustomerDashboardSection] (Màn hình Khách hàng)
        │     ├─→ Tab 0: Đặt sân (CustomerBookingCatalogSection)
        │     │     └─→ [CustomerBookingDetailPage] (/bookings/customer/create/detail)
        │     ├─→ Tab 1: Thanh toán (_CustomerPaymentInlineSection)
        │     ├─→ Tab 2: Lịch sử (_CustomerBookingHistoryInlineSection)
        │     └─→ Tab 3: Tài khoản (SettingPage - embedded)
        │
        ├─→ [NotifyPage] (/activity)
        ├─→ [SettingPage] (/account)
        ├─→ [MenuPopupPage] (/menu)
        ├─→ [HtmlPage] (/html)
        └─→ [NotifyPopupPage] (/notifycation-popup)
```

---

## 🛡️ Navigation Guard & Authentication Check
Toàn bộ routing được cấu hình tập trung bằng `GoRouter` tại [app.dart](file:///d:/Source/khulienhopthethao/lib/app.dart). Các luật điều hướng (Redirect logic):
* **Authentication Guard**: Nếu người dùng chưa đăng nhập (`isSignedIn == false`) và truy cập các màn hình không phải là Authentication Paths (`/sign-in`, `/sign-up`, `/verify-email`), hệ thống tự động redirect về màn hình Đăng nhập (`/sign-in`).
* **Authenticated Redirect**: Nếu đã đăng nhập (`isSignedIn == true`) mà truy cập các Authentication Paths, hệ thống tự động redirect về màn hình Trang chủ (`/home`).
* **Admin-only Paths**: Màn hình quản lý người dùng (`/users`) và quản lý cơ sở (`/catalog/facilities`) chỉ cho phép vai trò `admin` truy cập. Các vai trò khác truy cập sẽ bị redirect về `/home`.
* **Staff Blocked Paths**: Màn hình danh sách thanh toán (`/payments`) bị chặn đối với vai trò `staff`. Staff truy cập sẽ bị redirect về `/home`.

---

## 📋 Chi tiết từng màn hình

### 1. Đăng nhập (SignInPage)
**File:** [index.dart](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signin/pages/index.dart)  
**Class/Widget:** `SignInPage`  
**Route:** `/sign-in` (Name: `signIn`)  
**Điều hướng TỪ:**
* Hệ thống tự động redirect khi chưa được xác thực.
* [SignUpPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signup/pages/index.dart) → khi nhấn nút "Đăng nhập".
* [VerifyEmailPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/email_verification/pages/index.dart) → khi nhấn "Quay về đăng nhập".
* [SettingPage](file:///d:/Source/khulienhopthethao/modules/home_module/lib/persentation/ui/setting/pages/setting_page.dart) → khi người dùng nhấn Đăng xuất.

**Điều hướng ĐẾN:**
* → [VerifyEmailPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/email_verification/pages/index.dart) (`/verify-email`) - khi phát hiện email tài khoản chưa được xác thực (truyền tham số `email` và `password` qua `extra`).
* → [HomePage](file:///d:/Source/khulienhopthethao/modules/home_module/lib/persentation/ui/home/pages/home_page.dart) (`/home`) - khi đăng nhập thành công.
* → [SignUpPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signup/pages/index.dart) (`/sign-up`) - khi nhấn "Tạo tài khoản".

**Tham số truyền vào:** Không có.

**Code điều hướng mẫu:**
```dart
context.go(
  UserPath.verifyEmail,
  extra: <String, String>{
    'email': _emailController.text.trim(),
    'password': _passwordController.text,
  },
);
```

---

### 2. Đăng ký (SignUpPage)
**File:** [index.dart](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signup/pages/index.dart)  
**Class/Widget:** `SignUpPage`  
**Route:** `/sign-up` (Name: `signUp`)  
**Điều hướng TỪ:**
* [SignInPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signin/pages/index.dart) → khi nhấn nút "Tạo tài khoản".

**Điều hướng ĐẾN:**
* → [VerifyEmailPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/email_verification/pages/index.dart) (`/verify-email`) - khi đăng ký thành công (truyền tham số `email` và `password` qua `extra` để tự động xác thực).
* → [SignInPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signin/pages/index.dart) (`/sign-in`) - khi nhấn nút Back hoặc "Đăng nhập".

**Tham số truyền vào:** Không có.

**Code điều hướng mẫu:**
```dart
context.goNamed(
  UserRoutes.verifyEmail,
  extra: <String, String>{
    'email': _emailController.text.trim(),
    'password': _passwordController.text,
  },
);
```

---

### 3. Xác thực Email (VerifyEmailPage)
**File:** [index.dart](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/email_verification/pages/index.dart)  
**Class/Widget:** `VerifyEmailPage`  
**Route:** `/verify-email` (Name: `verifyEmail`)  
**Điều hướng TỪ:**
* [SignInPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signin/pages/index.dart) → khi đăng nhập bằng tài khoản chưa xác thực.
* [SignUpPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signup/pages/index.dart) → khi đăng ký thành công.

**Điều hướng ĐẾN:**
* → [HomePage](file:///d:/Source/khulienhopthethao/modules/home_module/lib/persentation/ui/home/pages/home_page.dart) (`/home`) - sau khi xác thực email thành công và đăng nhập thành công.
* → [SignInPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signin/pages/index.dart) (`/sign-in`) - khi nhấn nút "Quay về đăng nhập".

**Tham số truyền vào (qua `state.extra`):**
* `email`: String - Email của tài khoản cần xác thực.
* `password`: String - Mật khẩu tài khoản (dùng để tự động re-authenticate sau khi user xác nhận đã hoàn tất).

---

### 4. Trang chủ (HomePage)
**File:** [home_page.dart](file:///d:/Source/khulienhopthethao/modules/home_module/lib/persentation/ui/home/pages/home_page.dart)  
**Class/Widget:** `HomePage`  
**Route:** `/home` (Name: `homeScreen`)  
**Điều hướng TỪ:**
* Màn hình Đăng nhập/Xác thực sau khi thành công.
* Toàn bộ hệ thống khi các màn hình con nhấn quay lại (back) hoặc redirect do vi phạm guard.

**Điều hướng ĐẾN:**
* → [NotifyPage](file:///d:/Source/khulienhopthethao/modules/home_module/lib/persentation/ui/notify/pages/index.dart) (`/activity`) - khi nhấn icon thông báo trên dashboard.
* → [MenuPopupPage](file:///d:/Source/khulienhopthethao/modules/home_module/lib/persentation/ui/menu_popup/menu_popup.dart) (`/menu`) - khi admin nhấn notification popup.
* → [SignInPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signin/pages/index.dart) (`/sign-in`) - khi bloc nhận sự kiện đăng xuất (`UserSignedOut`).
* → Điều hướng đến các chức năng quản trị tùy theo vai trò (Role-based):
  * **Admin**: Nhấp các mục quản lý để sang `/users`, `/catalog/facilities`, `/catalog/courts`, `/catalog/sports`, `/bookings`, `/payments`.
  * **Staff**: Nhấp các card tác vụ để sang `/staff/court-slot-config`, `/catalog/courts`, `/catalog/sports`.
  * **Customer**: Nhấp chọn sân cụ thể trong `CustomerBookingCatalogSection` để chuyển sang màn đặt lịch chi tiết (`/bookings/customer/create/detail`).

**Tham số truyền vào (Query Parameters):**
* `tab`: String (Tùy chọn) - Chỉ định tab cần active ngay từ đầu (Ví dụ: `payment`, `history`, `account`, `staff-ops`, `staff-payment`, v.v.).
* `focusInvoiceId` / `focusBookingId` / `focusNotificationId`: String (Tùy chọn) - Chỉ định ID đối tượng cần focus và hiển thị chi tiết tự động (phục vụ điều hướng từ Notification Click).

**Code điều hướng mẫu:**
```dart
context.go('/home?tab=history');
```

---

### 5. Chi tiết Đặt lịch của Khách hàng (CustomerBookingDetailPage)
**File:** [customer_booking_detail_page.dart](file:///d:/Source/khulienhopthethao/modules/booking_module/lib/persentation/ui/customer_booking_detail_page.dart)  
**Class/Widget:** `CustomerBookingDetailPage`  
**Route:** `/bookings/customer/create/detail` (Name: `customerBookingDetail`)  
**Điều hướng TỪ:**
* [CustomerBookingCatalogSection](file:///d:/Source/khulienhopthethao/modules/booking_module/lib/persentation/ui/customer_booking_catalog_section.dart) (hiển thị trên tab chính của Customer/Staff) → khi người dùng click vào sân cụ thể để đặt.

**Điều hướng ĐẾN:**
* → [HomePage](file:///d:/Source/khulienhopthethao/modules/home_module/lib/persentation/ui/home/pages/home_page.dart) (`/home?tab=history`) - sau khi xác nhận đặt sân thành công (đưa khách về tab Lịch sử đặt lịch).

**Tham số truyền vào (qua `state.extra`):**
* `args`: `CustomerBookingDetailArgs` - chứa:
  * `sportId` (String), `sportName` (String)
  * `courtId` (String), `courtName` (String)
  * `facilityId` (String), `facilityName` (String), `facilityAddress` (String)
  * `initialDate` (DateTime)

**Code điều hướng mẫu:**
```dart
context.pushNamed(
  BookingRoutes.customerBookingDetail,
  extra: CustomerBookingDetailArgs(
    sportId: court.sport!.id,
    sportName: court.sport!.name,
    courtId: court.id,
    courtName: court.name,
    facilityId: court.facility!.id,
    facilityName: group.facilityName,
    facilityAddress: group.fullAddress,
    initialDate: _selectedBookingDate!,
  ),
);
```

---

### 6. Chi tiết Đặt lịch (BookingDetailPage)
**File:** [booking_detail_page.dart](file:///d:/Source/khulienhopthethao/modules/booking_module/lib/persentation/ui/booking_detail_page.dart)  
**Class/Widget:** `BookingDetailPage`  
**Route:** `/bookings/:bookingId` (Name: `bookingDetail`)  
**Điều hướng TỪ:**
* Danh sách đặt lịch (`BookingListPage`) khi click xem chi tiết.
* Nhấp từ thông báo có chứa mã booking.

**Điều hướng ĐẾN:**
* Chỉ có thể quay về màn hình trước đó.

**Tham số truyền vào (Path Parameters):**
* `bookingId`: String - Mã định danh của booking cần xem chi tiết.

---

### 7. Cấu hình Khung giờ Sân cho Nhân viên (StaffCourtSlotConfigPage)
**File:** [staff_court_slot_config_page.dart](file:///d:/Source/khulienhopthethao/modules/facility_module/lib/persentation/ui/staff_court_slot_config_page.dart)  
**Class/Widget:** `StaffCourtSlotConfigPage`  
**Route:** `/staff/court-slot-config` (Name: `staffCourtSlotConfig`)  
**Điều hướng TỪ:**
* [CourtListPage](file:///d:/Source/khulienhopthethao/modules/facility_module/lib/persentation/ui/court_list_page.dart) → khi click vào cấu hình giờ của một sân.
* Tác vụ vận hành trên dashboard của nhân viên.

**Điều hướng ĐẾN:**
* Quay về màn hình trước đó.

**Tham số truyền vào (Query Parameters):**
* `courtId`: String (Tùy chọn) - ID của sân cần focus cấu hình đầu tiên.

**Code điều hướng mẫu:**
```dart
context.push('${FacilityPath.staffCourtSlotConfig}?courtId=$queryCourtId');
```

---

### 8. Danh sách Thanh toán (PaymentListPage)
**File:** [payment_list_page.dart](file:///d:/Source/khulienhopthethao/modules/payment_module/lib/persentation/ui/payment_list_page.dart)  
**Class/Widget:** `PaymentListPage`  
**Route:** `/payments` (Name: `paymentList`)  
**Điều hướng TỪ:**
* Admin dashboard click "Quản lý thanh toán".

**Điều hướng ĐẾN:**
* → [InvoiceListPage](file:///d:/Source/khulienhopthethao/modules/payment_module/lib/persentation/ui/invoice_list_page.dart) (`/payments/invoices`) - khi admin/staff nhấn xem danh sách hóa đơn.
* → [PaymentDetailPage](file:///d:/Source/khulienhopthethao/modules/payment_module/lib/persentation/ui/payment_detail_page.dart) (`/payments/:paymentId`) - khi click vào một bản ghi thanh toán.

**Tham số truyền vào:** Không có.

---

### 9. Chi tiết Hóa đơn (InvoiceDetailPage)
**File:** [invoice_detail_page.dart](file:///d:/Source/khulienhopthethao/modules/payment_module/lib/persentation/ui/invoice_detail_page.dart)  
**Class/Widget:** `InvoiceDetailPage`  
**Route:** `/payments/invoices/:invoiceId` (Name: `invoiceDetail`)  
**Điều hướng TỪ:**
* [InvoiceListPage](file:///d:/Source/khulienhopthethao/modules/payment_module/lib/persentation/ui/invoice_list_page.dart) → click vào hóa đơn.

**Điều hướng ĐẾN:**
* → [PaymentListPage](file:///d:/Source/khulienhopthethao/modules/payment_module/lib/persentation/ui/payment_list_page.dart) (`/payments`) - sau khi xác nhận thanh toán offline thành công.

**Tham số truyền vào (Path Parameters):**
* `invoiceId`: String - ID của hóa đơn.

---

### 10. Danh sách Người dùng (UserListPage)
**File:** [user_list_page.dart](file:///d:/Source/khulienhopthethao/modules/user_management_module/lib/persentation/ui/user_list_page.dart)  
**Class/Widget:** `UserListPage`  
**Route:** `/users` (Name: `userList`)  
**Điều hướng TỪ:**
* Admin dashboard click "Quản lý người dùng".

**Điều hướng ĐẾN:**
* → [UserDetailPage](file:///d:/Source/khulienhopthethao/modules/user_management_module/lib/persentation/ui/user_detail_page.dart) (`/users/:userId`) - khi click xem thông tin chi tiết một user.
* → [UserNotificationPage](file:///d:/Source/khulienhopthethao/modules/user_management_module/lib/persentation/ui/user_notification_page.dart) (`/users/:userId/notifications`) - khi chọn xem thông báo của user đó.

**Tham số truyền vào:** Không có.

**Code điều hướng mẫu:**
```dart
context.push('/users/$userId');
```

---

### 11. Thông báo (NotifyPage)
**File:** [index.dart](file:///d:/Source/khulienhopthethao/modules/home_module/lib/persentation/ui/notify/pages/index.dart)  
**Class/Widget:** `NotifyPage`  
**Route:** `/activity` (Name: `activityScreen`)  
**Điều hướng TỪ:**
* Nhấn vào icon thông báo ở góc trên bên phải dashboard của Khách hàng hoặc Nhân viên.
* Click từ danh mục cài đặt hệ thống.

**Điều hướng ĐẾN:**
* Tùy thuộc vào loại thông báo và vai trò của user, khi người dùng click vào thông báo hệ thống sẽ phân tích nội dung để trích xuất ID đối tượng và điều hướng về trang chủ `/home` kèm các tham số query (để hiển thị dialog/hóa đơn tự động):
  * **Khách hàng + Booking**: → `/home?tab=history&focusBookingId=xxx&focusNotificationId=yyy`
  * **Khách hàng + Payment**: → `/home?tab=payment&focusInvoiceId=xxx&focusNotificationId=yyy`
  * **Staff + Booking**: → `/home?tab=staff-booking&focusBookingId=xxx&focusNotificationId=yyy`
  * **Staff + Payment**: → `/home?tab=staff-payment&focusInvoiceId=xxx&focusNotificationId=yyy`

**Tham số truyền vào:** Không có.

**Code điều hướng mẫu:**
```dart
final String route = _resolveNotificationRoute(notification: notification, role: role);
context.go(route);
```

---

### Các màn hình phụ / placeholders / khác
* **FacilityListPage** (`/catalog/facilities`): Màn hình danh sách cơ sở khu liên hợp, cho phép quản lý CRUD cơ sở. Chỉ hiển thị cho Admin.
* **SportListPage** (`/catalog/sports`): Danh sách môn thể thao trong hệ thống.
* **CourtListPage** (`/catalog/courts`): Danh sách sân, Staff chỉ thao tác được sân thuộc cơ sở được gán.
* **BookingListPage** (`/bookings`): Danh sách lịch đặt của toàn bộ hệ thống (dành cho Admin/Staff).
* **BookingHistoryPage** (`/bookings/history`): Danh sách lịch sử đặt sân của user.
* **InvoiceListPage** (`/payments/invoices`): Danh sách hóa đơn cần thanh toán.
* **PaymentDetailPage** (`/payments/:paymentId`): Chi tiết giao dịch thanh toán.
* **UserDetailPage** (`/users/:userId`): Chi tiết phân quyền và trạng thái của user.
* **UserNotificationPage** (`/users/:userId/notifications`): Xem lịch sử thông báo của một user cụ thể.
* **SettingPage** (`/account`): Cấu hình tài khoản, ngôn ngữ, giao diện dark mode và Đăng xuất.
* **MenuPopupPage** (`/menu`): Placeholder cho popup menu.
* **HtmlPage** (`/html`): Placeholder trang HTML tĩnh.
* **NotifyPopupPage** (`/notifycation-popup`): Placeholder popup thông báo.
* **_VoucherPage** (`/voucher`): Placeholder trang ưu đãi.
* **_ServicesPage** (`/services`): Placeholder trang dịch vụ đi kèm.
* **NotFoundPage**: Hiển thị khi nhập sai URL không tồn tại.

---

## 🏗️ Cấu trúc module

Hệ thống được thiết kế theo kiến trúc Modular Clean Architecture. Các màn hình UI được chia theo các thư mục con tương ứng trong thư mục `modules/`:

### app_module
* `lib/persentation/components/`
  * `base_page.dart` → Component layout cơ sở
  * `input_widget.dart` → Trường dữ liệu dùng chung
  * `reload_app.dart` → Component reload trạng thái ứng dụng
* `lib/persentation/ui/page/`
  * `notfound.dart` → Màn hình 404 Not Found

### authentication_module
* `lib/persentation/ui/signin/pages/`
  * `index.dart` → `SignInPage` (Màn hình Đăng nhập)
* `lib/persentation/ui/signup/pages/`
  * `index.dart` → `SignUpPage` (Màn hình Đăng ký)
* `lib/persentation/ui/email_verification/pages/`
  * `index.dart` → `VerifyEmailPage` (Màn hình Xác thực Email)
* `lib/persentation/ui/user_info/pages/`
  * `index.dart` → `UserInfoPage` (Placeholder thông tin tài khoản)

### booking_module
* `lib/persentation/ui/`
  * `booking_list_page.dart` → Danh sách đặt lịch của hệ thống
  * `booking_detail_page.dart` → Chi tiết lịch đặt
  * `booking_history_page.dart` → Lịch sử đặt lịch của khách hàng
  * `customer_booking_wizard_page.dart` → Màn hình catalog chọn sân theo môn
  * `customer_booking_detail_page.dart` → Chọn giờ đặt sân và tạo booking
  * `customer_booking_catalog_section.dart` → Widget hiển thị timeline các sân

### facility_module
* `lib/persentation/ui/`
  * `facility_list_page.dart` → Quản lý các cơ sở khu liên hợp
  * `sport_list_page.dart` → Quản lý danh mục môn thể thao
  * `court_list_page.dart` → Quản lý danh sách sân
  * `staff_court_slot_config_page.dart` → Cấu hình vận hành khung giờ sân

### home_module
* `lib/persentation/ui/home/pages/`
  * `home_page.dart` → `HomePage` chung
  * `admin/admin_dashboard_section.dart` → Bảng điều khiển cho Admin
  * `staff/staff_dashboard_section.dart` → Bảng điều khiển cho Staff
  * `customer/customer_dashboard_section.dart` → Bảng điều khiển cho Customer
* `lib/persentation/ui/main/`
  * `main_page.dart` → Shell page chứa GoRouter Navigation Shell
* `lib/persentation/ui/notify/pages/`
  * `index.dart` → Màn hình thông báo chính (`NotifyPage`)
  * `popup.dart` → Placeholder Notify Popup
* `lib/persentation/ui/setting/pages/`
  * `setting_page.dart` → Màn hình cài đặt tài khoản (`SettingPage`)
* `lib/persentation/ui/menu_popup/`
  * `menu_popup.dart` → Placeholder Menu Popup

### payment_module
* `lib/persentation/ui/`
  * `payment_list_page.dart` → Màn hình giao dịch thanh toán
  * `payment_detail_page.dart` → Chi tiết giao dịch thanh toán
  * `invoice_list_page.dart` → Danh sách hóa đơn đặt sân
  * `invoice_detail_page.dart` → Chi tiết hóa đơn và nút thanh toán offline

### services_module
* Rút gọn chỉ chứa `_ServicesPage` (Placeholder trang dịch vụ phụ trợ).

### user_management_module
* `lib/persentation/ui/`
  * `user_list_page.dart` → Quản lý phân quyền user
  * `user_detail_page.dart` → Thông tin chi tiết user
  * `user_notification_page.dart` → Danh sách thông báo riêng của user

---

## 🔀 Bottom Navigation / Drawer

Dự án không sử dụng Bottom Navigation truyền thống ở cấp root (Root Shell Route ẩn menu này bằng cách đặt `bottomNavigationBar: null` tại [main_page.dart](file:///d:/Source/khulienhopthethao/modules/home_module/lib/persentation/ui/main/main_page.dart)). 

Thay vào đó, bottom navigation được thiết kế riêng biệt trong từng Dashboard của **Khách hàng** và **Nhân viên**:

### 📱 Bottom Navigation của Khách hàng (Customer NavigationBar)
1. **Đặt sân** → Hiển thị `CustomerBookingCatalogSection` để xem danh sách sân và giờ trống.
2. **Thanh toán** → Hiển thị `_CustomerPaymentInlineSection` để theo dõi các hóa đơn đang chờ.
3. **Lịch sử** → Hiển thị `_CustomerBookingHistoryInlineSection` chứa lịch sử booking.
4. **Tài khoản** → Hiển thị `SettingPage` để cài đặt giao diện/tài khoản.

### 📱 Bottom Navigation của Nhân viên (Staff NavigationBar)
1. **Tổng quan** → Renders báo cáo hoạt động nhanh kèm timeline đặt sân hôm nay.
2. **Vận hành sân** → Cung cấp các lối tắt nhanh sang cấu hình slot giờ, quản lý sân, quản lý môn thể thao.
3. **Đặt lịch** → Quản lý toàn bộ danh sách đặt lịch (`_StaffBookingInlineSection`).
4. **Thanh toán** → Xác nhận nhanh thanh toán trực tiếp của khách hàng tại quầy (`_StaffPaymentInlineSection`).
5. **Tài khoản** → Cấu hình cá nhân (`SettingPage`).

---

## 📊 Thống kê dự án

* **Tổng số màn hình khả dụng**: 28 màn hình (bao gồm cả màn 404 và các màn placeholder).
* **Tổng số route định tuyến**: 27 routes.
* **Màn hình có nhiều điều hướng đến nhất**:
  * [HomePage](file:///d:/Source/khulienhopthethao/modules/home_module/lib/persentation/ui/home/pages/home_page.dart) (`/home`) - Điểm đến của tất cả luồng đăng nhập, xác thực thành công và nút back/redirect.
  * [SignInPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/signin/pages/index.dart) (`/sign-in`) - Điểm đến mặc định khi token hết hạn hoặc chưa đăng nhập.
* **Màn hình không có điều hướng đến (màn chết)**:
  * [UserInfoPage](file:///d:/Source/khulienhopthethao/modules/authentication_module/lib/persentation/ui/user_info/pages/index.dart) - File màn hình tồn tại trong thư mục mã nguồn nhưng không được khai báo trong hệ thống Router.
