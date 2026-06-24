import React from 'react';
import { Badge, List, Button, Typography, Popover } from 'antd';
import { BellOutlined, MessageOutlined, CalendarOutlined, DollarCircleOutlined, InfoCircleOutlined, TagsOutlined, StarOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { Notification } from '../../domain/entities/notification.entity';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/vi';

dayjs.extend(relativeTime);
dayjs.locale('vi');

const { Text } = Typography;

interface NotificationDropdownProps {
  notifications: Notification[];
  unreadCount: number;
  onMarkRead: (id: string) => void;
  onMarkAllRead: () => void;
  userRole: 'ADMIN' | 'SUPER_ADMIN' | 'STAFF' | 'CUSTOMER';
}

export const NotificationDropdown: React.FC<NotificationDropdownProps> = ({
  notifications,
  unreadCount,
  onMarkRead,
  onMarkAllRead,
  userRole,
}) => {
  const navigate = useNavigate();
  const isAdminRole = userRole === 'ADMIN' || userRole === 'SUPER_ADMIN';

  const getBookingId = (notif: Notification) => {
    const metadata = notif.metadata || {};
    const rawNotif = notif as any;
    const metadataId = notif.type === 'BOOKING' ? metadata.id : undefined;
    return rawNotif.bookingId || rawNotif.booking_id || metadata.bookingId || metadata.booking_id || metadataId || metadata.booking?._id || metadata.booking?.id;
  };

  const getBookingDetailPath = (bookingId: string) => {
    return isAdminRole ? `/admin/bookings/${bookingId}` : `/staff/bookings/${bookingId}`;
  };

  const getFixedScheduleId = (notif: Notification) => {
    const metadata = notif.metadata || {};
    const rawNotif = notif as any;
    return rawNotif.fixedScheduleId || rawNotif.fixed_schedule_id || metadata.fixedScheduleId || metadata.fixed_schedule_id || metadata.scheduleId || metadata.schedule_id;
  };

  const getFixedScheduleDetailPath = (fixedScheduleId: string) => {
    return isAdminRole ? `/admin/fixed-schedules/${fixedScheduleId}` : `/staff/fixed-schedules/${fixedScheduleId}`;
  };

  const getMatchingId = (notif: Notification) => {
    const metadata = notif.metadata || {};
    const rawNotif = notif as any;
    return rawNotif.matchingId
      || rawNotif.matching_id
      || rawNotif.matchingSessionId
      || rawNotif.matching_session_id
      || rawNotif.sessionId
      || rawNotif.session_id
      || metadata.matchingId
      || metadata.matching_id
      || metadata.matchingSessionId
      || metadata.matching_session_id
      || metadata.sessionId
      || metadata.session_id;
  };

  const getMatchingDetailPath = (matchingId: string) => {
    return isAdminRole ? `/admin/matching/${matchingId}` : `/staff/matching/${matchingId}`;
  };

  const getReviewId = (notif: Notification) => {
    const metadata = notif.metadata || {};
    const rawNotif = notif as any;
    return rawNotif.reviewId
      || rawNotif.review_id
      || rawNotif.ratingId
      || rawNotif.rating_id
      || rawNotif.feedbackId
      || rawNotif.feedback_id
      || metadata.reviewId
      || metadata.review_id
      || metadata.ratingId
      || metadata.rating_id
      || metadata.feedbackId
      || metadata.feedback_id;
  };

  const getReviewDetailPath = (reviewId: string) => {
    return isAdminRole ? `/admin/reviews/${reviewId}` : `/staff/reviews/${reviewId}`;
  };

  const handleNotificationClick = async (notif: Notification) => {
    onMarkRead(notif.id);
    
    // Deep Link redirection logic based on type and metadata
    const metadata = notif.metadata || {};
    const bookingId = getBookingId(notif);
    const fixedScheduleId = getFixedScheduleId(notif);
    const matchingId = getMatchingId(notif);
    const reviewId = getReviewId(notif);
    if (fixedScheduleId) {
      navigate(getFixedScheduleDetailPath(fixedScheduleId));
    } else if (matchingId) {
      navigate(getMatchingDetailPath(matchingId));
    } else if (reviewId) {
      navigate(getReviewDetailPath(reviewId));
    } else if ((notif.type === 'BOOKING' || notif.type === 'PAYMENT') && bookingId) {
      navigate(getBookingDetailPath(bookingId));
    } else if (notif.type === 'PAYMENT' && (metadata.paymentId || metadata.id || metadata.bookingId)) {
      const pId = metadata.paymentId || metadata.id;
      const bId = metadata.bookingId;
      navigate(isAdminRole && bId ? `/admin/bookings/${bId}` : `/staff/cashier?paymentId=${pId}&bookingId=${bId}`);
    } else if (notif.type === 'PROMOTION') {
      navigate(isAdminRole ? '/admin/profile' : '/staff/profile');
    } else if (notif.type === 'SYSTEM') {
      navigate(isAdminRole ? '/admin/profile' : '/staff/profile');
    }
  };

  const getIcon = (type: Notification['type']) => {
    switch (type) {
      case 'BOOKING':
        return <CalendarOutlined className="text-emerald-500 text-lg bg-emerald-50 dark:bg-emerald-950/20 p-2 rounded-full" />;
      case 'PAYMENT':
        return <DollarCircleOutlined className="text-orange-500 text-lg bg-orange-50 dark:bg-orange-950/20 p-2 rounded-full" />;
      case 'PROMOTION':
        return <TagsOutlined className="text-violet-500 text-lg bg-violet-50 dark:bg-violet-950/20 p-2 rounded-full" />;
      case 'REVIEW':
        return <StarOutlined className="text-amber-500 text-lg bg-amber-50 dark:bg-amber-950/20 p-2 rounded-full" />;
      case 'SYSTEM':
      default:
        return <InfoCircleOutlined className="text-blue-500 text-lg bg-blue-50 dark:bg-blue-950/20 p-2 rounded-full" />;
    }
  };

  const content = (
    <div className="w-[360px] md:w-[400px]">
      <div className="flex items-center justify-between px-4 py-3 border-b border-semantic-border/10 dark:border-semantic-borderDark/10">
        <Text className="font-bold text-base dark:text-white">Thông báo</Text>
        {unreadCount > 0 && (
          <Button
            type="link"
            size="small"
            onClick={onMarkAllRead}
            className="text-brand-orange hover:text-brand-orange/80 p-0 text-xs font-semibold"
          >
            Đánh dấu đọc tất cả
          </Button>
        )}
      </div>

      <div className="max-h-[360px] overflow-y-auto">
        {notifications.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-10 text-center">
            <MessageOutlined className="text-4xl text-ink-subtle dark:text-ink-darkSubtle mb-2 opacity-55" />
            <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Bạn chưa có thông báo nào</Text>
          </div>
        ) : (
          <List
            dataSource={notifications.slice(0, 10)} // Show top 10 in dropdown
            renderItem={(item) => (
              <List.Item
                onClick={() => handleNotificationClick(item)}
                className={`px-4 py-3 cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800/40 transition-colors flex items-start gap-3 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 ${
                  !item.isRead ? 'bg-brand-orange/5 dark:bg-brand-orange/5' : ''
                }`}
              >
                <div className="shrink-0 mt-0.5">{getIcon(item.type)}</div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between gap-2">
                    <Text className={`text-sm block truncate ${!item.isRead ? 'font-bold dark:text-white' : 'font-medium dark:text-white'}`}>
                      {item.title}
                    </Text>
                    {!item.isRead && (
                      <span className="w-2.5 h-2.5 bg-brand-orange rounded-full shrink-0 mt-1.5" />
                    )}
                  </div>
                  <Text className="text-xs text-ink-muted dark:text-ink-darkMuted block mt-0.5 line-clamp-2">
                    {item.body}
                  </Text>
                  <Text className="text-[10px] text-ink-subtle dark:text-ink-darkSubtle block mt-1">
                    {dayjs(item.createdAt).fromNow()}
                  </Text>
                </div>
              </List.Item>
            )}
          />
        )}
      </div>

      <div className="p-3 border-t border-semantic-border/10 dark:border-semantic-borderDark/10 text-center">
        <Button
          type="text"
          block
          onClick={() => {
            // Redirect based on current user role
            if (isAdminRole) {
              navigate('/admin/notifications');
            } else {
              navigate('/staff/notifications');
            }
          }}
          className="text-brand-orange hover:text-brand-orange/90 font-semibold text-xs"
        >
          Xem tất cả thông báo
        </Button>
      </div>
    </div>
  );

  return (
    <Popover
      content={content}
      trigger="click"
      placement="bottomRight"
      overlayClassName="p-0 rounded-xl overflow-hidden shadow-xl"
    >
      <Badge count={unreadCount} overflowCount={99} size="small" offset={[-2, 6]}>
        <Button
          type="text"
          icon={<BellOutlined className="text-xl" />}
          className="dark:text-white dark:hover:bg-white/10 w-10 h-10 rounded-full flex items-center justify-center shrink-0"
        />
      </Badge>
    </Popover>
  );
};
