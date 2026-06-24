# 🚀 Sports Management Project Roadmap

## 📌 Project Overview
**Sport Energy** is a comprehensive sports facility management system built with Flutter. It follows a **Modular Clean Architecture** to ensure scalability, maintainability, and clear separation of concerns.

- **Objective:** Provide a seamless experience for Customers to book courts, Staff to manage operations, and Admins to oversee the entire system.
- **Key Features:** Role-based dashboards, real-time booking, payment integration, and automated notifications.

---

## 🏗️ Architecture & Modules

### 🏢 Core Modules (`/modules`)
- **`server_module`**: The data layer handling all API communications (Dio), Data Models, Entities, and Repositories.
- **`app_module`**: Shared UI components, base classes, and utility widgets used across all modules.
- **`authentication_module`**: Manages User Identity (Sign In, Sign Up, Email Verification, Password Reset).
- **`home_module`**: The heart of the app, providing role-specific dashboards (Admin, Staff, Customer) and shell navigation.
- **`booking_module`**: Handles the full booking lifecycle—from searching and selecting slots to viewing history.
- **`facility_module`**: Management of Facilities, Courts, Sports categories, and operational time slots.
- **`payment_module`**: Manages invoices, transactions, and payment status tracking.
- **`user_management_module`**: Admin-only module for managing users, roles, and user-specific notifications.

### 🔌 Integration & Routing
- **Routing:** Centralized navigation using `GoRouter` in `lib/router/`.
- **Dependency Injection:** Powered by `GetIt` in `lib/injection/`.
- **State Management:** Standardized using `Flutter BLoC`.
- **Firebase:** Integrated for Push Notifications and Authentication services.

---

## 🚦 Current Status (v1.0.0)

### ✅ Completed
- [x] Modular project structure and foundation.
- [x] Clean Architecture implementation in `server_module`.
- [x] Base UI Kit and Theme configuration.
- [x] Authentication flow (Sign In, Sign Up, Email Verification).
- [x] Role-based Dashboard navigation and Guards.
- [x] Basic Facility and Court management UI.
- [x] Customer booking flow (Selection -> Detail -> History).
- [x] Admin User Management and Payment listing.
- [x] Firebase Core and Messaging setup.

### 🚧 In Progress
- [ ] Finalizing Staff operational workflows (Court Slot Config).
- [ ] Offline payment confirmation logic for Staff.
- [ ] Detailed notification interaction handling (Deep linking from NotifyPage).
- [ ] Polishing UI/UX across all dashboards for consistency.

---

## 📅 Roadmap & Future Tasks

### Phase 1: Stability & Polish (Q2 2024)
- [ ] **Fix "Dead Screens":** Integrate `UserInfoPage` into the router and navigation flow.
- [ ] **Data Validation:** Implement comprehensive error handling and user feedback for all API interactions.
- [ ] **Performance:** Optimize image loading (CachedNetworkImage) and list rendering.
- [ ] **Unit Testing:** Increase coverage for Repositories and BLoCs in `server_module` and `booking_module`.

### Phase 2: Feature Expansion (Q3 2024)
- [ ] **Advanced Analytics:** Add reporting charts for Admins (Revenue, Booking trends).
- [ ] **Voucher & Promotion System:** Implement the `_VoucherPage` placeholders with real logic.
- [ ] **In-App Notifications:** Real-time notification tray with read/unread status syncing.
- [ ] **Service Integration:** Develop the `_ServicesPage` for additional facility services (e.g., equipment rental).

### Phase 3: Scaling & Optimization (Q4 2024)
- [ ] **Multi-language Support:** Full localization using `intl`.
- [ ] **Dark Mode:** Complete the dark theme implementation in `AppTheme`.
- [ ] **Web Support:** Adapt layouts for a desktop/web-based Admin panel.
- [ ] **Automated CI/CD:** Set up GitHub Actions for automated testing and deployment to Firebase App Distribution.

---

## 🛠️ Technical Debt & Maintenance
- **Refactoring:** Standardize BLoC naming conventions and event/state structures.
- **Documentation:** Maintain `manhinh.md` and `server_module.md` as the project evolves.
- **Dependencies:** Regularly audit `pubspec.yaml` for updates and security patches.

---
*Last Updated: May 23, 2026*
