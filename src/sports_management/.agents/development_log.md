# Nhật ký phát triển (Development Log)

- **2026-05-29** - Thiết kế hệ thống tìm trận (Ghép trận) dành cho Khách hàng - Phần Backend.

  - Phân tích và xây dựng giải pháp kiến trúc ghép trận (Matchmaking) ở phía Backend cho dự án Sport Energy, đảm bảo tính nhất quán với các thực thể hiện hữu (`User`, `Facility`, `Court`, `Sport`, `Booking`).
  - Viết tài liệu đặc tả chi tiết \[matching.md\](file:///d:/Source/sport_management/sports_management/matching.md) bao gồm: Tổng quan nghiệp vụ, Mô hình dữ liệu (Schemas cho `MatchRequest` và `MatchParticipant`), Đặc tả REST APIs (kèm Request/Response JSON chuẩn và phân quyền), Thuật toán ghép cặp thông minh (CS Score & gợi ý gộp phòng), cùng cơ chế Chia sẻ chi phí sân tự động.
  - Cấu hình các mã lỗi đặc thù cho Matching (`MATCH_FULL`, `HOST_CANNOT_JOIN`, `BOOKING_ALREADY_MAPPED`, `CONFLICTING_MATCH`...).

- **2026-05-28** - Sửa lỗi RangeError trên Tab Thành viên.

  - Sửa lỗi `RangeError (end): Invalid value: Only valid value is 0: 1` xảy ra trên tab quản lý thành viên (`user_management_page.dart`) khi người dùng mới có trường tên (`user.name`) hoặc email (`user.email`) trống (`""`). Bằng cách bổ sung logic tính toán hiển thị an toàn `displayName` trước khi gọi hàm `.substring(0, 1)`.
  - Chạy `flutter analyze` xác minh thành công và biên dịch chuẩn xác không lỗi.

- **2026-05-28** - Khắc phục các lỗi hiển thị (Layout Overflow) trên tất cả các tab Admin.

  - Sửa lỗi tràn giao diện ở các tab Cơ sở (`facility_management_page.dart`), Sân đấu (`court_management_page.dart`) và Thành viên (`user_management_page.dart`). Sử dụng `Expanded`, `Flexible`, `ellipsis`, và chuyển đổi cấu trúc nút hàng ngang sang `Wrap` để giao diện co giãn linh hoạt và tự động xuống dòng khi màn hình nhỏ.
  - Chạy `flutter analyze` kiểm chứng, dự án biên dịch thành công không có lỗi tĩnh.

- **2026-05-28** - Khắc phục các lỗi hiển thị (Layout Overflow) & Sửa lỗi RangeError trên Tab Cơ sở.

  - Sửa lỗi tràn giao diện (layout overflowed) trên các màn hình home của Customer, Staff, Admin và màn hình Booking của Customer. Sử dụng các kỹ thuật như giới hạn dòng (`maxLines: 1`), cắt chữ tràn (`TextOverflow.ellipsis`), linh hoạt co giãn (`Expanded`/`Flexible`), tỷ lệ aspect ratio động, và cấu trúc tự xuống dòng (`Wrap`).
  - Sửa lỗi `RangeError (end): Invalid value: Not in inclusive range 0..2: 4` xảy ra trên tab quản lý cơ sở (`facility_management_page.dart`) bằng cách bổ sung kiểm tra độ dài an toàn (`length < 4`) trước khi thực hiện hàm `substring(0, 4)` trên trường `facility.ownerId`.
  - Toàn bộ source code được xác minh thành công và biên dịch chuẩn xác không lỗi thông qua `flutter analyze`.

- **2026-05-28** - Hoàn chỉnh tài liệu `api-admin-staff.md` — Ultra-detailed API Specification.

  - Đọc toàn bộ source code `server_module` (Dart): `AuthService`, `BookingService`, `CourtService`, `FacilityService`, `SportService`, `PaymentService`, `ReviewService`, `NotificationService`, `UploadService`, `ContentService`, `UserService`.
  - Trích xuất chính xác từng endpoint URL, method, request body, response structure, field types, constraints từ code Dart thực tế.
  - Bổ sung bảng mapping `Dart Model → JSON key` (xử lý `id` vs `_id` ambiguity).
  - Bổ sung Error Code Reference Table đầy đủ (`AUTH_FAILED`, `CONFLICTED_SLOT`, `REFRESH_FAILED`...).
  - Tài liệu hoá 5 luồng nghiệp vụ đặc biệt: Staff đặt hộ, Token Refresh, CRM Login Flow, Slot filter real-time, Admin slot config.
  - Bảng tóm tắt 43 endpoints với phân quyền rõ ràng.

- **2026-05-23** - Triển khai Phase 3: Quản lý Lịch sử Đặt sân (Booking History) & Lọc slot động theo ngày - **Hoàn thành**.

  - Cập nhật `BookingRepositoryImpl` để hỗ trợ parse `BookingDetailEntity` từ API.
  - Tích hợp `BookingHistoryPage` vào `CustomerDashboardSection`.
  - Khai báo route `/booking/:bookingId` để dẫn đến `BookingDetailPage`.
  - Đăng ký DI cho `GetBookingHistoryUseCase` và `GetBookingDetailUseCase`.
  - Lọc slot thời gian đã đặt: Cập nhật `GetSlotConfigUseCase`, `CourtRepositoryImpl` và `court_booking_page.dart` để tự động truyền ngày đặt sân được chọn dưới dạng query parameter (`bookingDate` và `date`) lên API, cho phép Backend nhận diện và ẩn/khóa các khung giờ đã được người khác đặt trước trong ngày đó.
  - Tối ưu hóa Client-side Filter: Tích hợp gọi `GetBookingHistoryUseCase` khi tải cấu hình slot để đối soát trực tiếp các booking hiện hữu của user. Nếu phát hiện slot trùng lặp với booking đã đặt (có trạng thái hoạt động: khác CANCELLED), Client sẽ tự động khóa và hiển thị trạng thái "Đã đặt" để tăng tính bảo mật và chuẩn xác kể cả khi Backend không lọc động.

- **2026-05-23** - Triển khai Phase 4: Thanh toán hóa đơn (Payment) - **Hoàn thành**.

  - Khởi tạo package `payment_module` theo kiến trúc Clean Architecture.
  - Xây dựng các thực thể, UseCases, Repositories kết nối API thanh toán.
  - Tích hợp trang thanh toán giả lập `MockPaymentPage` với QR Code và chuyển khoản ngân hàng.
  - Nhúng `PaymentTabWidget` vào Customer Dashboard và cấu hình GoRouter trong `app_module`.
  - Khắc phục lỗi `RangeError` khi gán `bookingId` có độ dài ngắn hơn 6 ký tự.

- **2026-05-23** - Triển khai Phase 5: Đánh giá sân bãi (Reviews) - **Hoàn thành**.

  - Khởi tạo package `review_module` theo kiến trúc Clean Architecture.
  - Triển khai `ReviewDetailEntity`, `GetCourtReviewsUseCase` và `CreateReviewUseCase`.
  - Triển khai `ReviewRepositoryImpl` kết nối trực tiếp API `/review/` với query parameters thông qua `DioClient`.
  - Xây dựng giao diện chấm điểm sao động `ReviewBottomSheet` và danh sách nhận xét `ReviewsListWidget`.
  - Tích hợp nút Đánh giá vào Lịch sử & Chi tiết đặt sân khi booking ở trạng thái `COMPLETED`.
  - Nhúng danh sách đánh giá trực quan vào trang đặt sân `CourtBookingPage`.

- **2026-05-23** - Triển khai Phase 1 Admin: Quản lý Cơ sở & Sân đấu (Facility & Court Management) - **Hoàn thành**.

  - Cấu hình dependencies cục bộ và đăng ký các UseCases (`CreateFacilityUseCase`, `UpdateFacilityUseCase`, `DeleteFacilityUseCase`, `GetFacilityCourtsUseCase`, `CreateCourtUseCase`, `UpdateCourtUseCase`, `DeleteCourtUseCase`, `GetStaffUsersUseCase`).
  - Triển khai `FacilityManagementCubit` và `CourtManagementCubit` để quản lý trạng thái tải danh sách cơ sở, sân đấu và các thao tác CRUD.
  - Xây dựng giao diện `FacilityManagementPage` và `CourtManagementPage` hiện đại theo tông màu cam `0xFFFF5600`.
  - Cấu hình routes `/facility` và `/facility/:facilityId/courts` trong `facility_routes.dart` và tích hợp vào `app_router.dart`.
  - Đổi tên `GetCourtsUseCase` thành `GetFacilityCourtsUseCase` để tránh xung đột ambiguous import với `booking_module`.
  - Khắc phục các lỗi phân tích cú pháp tĩnh liên quan đến getter `code` và `pricePerHour` của `CourtEntity` và lỗi tham số `bottom` của `EdgeInsets.symmetric`.

- **2026-05-24** - Tinh chỉnh luồng điều hướng sau đăng nhập cho tài khoản ADMIN & STAFF (bỏ qua CompleteProfileSection để chuyển thẳng vào dashboard quản lý) - **Hoàn thành**.

- **2026-05-24** - Tích hợp Phase 1 Admin (Quản lý Cơ sở & Sân đấu) dưới dạng Tab con - **Hoàn thành**.

  - Tái cấu trúc `AdminDashboardSection` thành giao diện 3 Tab sử dụng `BottomNavigationBar`: Tổng quan, Cơ sở, Sân đấu.
  - Cập nhật `FacilityManagementPage` và `CourtManagementPage` hỗ trợ cờ `isEmbedded` để ẩn `AppBar` khi được nhúng trực tiếp làm nội dung Tab.
  - Liên kết Tab mượt mà: Nhấp vào cơ sở tại Tab 1 (Cơ sở) sẽ tự động lưu thông tin ID cơ sở và chuyển hướng sang Tab 2 (Sân đấu).
  - Tải động danh sách cơ sở tại Tab 2 qua `GetFacilitiesUseCase` và hiển thị bằng Dropdown, cho phép Admin chuyển đổi cơ sở nhanh chóng để cập nhật danh sách sân đấu tương ứng.

- **2026-05-24** - Triển khai Phase 2 Admin: Quản lý Danh mục Môn Thể thao (Sport Catalog Management) - **Hoàn thành**.

  - Định nghĩa thực thể `SportCatalogEntity` kế thừa từ `SportEntity` trong `facility_module` để lưu trữ thêm các trường: mô tả (`description`), quy mô đội hình (`teamSize`), và trạng thái kích hoạt (`active`).
  - Cập nhật `SportRepositoryImpl` trong `facility_module` để tự động parse các trường mở rộng này từ dữ liệu JSON của API.
  - Xây dựng 3 UseCases mới: `CreateSportUseCase`, `UpdateSportUseCase`, `DeleteSportUseCase` và đăng ký vào GetIt DI.
  - Phát triển `SportManagementCubit` để quản lý trạng thái tải danh sách môn thể thao và xử lý các hành động CRUD (Thêm mới, Chỉnh sửa, Thay đổi trạng thái kích hoạt và Xóa).
  - Xây dựng trang quản lý trực quan `SportManagementPage` với giao diện hiện đại, hỗ trợ nhúng (`isEmbedded`).
  - Thêm Tab thứ 4 (Môn thể thao) vào BottomNavigationBar của `AdminDashboardSection` và bổ sung route `/sport` vào GoRouter.
  - Tối ưu hóa GridView của Tab Tổng quan (Overview) thành lưới 3x2 cân đối gồm 6 thẻ tác vụ nhanh quản lý toàn diện.

- **2026-05-24** - Triển khai Phase 3 Admin: Quản lý Thành viên & Phân quyền (User Management & Authorization) - **Hoàn thành**.

  - Khai báo các dependencies của `user_management_module` trong `pubspec.yaml` bao gồm `flutter_bloc`, `get_it`, `server_module`, `facility_module`, và `equatable`.
  - Định nghĩa thực thể `UserCatalogEntity` kế thừa từ `UserEntity` trong `user_management_module` để lưu trữ thêm trường thông tin số điện thoại (`phone`) và tên cơ sở được gán quản lý (`facilityName`).
  - Xây dựng `AdminUserRepositoryImpl` để liên kết gọi API từ `UserService` của `server_module` và parse chính xác các trường mở rộng sang `UserCatalogEntity`.
  - Xây dựng 4 UseCases quản lý thành viên: `GetUsersUseCase`, `UpdateUserRoleUseCase`, `UpdateUserStatusUseCase`, và `AssignFacilityUseCase`, đồng thời đăng ký GetIt DI.
  - Phát triển `UserManagementCubit` để quản lý trạng thái tải danh sách, tìm kiếm, lọc nhanh và các thao tác cập nhật thông tin thành viên.
  - Xây dựng trang giao diện quản lý thành viên `UserManagementPage` hiện đại hỗ trợ tìm kiếm theo Tên/Email/SĐT, lọc vai trò/trạng thái hoạt động, đổi vai trò người dùng (CUSTOMER/STAFF/ADMIN), gán cơ sở quản lý cho STAFF qua Dropdown và khóa/mở khóa tài khoản.
  - Hợp nhất trang vào `AdminDashboardSection` dưới dạng Tab thứ 5 trong `BottomNavigationBar`. Sửa đổi liên kết card "Quản lý Users" tại Tab Tổng quan để tự chuyển hướng mượt mà sang Tab 5.

- **2026-05-24** - Khắc phục lỗi địa chỉ cơ sở bị trống và gộp thông tin trên phần Quản lý Cơ sở - **Hoàn thành**.

  - Triển khai cơ chế phân tích cú pháp thông minh (**Smart Address Parser**) trong \[facility_repository_impl.dart\](file:///d:/Source/sport_management/sports_management/modules/facility_module/lib/data/repositories/facility_repository_impl.dart) để tự động nhận diện và bóc tách các trường địa chỉ chi tiết (`full`/`fullAddress`) và thành phố (`city`) khi API trả về dưới dạng Map hoặc String Map (chuỗi có cấu trúc `{city: ..., full: ...}`).
  - Ánh xạ chính xác các trường tách biệt lên UI quản trị (giao diện Thêm mới, Chỉnh sửa và Xem danh sách cơ sở).

- **2026-05-24** - Sửa lỗi tính năng gán nhân viên phụ trách cho cơ sở ở cả 2 Tab Cơ sở và Tab Thành viên - **Hoàn thành**.

  - Cập nhật \[facility_repository_impl.dart\](file:///d:/Source/sport_management/sports_management/modules/facility_module/lib/data/repositories/facility_repository_impl.dart) bổ sung helper `_parseOwnerId` để bóc tách chính xác ID của nhân viên phụ trách từ danh sách `staffIds`/`staffs` bất kể định dạng trả về là String hay Map, giúp UI so khớp và hiển thị đúng tên nhân viên phụ trách thay vì "Chưa phân công".
  - Bổ sung trường `facilityId` vào \[UserCatalogEntity\](file:///d:/Source/sport_management/sports_management/modules/user_management_module/lib/domain/entities/user_catalog_entity.dart) và cập nhật \[admin_user_repository_impl.dart\](file:///d:/Source/sport_management/sports_management/modules/user_management_module/lib/data/repositories/admin_user_repository_impl.dart) để tự động parse `facilityId` và `facilityName` thông minh từ API.
  - Cập nhật \[user_management_page.dart\](file:///d:/Source/sport_management/sports_management/modules/user_management_module/lib/presentation/pages/user_management_page.dart) để tự động tra cứu tên cơ sở dựa vào `facilityId` when `facilityName` bị thiếu, đồng thời tự động set giá trị mặc định cho Dropdown trong Dialog gán cơ sở.

- **2026-05-25** - Triển khai Phase 1 Staff: Vận hành & Cấu hình Slot Sân (Court Slot Operation & Config) - **Hoàn thành**.

  - Triển khai UseCase \[UpdateCourtSlotConfigUseCase\](file:///d:/Source/sport_management/sports_management/modules/booking_module/lib/domain/usecases/update_court_slot_config_usecase.dart) trong `booking_module`, đăng ký DI và export.
  - Phát triển \[StaffCourtListingCubit\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/cubit/staff_court_listing/staff_court_listing_cubit.dart) và \[CourtSlotConfigCubit\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/cubit/court_slot_config/court_slot_config_cubit.dart) để xử lý logic tải danh sách và lưu cấu hình slot.
  - Xây dựng giao diện danh sách sân \[StaffCourtSlotConfigPage\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/pages/staff_court_slot_config_page.dart) và trang cấu hình chi tiết \[StaffCourtSlotConfigDetailPage\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/pages/staff_court_slot_config_detail_page.dart) với time picker, dropdown thời lượng và switch khóa/mở slot bảo trì.
  - Đăng ký GoRoutes cho các trang cấu hình slot trong \[home_routes.dart\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/routes/home_routes.dart).
  - Dọn dẹp toàn bộ cảnh báo tĩnh, deprecations (DropdownFormField.value, Switch.activeColor) và unused imports.

- **2026-05-25** - Triển khai Phase 2 Staff: Kiểm soát Đặt sân tại Cơ sở (Local Booking Management) - **Hoàn thành**.

  - Phát triển \[StaffBookingCubit\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/cubit/staff_booking/staff_booking_cubit.dart) và \[StaffBookingState\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/cubit/staff_booking/staff_booking_state.dart) để quản lý danh sách đặt sân của cơ sở Staff phụ trách và cập nhật trạng thái lịch đặt sân.
  - Tích hợp cubit vào \[staff_dashboard_section.dart\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/pages/staff_dashboard_section.dart) để hiển thị động lịch đặt hôm nay tại Tab 0 (Overview) và quản lý lịch chờ duyệt / đã xử lý tại Tab 2 (Đặt lịch).
  - Thêm các hành động kiểm soát lịch đặt: Duyệt đặt sân / Check-in (`CONFIRMED`), Kết thúc ca đấu (`COMPLETED`), và Từ chối đặt sân (`CANCELLED`).
  - Hỗ trợ tính toán doanh thu hôm nay và lượt đặt hôm nay động từ API thực tế.
  - Sửa đổi các cảnh báo tĩnh liên quan đến kiểu dữ liệu `FacilityEntity` và dọn dẹp hàm `_buildTimelineItem` không sử dụng.

- **2026-05-25** - Triển khai Phase 3 Staff: Đối soát & Nhận Thanh toán tại Sân (Local Payment Verification) - **Hoàn thành**.

  - Phát triển \[StaffPaymentCubit\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/cubit/staff_payment/staff_payment_cubit.dart) và \[StaffPaymentState\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/cubit/staff_payment/staff_payment_state.dart) ở `home_module` để xử lý logic tải hóa đơn và đồng bộ hóa với cơ sở đang chọn.
  - Tích hợp cubit vào \[staff_dashboard_section.dart\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/pages/staff_dashboard_section.dart) để tự động hóa Tab 3 (Thu ngân).
  - Triển khai phân loại hóa đơn theo trạng thái (Hóa đơn chờ thu tiền tại quầy và Hóa đơn đã xử lý).
  - Tích hợp đối soát tự động (cross-referencing) khớp nối thông tin `bookingId` với danh sách booking của cơ sở để hiển thị đúng tên Khách hàng và chi tiết Sân đấu trên mỗi hóa đơn.
  - Hỗ trợ hành động xác nhận thanh toán thành công trực tiếp tại quầy (`confirmPaymentSuccess` đổi sang `SUCCESS`).
  - Dọn dẹp cảnh báo tĩnh lints và unused imports.

- **2026-05-25** - Nâng cấp Tab 1 (Vận hành) của Dashboard Staff - **Hoàn thành**.

  - Đăng ký `HomeRoutes.routes` tại root router `AppModuleRouter.router` ở `app_module` để kích hoạt định tuyến cho các chức năng của `home_module` (tránh crash GoRouter).
  - Triển khai màn hình báo cáo thống kê mới \[StaffCourtReportPage\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/pages/staff_court_report_page.dart) ở `home_module` hiển thị doanh thu, ca đấu, phân bổ sân, giờ cao điểm và top khách hàng.
  - Khai báo route `/staff/report` trong \[home_routes.dart\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/routes/home_routes.dart).
  - Tích hợp điều hướng cho 4 phím chức năng tại Tab Vận hành trong \[staff_dashboard_section.dart\](file:///d:/Source/sport_management/sports_management/modules/home_module/lib/presentation/pages/staff_dashboard_section.dart):
    - **Khung giờ sân**: chuyển hướng tới `/staff/court-slot-config`.
    - **Quản lý sân**: chuyển hướng tới `/facility/:facilityId/courts` (truyền ID và Tên cơ sở đang được chọn).
    - **Môn thể thao**: chuyển hướng tới `/sport`.
    - **Báo cáo sân**: chuyển hướng tới `/staff/report` (truyền ID cơ sở).
  - Khắc phục các cảnh báo phân tích tĩnh lints (unused imports và unused local variables).

- **2026-05-25** - Sửa lỗi trùng lặp route `/home` & Sửa lỗi 0 lịch đặt sân tại Dashboard Staff - **Hoàn thành**.

  - Sửa lỗi `GoRouter` crash do trùng lặp cấu hình route `/home` ở cả root `app_router.dart` và phân hệ `home_routes.dart` (loại bỏ khỏi root).
  - Khắc phục lỗi Staff không nhìn thấy lịch đặt sân (hiển thị 0 lịch/0 hóa đơn): Do API `GET /api/v1/booking/` trả về danh sách booking không có đối tượng `court` đầy đủ (dẫn đến `court` bị null và lọc sai cơ sở). Tiêm `CourtRepository` vào `GetBookingHistoryUseCase` để tự động truy vấn danh sách sân bãi và gán đúng `facilityId` vào thực thể `court` trước khi trả về.
  - Sửa lỗi không hiển thị hóa đơn thanh toán trên giao diện Thu ngân của Staff: Do trường `bookingId` không nằm ở root của object payment mà nằm ở `booking.id`. Cập nhật parser trong `PaymentRepositoryImpl` để lấy đúng ID từ `bookingMap?['id']` khi trường root hoặc `_id` bị null.

- **2026-05-27** - Tối ưu hóa Dark Mode, chuẩn hóa Clean Architecture cho Authentication & Notification Modules, và định hướng xây dựng hệ thống thông báo - **Hoàn thành**.

  - Tối ưu hóa giao diện tối trong `admin_booking_supervision_page.dart` (bộ lọc, chi tiết card đặt sân) và `staff_court_slot_config_detail_page.dart` (đồng bộ TimePicker theme, màu card ca đấu).
  - Tái cấu trúc Clean Architecture: Loại bỏ các import trực tiếp `AuthenticationLocalDataSource` khỏi Presentation layers của `home_module` và `payment_module`, chuyển sang dùng `GetLocalUserUseCase` và `ClearLocalSessionUseCase`.
  - Tách biệt hoàn toàn `notification_module` khỏi `server_module` bằng `AppNotificationRepository` và `AppNotificationRepositoryImpl`, đồng thời áp dụng Constructor Injection cho 4 UseCases.
  - Phân tích tĩnh dự án: `flutter analyze` cho kết quả **No issues found!** sạch hoàn toàn.

- **2026-05-27** - Tối ưu Clean Architecture tầng dữ liệu (Data Layer) - **Hoàn thành**.

  - Di chuyển toàn bộ các gọi API của services (`server_module`) và `DioClient` từ `RepositoryImpl` vào các lớp `RemoteDataSource` mới được tạo lập.
  - Áp dụng trên 6 module chính: `user_management_module`, `payment_module`, `review_module`, `notification_module`, `booking_module`, `facility_module`.
  - Đăng ký DI cho tất cả các `RemoteDataSourceImpl` mới và tiêm qua constructor vào các `RepositoryImpl` tương ứng.
  - Chạy `flutter analyze` xác minh thành công: **No issues found!** sạch hoàn toàn.

- **2026-05-27** - Tối ưu hóa Dark Mode toàn diện cho dự án - **Hoàn thành**.

  - Loại bỏ các màu hardcode (trắng, đen, xám) gây lỗi giao diện khi chuyển sang chế độ tối (Dark Mode).
  - Tích hợp theme-aware colors cho các ChoiceChips, ô trạng thái slot, tên cơ sở, mã sân và Card thông tin trong các module `booking_module`, `home_module` và `payment_module`.
  - Cập nhật textTheme của hệ thống cho `labelSmall` có màu sắc thích hợp với cả Light và Dark Mode.
  - Chạy `flutter analyze` xác minh thành công: **No issues found!** sạch hoàn toàn.

- **2026-05-28** - Biên soạn và đồng bộ hóa tài liệu API chi tiết dành cho Admin và Staff (`api-admin-staff.md`) trên cả hai phân hệ Backend và React CRM - **Hoàn thành**.

  - Khảo sát các yêu cầu API, đối soát với `json-in-out_single_line.txt` và `UI_Specification.md`.
  - Thiết lập chi tiết cấu trúc Request/Response và mô tả hoạt động của các phân hệ: Auth & Profile, Booking, Payment, Court Slot Configuration, Catalog, User Management, Notifications, Reviews và Health check.
  - Tạo và cập nhật đồng bộ file `api-admin-staff.md` tại cả hai thư mục làm việc của Backend/Mobile và React CRM.

- **2026-05-29** - Triển khai phân hệ Ghép trận (Matchmaking Module) trên ứng dụng Flutter Mobile - **Hoàn thành**.

  - Xây dựng tầng Domain với các thực thể: `MatchingMemberEntity`, `MatchingSessionEntity` và `MatchQueueEntity`.
  - Triển khai Data Layer bao gồm Models (`MatchingMemberModel`, `MatchingSessionModel`, `MatchQueueModel`) và nguồn dữ liệu từ xa `MatchingRemoteDataSource` hỗ trợ đầy đủ các REST API endpoint thông qua Dio và kết nối realtime thông qua Socket.IO (lắng nghe sự kiện `matching_session_updated`, gửi `join_matching_room`/`leave_matching_room` qua kết nối handshake đính kèm JWT token).
  - Triển khai toàn bộ UseCases và BLoCs (`MatchingBloc`, `MatchQueueBloc`) xử lý logic nghiệp vụ ghép trận tự động và phòng ghép thủ công.
  - Xây dựng giao diện UI/UX hoàn chỉnh:
    - **Khám phá phòng ghép (Hosted Matches Explorer)**: Hiển thị danh sách phòng, bộ lọc tìm kiếm theo bộ môn, cơ sở sân, ngày chơi và thanh tiến trình tuyển thành viên, kèm theo huy hiệu (badge) hiển thị tên Sân cụ thể (ví dụ: Sân số 3) thông qua ánh xạ từ danh sách sân.
    - **Tạo phòng ghép (Create Match)**: Thiết kế bắt buộc lựa chọn Sân chơi cụ thể (Court) thay vì chọn Khu liên hợp (Facility) chung chung. Áp dụng ràng buộc validation chặn submit khi chưa chọn sân bãi và gửi `courtId` bắt buộc trong payload gửi lên backend.
    - **Chi tiết phòng ghép (Match Details)**: Hiển thị thông tin cụ thể, hiển thị thêm thông tin Sân cụ thể, phân biệt vai trò Host (Duyệt/Từ chối, Hủy kèo) và Guest (Xin gia nhập, Rời kèo) và đồng bộ trạng thái realtime qua Socket.IO.
    - **Hàng chờ tự động (Auto-Matchmaking Lobby)**: Form đăng ký nhu cầu tìm trận và giao diện radar sóng âm lan tỏa (Pulsing Radar Wave) đếm thời gian thực tế.
  - Tích hợp điều hướng Deep Linking tự động thông qua xử lý Push Notification từ Firebase Cloud Messaging (FCM) khi nhận payload chứa `"type": "MATCHING"` và `"matchingSessionId"`.
  - Khắc phục hoàn toàn các lỗi phân tích tĩnh (thiếu import, sai kiểu dữ liệu `CourtEntity`, thay thế `print` bằng `debugPrint`, sửa các assertion không cần thiết, và xử lý các warning static lints), chạy `flutter analyze` xác minh dự án sạch hoàn toàn các lỗi biên dịch và cảnh báo cảnh báo tĩnh (chỉ còn lại các thông tin khuyến nghị về deprecations của DropdownFormField.value/Switch.activeColor trong các phiên bản Flutter mới).