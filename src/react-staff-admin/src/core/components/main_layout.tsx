import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Layout, Menu, Button, Avatar, Dropdown, Space, App } from 'antd';
import {
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  UserOutlined,
  LogoutOutlined,
  DashboardOutlined,
  CalendarOutlined,
  DollarCircleOutlined,
  SettingOutlined,
  DatabaseOutlined,
  BarChartOutlined,
  TeamOutlined,
  EnvironmentOutlined,
  BulbOutlined,
  SunOutlined,
  BellOutlined,
  StarOutlined
} from '@ant-design/icons';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { authStorage, UserSession } from '../utils/auth_storage';
import { apiClient } from '../network/api_client';
import { socketService } from '../network/socket_service';
import { getNotificationsUseCase, markNotificationReadUseCase, markAllNotificationsReadUseCase } from '../di/injection';
import { Notification } from '../../features/notification/domain/entities/notification.entity';
import { NotificationDropdown } from '../../features/notification/presentation/components/notification_dropdown';

const { Header: AntHeader, Sider, Content } = Layout;

interface MainLayoutProps {
  children: React.ReactNode;
  user: UserSession;
  isDarkMode: boolean;
  setIsDarkMode: (val: boolean) => void;
}

export const MainLayout: React.FC<MainLayoutProps> = ({ children, user, isDarkMode, setIsDarkMode }) => {
  const [collapsed, setCollapsed] = useState(false);
  const [facilityName, setFacilityName] = useState<string>('');
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState<number>(0);
  const realtimeNotificationKeys = useRef<Set<string>>(new Set());
  const brandLogoSrc = `${process.env.PUBLIC_URL}/sport-energy-logo.png`;
  
  const navigate = useNavigate();
  const location = useLocation();
  const { notification: antdNotification } = App.useApp();

  const getBookingIdFromPayload = useCallback((payload: any) => {
    const metadata = payload?.metadata || {};
    const metadataId = payload?.type === 'BOOKING' ? metadata.id : undefined;
    return payload?.bookingId || payload?.booking_id || metadata.bookingId || metadata.booking_id || metadataId || metadata.booking?._id || metadata.booking?.id;
  }, []);

  const getBookingDetailPath = useCallback((bookingId: string) => {
    return user.role === 'ADMIN' ? `/admin/bookings/${bookingId}` : `/staff/bookings/${bookingId}`;
  }, [user.role]);

  const getFixedScheduleIdFromPayload = useCallback((payload: any) => {
    const metadata = payload?.metadata || {};
    return payload?.fixedScheduleId || payload?.fixed_schedule_id || metadata.fixedScheduleId || metadata.fixed_schedule_id || metadata.scheduleId || metadata.schedule_id;
  }, []);

  const getFixedScheduleDetailPath = useCallback((fixedScheduleId: string) => {
    return user.role === 'ADMIN' ? `/admin/fixed-schedules/${fixedScheduleId}` : `/staff/fixed-schedules/${fixedScheduleId}`;
  }, [user.role]);

  const getMatchingIdFromPayload = useCallback((payload: any) => {
    const metadata = payload?.metadata || {};
    return payload?.matchingId
      || payload?.matching_id
      || payload?.matchingSessionId
      || payload?.matching_session_id
      || payload?.sessionId
      || payload?.session_id
      || metadata.matchingId
      || metadata.matching_id
      || metadata.matchingSessionId
      || metadata.matching_session_id
      || metadata.sessionId
      || metadata.session_id;
  }, []);

  const getMatchingDetailPath = useCallback((matchingId: string) => {
    return user.role === 'ADMIN' ? `/admin/matching/${matchingId}` : `/staff/matching/${matchingId}`;
  }, [user.role]);

  const getReviewIdFromPayload = useCallback((payload: any) => {
    const metadata = payload?.metadata || {};
    return payload?.reviewId
      || payload?.review_id
      || payload?.ratingId
      || payload?.rating_id
      || payload?.feedbackId
      || payload?.feedback_id
      || metadata.reviewId
      || metadata.review_id
      || metadata.ratingId
      || metadata.rating_id
      || metadata.feedbackId
      || metadata.feedback_id;
  }, []);

  const getReviewDetailPath = useCallback((reviewId: string) => {
    return user.role === 'ADMIN' ? `/admin/reviews/${reviewId}` : `/staff/reviews/${reviewId}`;
  }, [user.role]);

  // Load initial notification history
  const fetchNotifications = useCallback(async () => {
    try {
      const res = await getNotificationsUseCase.execute();
      const items = res.items || [];
      realtimeNotificationKeys.current = new Set(items.map((item) => `id:${item.id}`));
      setNotifications(items);
      setUnreadCount(res.unreadCount || 0);
    } catch (e) {
      console.error('Failed to fetch notifications:', e);
    }
  }, []);

  // Synthesize beautiful alert chime sound via browser Web Audio API
  const playAlertSound = useCallback(() => {
    try {
      const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
      const oscillator = audioCtx.createOscillator();
      const gainNode = audioCtx.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(audioCtx.destination);

      oscillator.type = 'sine';

      // Play C5 (523.25 Hz)
      oscillator.frequency.setValueAtTime(523.25, audioCtx.currentTime);
      gainNode.gain.setValueAtTime(0.12, audioCtx.currentTime);
      oscillator.start();

      // Play E5 (659.25 Hz) quickly after
      oscillator.frequency.setValueAtTime(659.25, audioCtx.currentTime + 0.12);
      
      // Smooth fade out
      gainNode.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.55);
      oscillator.stop(audioCtx.currentTime + 0.55);
    } catch (err) {
      console.warn('[Notification] Sound playback blocked/unsupported:', err);
    }
  }, []);

  // Mark single notification as read
  const handleMarkRead = async (id: string) => {
    try {
      await markNotificationReadUseCase.execute(id);
      setNotifications((prev) =>
        prev.map((n) => (n.id === id ? { ...n, isRead: true } : n))
      );
      setUnreadCount((prev) => Math.max(0, prev - 1));
    } catch (e) {
      console.error('Failed to mark notification read:', e);
    }
  };

  // Mark all notifications as read
  const handleMarkAllRead = async () => {
    try {
      await markAllNotificationsReadUseCase.execute();
      setNotifications((prev) => prev.map((n) => ({ ...n, isRead: true })));
      setUnreadCount(0);
    } catch (e) {
      console.error('Failed to mark all read:', e);
    }
  };

  // Sync notifications from other pages or custom storage event
  useEffect(() => {
    const handleStorageChange = () => {
      fetchNotifications();
    };
    window.addEventListener('storage', handleStorageChange);
    return () => window.removeEventListener('storage', handleStorageChange);
  }, [fetchNotifications]);

  // Load active facility name for Staff
  useEffect(() => {
    const loadFacilityName = async () => {
      if (!user || user.role !== 'STAFF' || !user.facilityId) return;
      
      if (user.facilityId.length > 24 || !/^[0-9a-fA-F]+$/.test(user.facilityId)) {
        setFacilityName(user.facilityId);
        return;
      }

      try {
        const resFacs = await apiClient.get('/facility');
        const fac = (resFacs.data.items || []).find((f: any) => (f._id || f.id) === user.facilityId);
        setFacilityName(fac?.name || '');
      } catch {
        setFacilityName('');
      }
    };
    loadFacilityName();
    fetchNotifications();
  }, [user, fetchNotifications]);

  // Connect Socket.IO on mount / user changes
  useEffect(() => {
    if (!user) return;

    // Handle when a new notification is pushed in real-time
    const handleRealtimeNotification = (notifData: any) => {
      const notificationId = notifData.id || notifData._id;
      const fallbackKey = [
        notifData.type || 'SYSTEM',
        notifData.title || '',
        notifData.body || notifData.content || '',
        notifData.createdAt || '',
        JSON.stringify(notifData.metadata || {}),
      ].join('|');
      const realtimeKey = notificationId ? `id:${notificationId}` : `fallback:${fallbackKey}`;

      if (realtimeNotificationKeys.current.has(realtimeKey)) {
        console.log('[Socket] Skipped duplicate notification:', realtimeKey);
        return;
      }
      realtimeNotificationKeys.current.add(realtimeKey);

      const newNotif: Notification = {
        id: notificationId || `socket_${Date.now()}`,
        userId: notifData.userId || user._id || user.id || '',
        title: notifData.title || 'Thông báo mới',
        body: notifData.body || notifData.content || '',
        type: notifData.type || 'SYSTEM',
        isRead: false,
        createdAt: notifData.createdAt || new Date().toISOString(),
        metadata: notifData.metadata || {},
      };

      // Play audio chime alert
      playAlertSound();

      // Show Ant Design Toast Notification
      antdNotification.open({
        message: <span className="font-bold text-sm text-brand-orange">{newNotif.title}</span>,
        description: <span className="text-xs text-ink-muted dark:text-ink-darkMuted">{newNotif.body}</span>,
        icon: <BellOutlined className="text-brand-orange" />,
        placement: 'topRight',
        duration: 5,
        btn: (
          <Button
            type="primary"
            size="small"
            onClick={() => {
              antdNotification.destroy();
              handleMarkRead(newNotif.id);
              const metadata = newNotif.metadata || {};
              const bookingId = getBookingIdFromPayload(newNotif);
              const fixedScheduleId = getFixedScheduleIdFromPayload(newNotif);
              const matchingId = getMatchingIdFromPayload(newNotif);
              const reviewId = getReviewIdFromPayload(newNotif);
              if (fixedScheduleId) {
                navigate(getFixedScheduleDetailPath(fixedScheduleId));
              } else if (matchingId) {
                navigate(getMatchingDetailPath(matchingId));
              } else if (reviewId) {
                navigate(getReviewDetailPath(reviewId));
              } else if ((newNotif.type === 'BOOKING' || newNotif.type === 'PAYMENT') && bookingId) {
                navigate(getBookingDetailPath(bookingId));
              } else if (newNotif.type === 'PAYMENT' && (metadata.paymentId || metadata.id)) {
                navigate(`/staff/cashier?paymentId=${metadata.paymentId || metadata.id}`);
              } else {
                navigate(user.role === 'ADMIN' ? '/admin/notifications' : '/staff/notifications');
              }
            }}
            className="bg-brand-orange hover:bg-brand-orange/90 border-none rounded text-xs"
          >
            Xem ngay
          </Button>
        ),
      });

      // Update state
      setNotifications((prev) => {
        if (prev.some((item) => item.id === newNotif.id)) return prev;
        return [newNotif, ...prev];
      });
      setUnreadCount((prev) => prev + 1);
    };

    // Handle when a new booking is created at quầy / online
    const handleRealtimeBooking = (bookingData: any) => {
      playAlertSound();
      antdNotification.open({
        message: <span className="font-bold text-sm text-brand-orange">Lịch đặt sân mới! ⚽</span>,
        description: (
          <span className="text-xs text-ink-muted dark:text-ink-darkMuted">
            Có yêu cầu đặt sân mới tại cơ sở {bookingData.facilityName || ''} đang chờ duyệt.
          </span>
        ),
        icon: <CalendarOutlined className="text-brand-orange" />,
        placement: 'topRight',
        duration: 6,
        btn: (
          <Button
            type="primary"
            size="small"
            onClick={() => {
              antdNotification.destroy();
              const bookingId = getBookingIdFromPayload(bookingData);
              navigate(bookingId ? getBookingDetailPath(bookingId) : (user.role === 'ADMIN' ? '/admin/supervision' : '/staff/bookings'));
            }}
            className="bg-brand-orange hover:bg-brand-orange/90 border-none rounded text-xs"
          >
            Duyệt ngay
          </Button>
        ),
      });

      fetchNotifications();
    };

    // Connect socket
    socketService.connect(handleRealtimeNotification, handleRealtimeBooking);

    return () => {
      socketService.disconnect();
    };
  }, [user, playAlertSound, antdNotification, navigate, fetchNotifications, getBookingIdFromPayload, getBookingDetailPath, getFixedScheduleIdFromPayload, getFixedScheduleDetailPath, getMatchingIdFromPayload, getMatchingDetailPath, getReviewIdFromPayload, getReviewDetailPath]);

  const handleLogout = () => {
    authStorage.clear();
    socketService.disconnect();
    navigate('/sign-in');
  };

  // Menu items based on role
  const menuItems = React.useMemo(() => {
    if (user.role === 'ADMIN') {
      return [
        {
          key: '/admin/overview',
          icon: <DashboardOutlined />,
          label: <Link to="/admin/overview">Tổng quan</Link>,
        },
        {
          key: '/admin/facilities',
          icon: <EnvironmentOutlined />,
          label: <Link to="/admin/facilities">Cơ sở / Khu phức hợp</Link>,
        },
        {
          key: '/admin/courts',
          icon: <DatabaseOutlined />,
          label: <Link to="/admin/courts">Sân đấu & Đơn giá</Link>,
        },
        {
          key: '/admin/sports',
          icon: <SettingOutlined />,
          label: <Link to="/admin/sports">Danh mục Môn thể thao</Link>,
        },
        {
          key: '/admin/users',
          icon: <TeamOutlined />,
          label: <Link to="/admin/users">Quản lý Thành viên</Link>,
        },
        {
          key: '/admin/supervision',
          icon: <BarChartOutlined />,
          label: <Link to="/admin/supervision">Giám sát hệ thống</Link>,
        },
        {
          key: '/admin/fixed-schedules',
          icon: <CalendarOutlined />,
          label: <Link to="/admin/fixed-schedules">Lịch cố định</Link>,
        },
        {
          key: '/admin/matching',
          icon: <TeamOutlined />,
          label: <Link to="/admin/matching">Ghép trận</Link>,
        },
        {
          key: '/admin/reviews',
          icon: <StarOutlined />,
          label: <Link to="/admin/reviews">Đánh giá</Link>,
        },
        {
          key: '/admin/notifications',
          icon: <BellOutlined />,
          label: <Link to="/admin/notifications">Quản lý thông báo</Link>,
        },
        {
          key: '/admin/profile',
          icon: <UserOutlined />,
          label: <Link to="/admin/profile">Hồ sơ cá nhân</Link>,
        }
      ];
    } else if (user.role === 'STAFF') {
      return [
        {
          key: '/staff/overview',
          icon: <DashboardOutlined />,
          label: <Link to="/staff/overview">Tổng quan & Sơ đồ</Link>,
        },
        {
          key: '/staff/bookings',
          icon: <CalendarOutlined />,
          label: <Link to="/staff/bookings">Quản lý Lịch đặt</Link>,
        },
        {
          key: '/staff/fixed-schedules',
          icon: <CalendarOutlined />,
          label: <Link to="/staff/fixed-schedules">Lịch cố định</Link>,
        },
        {
          key: '/staff/matching',
          icon: <TeamOutlined />,
          label: <Link to="/staff/matching">Ghép trận</Link>,
        },
        {
          key: '/staff/reviews',
          icon: <StarOutlined />,
          label: <Link to="/staff/reviews">Đánh giá</Link>,
        },
        {
          key: '/staff/cashier',
          icon: <DollarCircleOutlined />,
          label: <Link to="/staff/cashier">Thu ngân tại quầy</Link>,
        },
        {
          key: 'operations',
          icon: <SettingOutlined />,
          label: 'Vận hành sân',
          children: [
            {
              key: '/staff/operations/slots',
              label: <Link to="/staff/operations/slots">Cấu hình ca đấu (Slots)</Link>,
            },
            {
              key: '/staff/operations/courts',
              label: <Link to="/staff/operations/courts">Danh sách Sân đấu</Link>,
            },
            {
              key: '/staff/operations/sports',
              label: <Link to="/staff/operations/sports">Môn thể thao</Link>,
            }
          ]
        },
        {
          key: '/staff/report',
          icon: <BarChartOutlined />,
          label: <Link to="/staff/report">Báo cáo doanh thu</Link>,
        },
        {
          key: '/staff/notifications',
          icon: <BellOutlined />,
          label: <Link to="/staff/notifications">Thông báo</Link>,
        },
        {
          key: '/staff/profile',
          icon: <UserOutlined />,
          label: <Link to="/staff/profile">Hồ sơ & Cơ sở</Link>,
        }
      ];
    }
    return [];
  }, [user]);

  // Find active key
  const getSelectedKeys = () => {
    return [location.pathname];
  };

  const getOpenKeys = () => {
    if (location.pathname.startsWith('/staff/operations/')) {
      return ['operations'];
    }
    return [];
  };

  const userMenuItems = [
    {
      key: 'profile',
      label: 'Hồ sơ cá nhân',
      icon: <UserOutlined />,
      onClick: () => navigate(user.role === 'ADMIN' ? '/admin/profile' : '/staff/profile'),
    },
    {
      type: 'divider' as const,
    },
    {
      key: 'logout',
      label: 'Đăng xuất',
      icon: <LogoutOutlined />,
      danger: true,
      onClick: handleLogout,
    },
  ];

  return (
    <Layout className="min-h-screen">
      <Sider
        trigger={null}
        collapsible
        collapsed={collapsed}
        theme={isDarkMode ? 'dark' : 'light'}
        className="shadow-md border-r border-semantic-border/20 dark:border-semantic-borderDark/20"
        width={256}
        style={{
          position: 'fixed',
          left: 0,
          top: 0,
          bottom: 0,
          height: '100vh',
          overflow: 'hidden',
          zIndex: 100,
        }}
      >
        <div className="p-4 flex items-center justify-center border-b border-semantic-border/10 dark:border-semantic-borderDark/10">
          <div className="flex items-center gap-2 overflow-hidden">
            <img
              src={brandLogoSrc}
              alt="Sport Energy logo"
              className="w-9 h-9 rounded-lg object-contain shrink-0 shadow-sm"
            />
            {!collapsed && (
              <span className="font-sans font-bold text-lg tracking-tight truncate dark:text-white">
                Sport Energy
              </span>
            )}
          </div>
        </div>
        
        <Menu
          mode="inline"
          selectedKeys={getSelectedKeys()}
          defaultOpenKeys={getOpenKeys()}
          items={menuItems}
          className="border-none mt-2"
          theme={isDarkMode ? 'dark' : 'light'}
          style={{
            height: 'calc(100vh - 66px)',
            overflowY: 'auto',
            overflowX: 'hidden',
          }}
        />
      </Sider>

      <Layout
        style={{
          marginLeft: collapsed ? 80 : 256,
          minHeight: '100vh',
          transition: 'margin-left 0.2s',
        }}
      >
        <AntHeader className="sticky top-0 z-40 p-0 flex items-center justify-between shadow-sm bg-white dark:bg-surface-dark1 border-b border-semantic-border/20 dark:border-semantic-borderDark/20 pr-6">
          <div className="flex items-center">
            <Button
              type="text"
              icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
              onClick={() => setCollapsed(!collapsed)}
              className="w-16 h-16 text-base dark:text-white hover:bg-black/5 dark:hover:bg-white/5"
            />
            {facilityName && (
              <div className="hidden sm:flex items-center gap-2 bg-brand-orange/10 px-3 py-1 rounded-md text-brand-orange font-medium text-sm">
                <EnvironmentOutlined />
                <span>Cơ sở: {facilityName}</span>
              </div>
            )}
          </div>

          <Space size="large" align="center">
            {/* Real-time Notification Dropdown */}
            <NotificationDropdown
              notifications={notifications}
              unreadCount={unreadCount}
              onMarkRead={handleMarkRead}
              onMarkAllRead={handleMarkAllRead}
              userRole={user.role}
            />

            {/* Dark Mode Switcher */}
            <Button
              type="text"
              icon={isDarkMode ? <SunOutlined /> : <BulbOutlined />}
              onClick={() => setIsDarkMode(!isDarkMode)}
              className="text-base dark:text-white dark:hover:bg-white/10 w-10 h-10 rounded-full flex items-center justify-center"
              title="Đổi giao diện Sáng/Tối"
            />

            {/* User Dropdown */}
            <Dropdown menu={{ items: userMenuItems }} placement="bottomRight" trigger={['click']}>
              <div className="flex items-center gap-2 cursor-pointer hover:bg-black/5 dark:hover:bg-white/5 p-2 rounded-md transition-colors">
                <Avatar 
                  src={user.profile?.avatar || `https://api.dicebear.com/7.x/adventurer/svg?seed=${user._id}`} 
                  icon={<UserOutlined />} 
                  className="bg-brand-orange"
                />
                <div className="hidden md:flex flex-col text-left leading-none">
                  <span className="font-semibold text-sm dark:text-white">
                    {user.profile?.fullName || 'Nhân viên'}
                  </span>
                  <span className="text-xs text-ink-muted dark:text-ink-darkMuted mt-0.5">
                    {user.role === 'ADMIN' ? 'Quản trị viên' : 'Nhân viên'}
                  </span>
                </div>
              </div>
            </Dropdown>
          </Space>
        </AntHeader>

        <Content className="m-6 p-6 min-h-[280px] bg-white dark:bg-surface-dark1 rounded-xl shadow-sm border border-semantic-border/10 dark:border-semantic-borderDark/10 overflow-y-auto">
          {children}
        </Content>
      </Layout>
    </Layout>
  );
};
