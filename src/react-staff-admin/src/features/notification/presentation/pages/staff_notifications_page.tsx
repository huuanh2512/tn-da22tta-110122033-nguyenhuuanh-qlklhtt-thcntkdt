import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { Card, Table, Tabs, Button, Tag, Space, Typography, message, Tooltip } from 'antd';
import { CheckOutlined, CalendarOutlined, DollarCircleOutlined, InfoCircleOutlined, TagsOutlined, MessageOutlined, StarOutlined } from '@ant-design/icons';
import { getNotificationsUseCase, markNotificationReadUseCase, markAllNotificationsReadUseCase } from '../../../../core/di/injection';
import { Notification } from '../../domain/entities/notification.entity';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';

const { Title, Text } = Typography;

const StaffNotificationsPage: React.FC = () => {
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [activeTab, setActiveTab] = useState<string>('ALL');

  const loadNotifications = useCallback(async () => {
    setLoading(true);
    try {
      const res = await getNotificationsUseCase.execute();
      setNotifications(res.items || []);
    } catch {
      message.error('Không thể tải lịch sử thông báo');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadNotifications();
  }, [loadNotifications]);

  const handleMarkRead = async (id: string) => {
    try {
      await markNotificationReadUseCase.execute(id);
      message.success('Đã đánh dấu đã đọc');
      loadNotifications();
      // Dispatch a custom storage event to notify header badge
      window.dispatchEvent(new Event('storage'));
    } catch {
      message.error('Lỗi khi cập nhật trạng thái thông báo');
    }
  };

  const handleMarkAllRead = async () => {
    try {
      await markAllNotificationsReadUseCase.execute();
      message.success('Đã đánh dấu tất cả là đã đọc');
      loadNotifications();
      window.dispatchEvent(new Event('storage'));
    } catch {
      message.error('Lỗi khi cập nhật trạng thái thông báo');
    }
  };

  const handleNotificationClick = async (notif: Notification) => {
    if (!notif.isRead) {
      await markNotificationReadUseCase.execute(notif.id);
      window.dispatchEvent(new Event('storage'));
    }

    const metadata = notif.metadata || {};
    const rawNotif = notif as any;
    const metadataId = notif.type === 'BOOKING' ? metadata.id : undefined;
    const bookingId = rawNotif.bookingId || rawNotif.booking_id || metadata.bookingId || metadata.booking_id || metadataId || metadata.booking?._id || metadata.booking?.id;
    const fixedScheduleId = rawNotif.fixedScheduleId || rawNotif.fixed_schedule_id || metadata.fixedScheduleId || metadata.fixed_schedule_id || metadata.scheduleId || metadata.schedule_id;
    const matchingId = rawNotif.matchingId
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
    const reviewId = rawNotif.reviewId
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
    if (fixedScheduleId) {
      navigate(`/staff/fixed-schedules/${fixedScheduleId}`);
    } else if (matchingId) {
      navigate(`/staff/matching/${matchingId}`);
    } else if (reviewId) {
      navigate(`/staff/reviews/${reviewId}`);
    } else if ((notif.type === 'BOOKING' || notif.type === 'PAYMENT') && bookingId) {
      navigate(`/staff/bookings/${bookingId}`);
    } else if (notif.type === 'PAYMENT' && (metadata.paymentId || metadata.id || metadata.bookingId)) {
      const pId = metadata.paymentId || metadata.id;
      const bId = metadata.bookingId;
      navigate(`/staff/cashier?paymentId=${pId}&bookingId=${bId}`);
    } else {
      loadNotifications();
    }
  };

  const getIcon = (type: Notification['type']) => {
    switch (type) {
      case 'BOOKING':
        return <CalendarOutlined className="text-emerald-500 text-lg bg-emerald-50 dark:bg-emerald-950/20 p-2.5 rounded-full shrink-0" />;
      case 'PAYMENT':
        return <DollarCircleOutlined className="text-orange-500 text-lg bg-orange-50 dark:bg-orange-950/20 p-2.5 rounded-full shrink-0" />;
      case 'PROMOTION':
        return <TagsOutlined className="text-violet-500 text-lg bg-violet-50 dark:bg-violet-950/20 p-2.5 rounded-full shrink-0" />;
      case 'REVIEW':
        return <StarOutlined className="text-amber-500 text-lg bg-amber-50 dark:bg-amber-950/20 p-2.5 rounded-full shrink-0" />;
      case 'SYSTEM':
      default:
        return <InfoCircleOutlined className="text-blue-500 text-lg bg-blue-50 dark:bg-blue-950/20 p-2.5 rounded-full shrink-0" />;
    }
  };

  const filteredNotifications = useMemo(() => {
    return notifications.filter((notif) => {
      if (activeTab === 'UNREAD') return !notif.isRead;
      if (activeTab === 'READ') return notif.isRead;
      return true;
    });
  }, [notifications, activeTab]);

  const columns = [
    {
      title: 'Thông báo',
      key: 'notification',
      render: (_: any, record: Notification) => (
        <div 
          onClick={() => handleNotificationClick(record)}
          className="flex items-start gap-3.5 cursor-pointer py-1.5"
        >
          {getIcon(record.type)}
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <span className={`text-sm block ${!record.isRead ? 'font-bold dark:text-white' : 'font-semibold text-ink/90 dark:text-white/90'}`}>
                {record.title}
              </span>
              {!record.isRead && (
                <Tag color="red" className="border-none font-semibold text-[10px] px-1.5 rounded">MỚI</Tag>
              )}
            </div>
            <span className="text-xs text-ink-muted dark:text-ink-darkMuted mt-1 block">
              {record.body}
            </span>
          </div>
        </div>
      )
    },
    {
      title: 'Loại',
      dataIndex: 'type',
      key: 'type',
      width: 140,
      render: (type: Notification['type']) => {
        const colors: Record<string, string> = {
          SYSTEM: 'blue',
          PROMOTION: 'purple',
          BOOKING: 'success',
          PAYMENT: 'orange',
          MATCHING: 'processing',
        };
        const labels: Record<string, string> = {
          SYSTEM: 'Hệ thống',
          PROMOTION: 'Khuyến mãi',
          BOOKING: 'Đặt sân',
          PAYMENT: 'Thanh toán',
          MATCHING: 'Ghép trận',
        };
        return <Tag color={colors[type] || 'default'} className="border-none font-semibold px-2.5 py-0.5 rounded">{labels[type] || type}</Tag>;
      }
    },
    {
      title: 'Thời gian nhận',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 180,
      render: (date: string) => (
        <span className="text-xs text-ink-muted dark:text-ink-darkMuted">
          {dayjs(date).format('HH:mm DD/MM/YYYY')}
        </span>
      )
    },
    {
      title: 'Thao tác',
      key: 'actions',
      width: 100,
      render: (_: any, record: Notification) => (
        <Space size="small">
          {!record.isRead ? (
            <Tooltip title="Đánh dấu đã đọc">
              <Button
                type="text"
                shape="circle"
                icon={<CheckOutlined className="text-emerald-600" />}
                onClick={() => handleMarkRead(record.id)}
                className="hover:bg-emerald-50 dark:hover:bg-emerald-950/20"
              />
            </Tooltip>
          ) : (
            <span className="text-ink-subtle dark:text-ink-darkSubtle text-xs">Đã đọc</span>
          )}
        </Space>
      )
    }
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div>
          <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
            Hộp thư Thông báo
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Xem lịch sử thông báo, cập nhật thời gian thực về hoạt động đặt sân, thanh toán và khuyến mãi tại cơ sở.
          </Text>
        </div>
        {notifications.some(n => !n.isRead) && (
          <Button
            type="primary"
            onClick={handleMarkAllRead}
            className="bg-brand-orange hover:bg-brand-orange/90 border-none font-semibold rounded-md shadow-md"
          >
            Đánh dấu đọc tất cả
          </Button>
        )}
      </div>

      <Tabs
        activeKey={activeTab}
        onChange={setActiveTab}
        items={[
          { key: 'ALL', label: 'Tất cả thông báo' },
          { key: 'UNREAD', label: `Chưa đọc (${notifications.filter(n => !n.isRead).length})` },
          { key: 'READ', label: 'Đã đọc' }
        ]}
      />

      {filteredNotifications.length === 0 ? (
        <Card className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 shadow-sm text-center py-16 bg-white dark:bg-surface-dark1">
          <MessageOutlined className="text-5xl text-ink-subtle dark:text-ink-darkSubtle mb-3 opacity-60" />
          <Title level={5} className="m-0 mb-1 dark:text-white" style={{ fontWeight: 600 }}>Không có thông báo nào</Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Hộp thư của bạn hiện đang trống ở danh mục này.</Text>
        </Card>
      ) : (
        <Table
          dataSource={filteredNotifications}
          columns={columns}
          rowKey="id"
          loading={loading}
          pagination={{ pageSize: 10 }}
          className="border border-semantic-border/10 dark:border-semantic-borderDark/10 rounded-xl overflow-hidden shadow-sm bg-white dark:bg-surface-dark1"
          rowClassName={(record) => !record.isRead ? 'bg-brand-orange/[0.015]' : ''}
        />
      )}
    </div>
  );
};

export default StaffNotificationsPage;
