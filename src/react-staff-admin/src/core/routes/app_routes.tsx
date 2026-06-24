import React, { useState, useEffect } from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { ConfigProvider, theme, Button } from 'antd';
import { getAntdTheme } from '../theme/theme';
import { AUTH_USER_UPDATED_EVENT, authStorage, UserSession } from '../utils/auth_storage';
import { MainLayout } from '../components/main_layout';

// Stub page imports
import LoginPage from '../../features/auth/presentation/pages/login_page';
import ProfilePage from '../../features/auth/presentation/pages/profile_page';

// Admin page imports
import AdminOverviewPage from '../../features/report/presentation/pages/admin_overview_page';
import AdminFacilitiesPage from '../../features/facility/presentation/pages/admin_facilities_page';
import AdminCourtsPage from '../../features/facility/presentation/pages/admin_courts_page';
import AdminSportsPage from '../../features/facility/presentation/pages/admin_sports_page';
import AdminUsersPage from '../../features/user_management/presentation/pages/admin_users_page';
import AdminSupervisionPage from '../../features/booking/presentation/pages/admin_supervision_page';
import BookingDetailPage from '../../features/booking/presentation/pages/booking_detail_page';
import FixedScheduleListPage from '../../features/fixed_schedule/presentation/pages/fixed_schedule_list_page';
import FixedScheduleDetailPage from '../../features/fixed_schedule/presentation/pages/fixed_schedule_detail_page';
import MatchingListPage from '../../features/matching/presentation/pages/matching_list_page';
import MatchingDetailPage from '../../features/matching/presentation/pages/matching_detail_page';
import ReviewListPage from '../../features/review/presentation/pages/review_list_page';
import ReviewDetailPage from '../../features/review/presentation/pages/review_detail_page';

// Staff page imports
import StaffOverviewPage from '../../features/booking/presentation/pages/staff_overview_page';
import StaffBookingsPage from '../../features/booking/presentation/pages/staff_bookings_page';
import StaffCashierPage from '../../features/payment/presentation/pages/staff_cashier_page';
import StaffSlotsPage from '../../features/facility/presentation/pages/staff_slots_page';
import StaffCourtsPage from '../../features/facility/presentation/pages/staff_courts_page';
import StaffSportsPage from '../../features/facility/presentation/pages/staff_sports_page';
import StaffReportPage from '../../features/report/presentation/pages/staff_report_page';

// Notification page imports
import StaffNotificationsPage from '../../features/notification/presentation/pages/staff_notifications_page';
import AdminNotificationsPage from '../../features/notification/presentation/pages/admin_notifications_page';

// Private Route Guard Component
interface GuardProps {
  children: React.ReactNode;
  allowedRoles: ('ADMIN' | 'STAFF')[];
  isDarkMode: boolean;
  setIsDarkMode: (val: boolean) => void;
}

const PrivateGuard: React.FC<GuardProps> = ({ children, allowedRoles, isDarkMode, setIsDarkMode }) => {
  const location = useLocation();
  const user = authStorage.getUser();

  if (!user) {
    return <Navigate to="/sign-in" state={{ from: location }} replace />;
  }

  if (!allowedRoles.includes(user.role as any)) {
    return <Navigate to="/403-forbidden" replace />;
  }

  return (
    <MainLayout user={user} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
      {children}
    </MainLayout>
  );
};

// Public Route Guard Component (Redirect to dashboard if already logged in)
const PublicGuard: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const user = authStorage.getUser();
  if (user) {
    if (user.role === 'ADMIN') return <Navigate to="/admin/overview" replace />;
    if (user.role === 'STAFF') return <Navigate to="/staff/overview" replace />;
  }
  return <>{children}</>;
};

// Simple Forbidden & Page Not Found Components
const ForbiddenPage: React.FC = () => (
  <div className="flex flex-col items-center justify-center min-h-[400px] text-center p-6 bg-canvas dark:bg-canvas-dark">
    <h1 className="text-6xl font-bold text-red-500 mb-4">403</h1>
    <h2 className="text-2xl font-semibold mb-2 dark:text-white">Truy cập bị từ chối</h2>
    <p className="text-ink-muted dark:text-ink-darkMuted mb-6">Tài khoản của bạn không có quyền truy cập vào chức năng này.</p>
    <Button 
      type="primary" 
      onClick={() => {
        authStorage.clear();
        window.location.href = '/sign-in';
      }} 
      className="bg-brand-orange hover:bg-brand-orange/90 border-none rounded-md"
    >
      Đăng nhập lại
    </Button>
  </div>
);

const NotFoundPage: React.FC = () => (
  <div className="flex flex-col items-center justify-center min-h-[400px] text-center p-6 bg-canvas dark:bg-canvas-dark">
    <h1 className="text-6xl font-bold text-brand-orange mb-4">404</h1>
    <h2 className="text-2xl font-semibold mb-2 dark:text-white">Không tìm thấy trang</h2>
    <p className="text-ink-muted dark:text-ink-darkMuted mb-6">Đường dẫn bạn yêu cầu không tồn tại.</p>
    <Button 
      type="primary" 
      onClick={() => {
        window.location.href = '/';
      }} 
      className="bg-brand-orange hover:bg-brand-orange/90 border-none rounded-md"
    >
      Quay lại Trang chủ
    </Button>
  </div>
);

export const AppRoutes: React.FC = () => {
  const [user, setUser] = useState<UserSession | null>(authStorage.getUser());
  const [isDarkMode, setIsDarkMode] = useState<boolean>(() => {
    return localStorage.getItem('theme') === 'dark' || 
      (!localStorage.getItem('theme') && window.matchMedia('(prefers-color-scheme: dark)').matches);
  });

  // Listen to storage changes to keep user session synced
  useEffect(() => {
    const handleStorageChange = () => {
      setUser(authStorage.getUser());
    };
    window.addEventListener('storage', handleStorageChange);
    window.addEventListener(AUTH_USER_UPDATED_EVENT, handleStorageChange);
    // Poll localstorage locally as well for in-app state changes
    const interval = setInterval(() => {
      const stored = authStorage.getUser();
      if (JSON.stringify(stored) !== JSON.stringify(user)) {
        setUser(stored);
      }
    }, 1000);

    return () => {
      window.removeEventListener('storage', handleStorageChange);
      window.removeEventListener(AUTH_USER_UPDATED_EVENT, handleStorageChange);
      clearInterval(interval);
    };
  }, [user]);

  // Synchronize HTML dark class
  useEffect(() => {
    if (isDarkMode) {
      document.documentElement.classList.add('dark');
      localStorage.setItem('theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('theme', 'light');
    }
  }, [isDarkMode]);

  const defaultThemeConfig = getAntdTheme(isDarkMode);
  
  return (
    <ConfigProvider
      theme={{
        ...defaultThemeConfig,
        algorithm: isDarkMode ? theme.darkAlgorithm : theme.defaultAlgorithm
      }}
    >
      <Routes>
        {/* Public Routes */}
        <Route 
          path="/sign-in" 
          element={
            <PublicGuard>
              <LoginPage />
            </PublicGuard>
          } 
        />

        {/* ADMIN Routes */}
        <Route 
          path="/admin/overview" 
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <AdminOverviewPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/admin/facilities" 
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <AdminFacilitiesPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/admin/courts" 
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <AdminCourtsPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/admin/sports" 
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <AdminSportsPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/admin/users" 
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <AdminUsersPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/admin/supervision" 
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <AdminSupervisionPage />
            </PrivateGuard>
          } 
        />
        <Route
          path="/admin/bookings/:bookingId"
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <BookingDetailPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/admin/fixed-schedules"
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <FixedScheduleListPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/admin/fixed-schedules/:fixedScheduleId"
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <FixedScheduleDetailPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/admin/matching"
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <MatchingListPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/admin/matching/:matchingId"
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <MatchingDetailPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/admin/reviews"
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <ReviewListPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/admin/reviews/:reviewId"
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <ReviewDetailPage />
            </PrivateGuard>
          }
        />
        <Route 
          path="/admin/profile" 
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <ProfilePage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/admin/notifications" 
          element={
            <PrivateGuard allowedRoles={['ADMIN']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <AdminNotificationsPage />
            </PrivateGuard>
          } 
        />

        {/* STAFF Routes */}
        <Route 
          path="/staff/overview" 
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <StaffOverviewPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/staff/bookings" 
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <StaffBookingsPage />
            </PrivateGuard>
          } 
        />
        <Route
          path="/staff/bookings/:bookingId"
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <BookingDetailPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/staff/fixed-schedules"
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <FixedScheduleListPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/staff/fixed-schedules/:fixedScheduleId"
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <FixedScheduleDetailPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/staff/matching"
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <MatchingListPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/staff/matching/:matchingId"
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <MatchingDetailPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/staff/reviews"
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <ReviewListPage />
            </PrivateGuard>
          }
        />
        <Route
          path="/staff/reviews/:reviewId"
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <ReviewDetailPage />
            </PrivateGuard>
          }
        />
        <Route 
          path="/staff/cashier" 
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <StaffCashierPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/staff/operations/slots" 
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <StaffSlotsPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/staff/operations/courts" 
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <StaffCourtsPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/staff/operations/sports" 
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <StaffSportsPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/staff/report" 
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <StaffReportPage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/staff/profile" 
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <ProfilePage />
            </PrivateGuard>
          } 
        />
        <Route 
          path="/staff/notifications" 
          element={
            <PrivateGuard allowedRoles={['STAFF']} isDarkMode={isDarkMode} setIsDarkMode={setIsDarkMode}>
              <StaffNotificationsPage />
            </PrivateGuard>
          } 
        />

        {/* Error Pages & Redirects */}
        <Route path="/403-forbidden" element={<ForbiddenPage />} />
        
        {/* Default route routing based on status */}
        <Route 
          path="/" 
          element={
            (() => {
              const currentUser = authStorage.getUser();
              if (currentUser) {
                if (currentUser.role === 'ADMIN') {
                  return <Navigate to="/admin/overview" replace />;
                } else if (currentUser.role === 'STAFF') {
                  return <Navigate to="/staff/overview" replace />;
                } else {
                  authStorage.clear();
                  return <Navigate to="/sign-in" replace />;
                }
              }
              return <Navigate to="/sign-in" replace />;
            })()
          } 
        />
        
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </ConfigProvider>
  );
};
