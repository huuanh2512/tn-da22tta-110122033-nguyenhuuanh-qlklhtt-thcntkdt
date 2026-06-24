import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Button, Card, Descriptions, Empty, Form, Input, List, Modal, Popconfirm, Result, Space, Spin, Table, Tag, Typography, message } from 'antd';
import { ArrowLeftOutlined, CheckCircleOutlined, CloseCircleOutlined, PauseCircleOutlined, PlayCircleOutlined, ReloadOutlined, StopOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { apiClient } from '../../../../core/network/api_client';
import { authStorage } from '../../../../core/utils/auth_storage';
import { formatVND, minutesToTimeStr } from '../../../../core/utils/formatters';
import { fixedScheduleApi } from '../../data/fixed_schedule_api';
import { FixedScheduleItem } from '../../data/fixed_schedule_types';

const { Title, Text } = Typography;

interface BookingChild {
  id?: string;
  _id?: string;
  courtId?: string;
  court?: any;
  bookingDate?: string;
  booking_date?: string;
  startMinutes?: number;
  start_minutes?: number;
  endMinutes?: number;
  end_minutes?: number;
  totalPrice?: number;
  total_price?: number;
  status?: string;
  paymentStatus?: string;
  payment_status?: string;
  fixedScheduleId?: string;
  fixed_schedule_id?: string;
  [key: string]: any;
}

const noData = 'Chưa có dữ liệu';

const valueText = (...values: any[]) => {
  const value = values.find((item) => item !== undefined && item !== null && item !== '');
  return value === undefined || value === null ? noData : String(value);
};

const formatDate = (value?: string | null) => {
  if (!value) return noData;
  const parsed = dayjs(value);
  return parsed.isValid() ? parsed.format('DD/MM/YYYY') : value;
};

const formatDateTime = (value?: string | null) => {
  if (!value) return noData;
  const parsed = dayjs(value);
  return parsed.isValid() ? parsed.format('HH:mm DD/MM/YYYY') : value;
};

const statusTag = (status?: string) => {
  const colors: Record<string, string> = {
    PENDING_APPROVAL: 'warning',
    ACTIVE: 'success',
    PAUSED: 'processing',
    CANCELLED: 'error',
    REJECTED: 'red',
    EXPIRED: 'default',
  };
  const labels: Record<string, string> = {
    PENDING_APPROVAL: 'Chờ duyệt',
    ACTIVE: 'Đang chạy',
    PAUSED: 'Tạm dừng',
    CANCELLED: 'Đã hủy',
    REJECTED: 'Từ chối',
    EXPIRED: 'Hết hạn',
  };
  return <Tag color={colors[status || ''] || 'default'}>{labels[status || ''] || status || noData}</Tag>;
};

const bookingStatusTag = (status?: string) => {
  const colors: Record<string, string> = {
    PENDING: 'warning',
    CONFIRMED: 'processing',
    COMPLETED: 'success',
    CANCELLED: 'error',
  };
  return <Tag color={colors[status || ''] || 'default'}>{status || noData}</Tag>;
};

const paymentStatusTag = (status?: string) => {
  const colors: Record<string, string> = {
    PENDING: 'warning',
    SUCCESS: 'success',
    FAILED: 'error',
  };
  return <Tag color={colors[status || ''] || 'default'}>{status || noData}</Tag>;
};

const recurringText = (schedule: FixedScheduleItem) => {
  if (schedule.frequency === 'DAILY') return 'Hằng ngày';
  const days = schedule.daysOfWeek || [];
  if (days.length === 0) return noData;
  const labels = ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
  return days.map((day) => labels[day] || `Thứ ${day}`).join(', ');
};

const normalizeBooking = (raw: any): BookingChild => ({
  ...raw,
  id: raw?.id || raw?._id || '',
  courtId: raw?.courtId || raw?.court_id || raw?.court?.id || raw?.court?._id,
  bookingDate: raw?.bookingDate || raw?.booking_date,
  startMinutes: raw?.startMinutes ?? raw?.start_minutes,
  endMinutes: raw?.endMinutes ?? raw?.end_minutes,
  totalPrice: raw?.totalPrice ?? raw?.total_price,
  paymentStatus: raw?.paymentStatus || raw?.payment_status,
  fixedScheduleId: raw?.fixedScheduleId || raw?.fixed_schedule_id,
});

const FixedScheduleDetailPage: React.FC = () => {
  const { fixedScheduleId = '' } = useParams();
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const user = authStorage.getUser();
  const rolePrefix = user?.role === 'ADMIN' ? '/admin' : '/staff';
  const [schedule, setSchedule] = useState<FixedScheduleItem | null>(null);
  const [bookings, setBookings] = useState<BookingChild[]>([]);
  const [loading, setLoading] = useState(true);
  const [bookingLoading, setBookingLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [error, setError] = useState('');
  const [conflictMessage, setConflictMessage] = useState('');

  const loadGeneratedBookings = useCallback(async (current: FixedScheduleItem) => {
    const embedded = current.bookings || [];
    if (embedded.length > 0) {
      setBookings(embedded.map(normalizeBooking));
      return;
    }

    setBookingLoading(true);
    try {
      // TODO: backend booking query currently ignores fixed_schedule_id; keep client-side filter until backend adds it.
      const response = await apiClient.get('/booking', {
        params: { fixed_schedule_id: current.id, fixedScheduleId: current.id, limit: 500 },
      });
      const rawItems = response.data?.items || response.data?.bookings || [];
      setBookings(
        rawItems
          .map(normalizeBooking)
          .filter((booking: BookingChild) => booking.fixedScheduleId === current.id || booking.fixed_schedule_id === current.id)
      );
    } catch {
      setBookings([]);
    } finally {
      setBookingLoading(false);
    }
  }, []);

  const loadDetail = useCallback(async () => {
    if (!fixedScheduleId) {
      setError('Thiếu mã lịch cố định.');
      setLoading(false);
      return;
    }

    setLoading(true);
    setError('');
    setConflictMessage('');
    try {
      const detail = await fixedScheduleApi.getFixedScheduleById(fixedScheduleId);
      setSchedule(detail);
      if (detail) {
        await loadGeneratedBookings(detail);
      } else {
        setBookings([]);
      }
    } catch (e: any) {
      setSchedule(null);
      setBookings([]);
      setError(e.response?.data?.message || e.message || 'Không thể tải chi tiết lịch cố định.');
    } finally {
      setLoading(false);
    }
  }, [fixedScheduleId, loadGeneratedBookings]);

  useEffect(() => {
    loadDetail();
  }, [loadDetail]);

  const customer = useMemo(() => {
    const owner = schedule?.user || schedule?.customer;
    return {
      name: valueText(owner?.profile?.fullName, owner?.profile?.name, owner?.name),
      phone: valueText(owner?.profile?.phone, owner?.phone),
      email: valueText(owner?.email),
    };
  }, [schedule]);

  const runAction = async (action: 'approve' | 'pause' | 'resume' | 'cancel', successText: string) => {
    if (!schedule) return;
    setActionLoading(true);
    setConflictMessage('');
    try {
      if (action === 'approve') await fixedScheduleApi.approveFixedSchedule(schedule.id);
      if (action === 'pause') await fixedScheduleApi.pauseFixedSchedule(schedule.id);
      if (action === 'resume') await fixedScheduleApi.resumeFixedSchedule(schedule.id);
      if (action === 'cancel') await fixedScheduleApi.cancelFixedSchedule(schedule.id);
      message.success(successText);
      await loadDetail();
    } catch (e: any) {
      const errorText = e.response?.data?.message || e.message || 'Thao tác thất bại.';
      setConflictMessage(e.response?.status === 409 ? errorText : '');
      message.error(errorText);
    } finally {
      setActionLoading(false);
    }
  };

  const handleReject = async () => {
    if (!schedule) return;
    const values = await form.validateFields();
    setActionLoading(true);
    try {
      await fixedScheduleApi.rejectFixedSchedule(schedule.id, values.reason);
      message.success('Đã từ chối lịch cố định.');
      setRejectOpen(false);
      form.resetFields();
      await loadDetail();
    } catch (e: any) {
      message.error(e.response?.data?.message || e.message || 'Từ chối lịch cố định thất bại.');
    } finally {
      setActionLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-[360px] flex items-center justify-center">
        <Spin size="large" tip="Đang tải lịch cố định..." />
      </div>
    );
  }

  if (error) {
    return (
      <Result
        status="error"
        title="Không thể tải lịch cố định"
        subTitle={error}
        extra={[
          <Button key="back" icon={<ArrowLeftOutlined />} onClick={() => navigate(-1)}>Quay lại</Button>,
          <Button key="reload" type="primary" icon={<ReloadOutlined />} onClick={loadDetail} className="bg-brand-orange border-none">Tải lại</Button>,
        ]}
      />
    );
  }

  if (!schedule) {
    return <Card><Empty description="Không tìm thấy lịch cố định" /></Card>;
  }

  const childBookingColumns = [
    {
      title: 'Ngày booking',
      key: 'bookingDate',
      render: (_: any, record: BookingChild) => formatDate(record.bookingDate),
    },
    {
      title: 'Khung giờ',
      key: 'time',
      render: (_: any, record: BookingChild) => (
        <span className="font-medium text-indigo-500">
          {record.startMinutes !== undefined ? minutesToTimeStr(record.startMinutes) : noData}
          {' - '}
          {record.endMinutes !== undefined ? minutesToTimeStr(record.endMinutes) : noData}
        </span>
      ),
    },
    {
      title: 'Sân',
      key: 'court',
      render: (_: any, record: BookingChild) => valueText(record.court?.name, schedule.court?.name, record.courtId),
    },
    {
      title: 'Booking',
      dataIndex: 'status',
      key: 'status',
      render: bookingStatusTag,
    },
    {
      title: 'Thanh toán',
      key: 'paymentStatus',
      render: (_: any, record: BookingChild) => paymentStatusTag(record.paymentStatus),
    },
    {
      title: 'Tổng tiền',
      key: 'totalPrice',
      render: (_: any, record: BookingChild) => formatVND(Number(record.totalPrice || 0)),
    },
    {
      title: 'Thao tác',
      key: 'actions',
      render: (_: any, record: BookingChild) => (
        <Button size="small" onClick={() => navigate(`${rolePrefix}/bookings/${record.id}`)}>
          Chi tiết
        </Button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col xl:flex-row xl:items-start xl:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div className="space-y-2">
          <Button icon={<ArrowLeftOutlined />} onClick={() => navigate(-1)} className="rounded-md">Quay lại</Button>
          <div>
            <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>Chi tiết lịch cố định</Title>
            <Text className="text-ink-muted dark:text-ink-darkMuted">
              Mã lịch: <span className="font-semibold text-brand-orange">{schedule.fixedScheduleCode || schedule.id}</span>
            </Text>
          </div>
        </div>

        <Space wrap>
          {schedule.status === 'PENDING_APPROVAL' && (
            <>
              <Button type="primary" icon={<CheckCircleOutlined />} loading={actionLoading} onClick={() => runAction('approve', 'Đã duyệt lịch cố định.')} className="bg-emerald-600 hover:bg-emerald-500 border-none">
                Duyệt
              </Button>
              <Button danger icon={<CloseCircleOutlined />} loading={actionLoading} onClick={() => setRejectOpen(true)}>
                Từ chối
              </Button>
            </>
          )}
          {schedule.status === 'ACTIVE' && (
            <Popconfirm title="Tạm dừng lịch cố định này?" okText="Tạm dừng" cancelText="Đóng" onConfirm={() => runAction('pause', 'Đã tạm dừng lịch cố định.')}>
              <Button icon={<PauseCircleOutlined />} loading={actionLoading}>Tạm dừng</Button>
            </Popconfirm>
          )}
          {schedule.status === 'PAUSED' && (
            <Popconfirm title="Tiếp tục lịch cố định này?" okText="Tiếp tục" cancelText="Đóng" onConfirm={() => runAction('resume', 'Đã tiếp tục lịch cố định.')}>
              <Button type="primary" icon={<PlayCircleOutlined />} loading={actionLoading} className="bg-indigo-600 border-none">Tiếp tục</Button>
            </Popconfirm>
          )}
          {schedule.status !== 'CANCELLED' && schedule.status !== 'REJECTED' && (
            <Popconfirm title="Hủy cả chuỗi lịch cố định này?" okText="Hủy chuỗi" cancelText="Đóng" okButtonProps={{ danger: true }} onConfirm={() => runAction('cancel', 'Đã hủy lịch cố định.')}>
              <Button danger icon={<StopOutlined />} loading={actionLoading}>Hủy chuỗi</Button>
            </Popconfirm>
          )}
        </Space>
      </div>

      {conflictMessage && (
        <Result status="warning" title="Có xung đột lịch" subTitle={conflictMessage} />
      )}

      <Card title="Thông tin lịch" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        <Descriptions column={{ xs: 1, md: 2 }} bordered size="small">
          <Descriptions.Item label="Mã lịch">{schedule.fixedScheduleCode || schedule.id}</Descriptions.Item>
          <Descriptions.Item label="Trạng thái">{statusTag(schedule.status)}</Descriptions.Item>
          <Descriptions.Item label="Người đặt">{customer.name}</Descriptions.Item>
          <Descriptions.Item label="Điện thoại / Email">{customer.phone} / {customer.email}</Descriptions.Item>
          <Descriptions.Item label="Cơ sở">{valueText(schedule.facility?.name, schedule.facilityId)}</Descriptions.Item>
          <Descriptions.Item label="Sân">{valueText(schedule.court?.name, schedule.courtId)}</Descriptions.Item>
          <Descriptions.Item label="Môn thể thao">{valueText(schedule.sport?.name)}</Descriptions.Item>
          <Descriptions.Item label="Loại lịch">{schedule.type === 'MATCHING' || schedule.isMatching ? 'Lịch cố định matching' : 'Lịch cố định thường'}</Descriptions.Item>
          <Descriptions.Item label="Ngày bắt đầu">{formatDate(schedule.startDate)}</Descriptions.Item>
          <Descriptions.Item label="Ngày kết thúc">{schedule.endDate ? formatDate(schedule.endDate) : 'Không giới hạn'}</Descriptions.Item>
          <Descriptions.Item label="Thứ/ngày lặp">{recurringText(schedule)}</Descriptions.Item>
          <Descriptions.Item label="Khung giờ">
            {schedule.startMinutes !== undefined ? minutesToTimeStr(schedule.startMinutes) : valueText(schedule.startTime)}
            {' - '}
            {schedule.endMinutes !== undefined ? minutesToTimeStr(schedule.endMinutes) : valueText(schedule.endTime)}
          </Descriptions.Item>
          <Descriptions.Item label="Ghi chú" span={2}>{valueText(schedule.note)}</Descriptions.Item>
          <Descriptions.Item label="Ngày tạo">{formatDateTime(schedule.createdAt)}</Descriptions.Item>
          <Descriptions.Item label="Cập nhật">{formatDateTime(schedule.updatedAt)}</Descriptions.Item>
          <Descriptions.Item label="Người duyệt">{valueText(typeof schedule.approvedBy === 'object' ? schedule.approvedBy?.name : schedule.approvedBy)}</Descriptions.Item>
          <Descriptions.Item label="Ngày duyệt">{formatDateTime(schedule.approvedAt)}</Descriptions.Item>
          <Descriptions.Item label="Lý do từ chối" span={2}>{valueText(schedule.rejectionReason)}</Descriptions.Item>
        </Descriptions>
      </Card>

      <Card title="Exception dates" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        {(schedule.exceptionDates || []).length === 0 ? (
          <Empty description="Chưa có exception dates" />
        ) : (
          <List
            dataSource={schedule.exceptionDates || []}
            renderItem={(item) => (
              <List.Item>
                <Space wrap>
                  <Tag color="orange">{formatDate(item.date)}</Tag>
                  <span className="font-medium dark:text-white">{valueText(item.type)}</span>
                  <Text className="text-ink-muted dark:text-ink-darkMuted">{valueText(item.reason)}</Text>
                </Space>
              </List.Item>
            )}
          />
        )}
      </Card>

      <Card title="Booking đã sinh" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        {bookings.length === 0 && !bookingLoading ? (
          <Empty description="Chưa có booking con hoặc backend chưa hỗ trợ filter fixed_schedule_id" />
        ) : (
          <Table
            dataSource={bookings}
            columns={childBookingColumns}
            rowKey={(record) => record.id || record._id || `${record.bookingDate}-${record.startMinutes}`}
            loading={bookingLoading}
            pagination={{ pageSize: 8 }}
          />
        )}
      </Card>

      <Card title="Conflict / trạng thái khung giờ" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        {(schedule.conflicts || []).length === 0 ? (
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Chưa có dữ liệu conflict từ backend. TODO: chờ backend endpoint kiểm tra conflict/trạng thái khung giờ nếu cần hiển thị trước khi approve.
          </Text>
        ) : (
          <List
            dataSource={schedule.conflicts || []}
            renderItem={(item: any) => (
              <List.Item>
                <Text>{valueText(item.date, item.bookingDate)} {valueText(item.startTime, item.startMinutes)} - {valueText(item.endTime, item.endMinutes)} {valueText(item.courtName)}</Text>
              </List.Item>
            )}
          />
        )}
      </Card>

      <Modal
        title="Từ chối lịch cố định"
        open={rejectOpen}
        onCancel={() => setRejectOpen(false)}
        onOk={handleReject}
        okText="Từ chối"
        cancelText="Đóng"
        okButtonProps={{ danger: true, loading: actionLoading }}
      >
        <Form form={form} layout="vertical">
          <Form.Item name="reason" label="Lý do từ chối" rules={[{ required: true, message: 'Vui lòng nhập lý do từ chối' }]}>
            <Input.TextArea rows={4} placeholder="Nhập lý do để khách hàng biết cần điều chỉnh gì..." />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default FixedScheduleDetailPage;
