import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Button, Card, Col, Descriptions, Divider, Empty, List, Popconfirm, Result, Row, Space, Spin, Tag, Typography, message } from 'antd';
import { ArrowLeftOutlined, CheckCircleOutlined, CloseCircleOutlined, DollarCircleOutlined, PlayCircleOutlined, ReloadOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { getBookingDetailUseCase, updateBookingStatusUseCase } from '../../../../core/di/injection';
import { apiClient } from '../../../../core/network/api_client';
import { authStorage } from '../../../../core/utils/auth_storage';
import { formatVND, minutesToTimeStr } from '../../../../core/utils/formatters';
import { Booking } from '../../domain/entities/booking.entity';

interface PaymentItem {
  _id?: string;
  id?: string;
  bookingId?: string;
  amount?: number;
  method?: string;
  status?: 'PENDING' | 'SUCCESS' | 'FAILED' | string;
  transactionId?: string;
  createdAt?: string;
  paidAt?: string;
  updatedAt?: string;
  [key: string]: any;
}

const { Title, Text } = Typography;

const getObjectId = (value: any): string => {
  if (!value) return '';
  if (typeof value === 'string') return value;
  return value._id || value.id || '';
};

const pickFirst = (...values: any[]): string => {
  const found = values.find((value) => value !== undefined && value !== null && value !== '');
  return found === undefined || found === null ? 'N/A' : String(found);
};

const formatDate = (value?: string) => {
  if (!value) return 'N/A';
  const parsed = dayjs(value);
  return parsed.isValid() ? parsed.format('DD/MM/YYYY') : value;
};

const formatDateTime = (value?: string) => {
  if (!value) return 'N/A';
  const parsed = dayjs(value);
  return parsed.isValid() ? parsed.format('HH:mm DD/MM/YYYY') : value;
};

const bookingStatusTag = (status?: string) => {
  const colors: Record<string, string> = {
    PENDING: 'warning',
    CONFIRMED: 'processing',
    COMPLETED: 'success',
    CANCELLED: 'error',
  };
  const labels: Record<string, string> = {
    PENDING: 'Chờ duyệt',
    CONFIRMED: 'Đã xác nhận',
    COMPLETED: 'Hoàn thành',
    CANCELLED: 'Đã hủy',
  };
  return <Tag color={colors[status || ''] || 'default'}>{labels[status || ''] || status || 'N/A'}</Tag>;
};

const paymentStatusTag = (status?: string) => {
  const colors: Record<string, string> = {
    PENDING: 'warning',
    SUCCESS: 'success',
    FAILED: 'error',
  };
  const labels: Record<string, string> = {
    PENDING: 'Chờ thanh toán',
    SUCCESS: 'Đã thanh toán',
    FAILED: 'Thất bại',
  };
  return <Tag color={colors[status || ''] || 'default'}>{labels[status || ''] || status || 'N/A'}</Tag>;
};

const paymentMethodLabel = (method?: string) => {
  if (!method) return 'N/A';
  if (method === 'CASH') return 'Tiền mặt';
  if (method === 'BANK_TRANSFER') return 'Chuyển khoản';
  return method;
};

const getBookingType = (booking: Booking) => {
  if (booking.fixedScheduleId || booking.fixed_schedule_id || booking.isFixedSchedule || booking.is_fixed_schedule) {
    return 'Fixed schedule';
  }
  if (booking.matchingSessionId || booking.matching_session_id || booking.matchingId || booking.matching_id || booking.matchingSession) {
    return 'Matching';
  }
  return 'Booking thường';
};

const extractPaymentsFromBooking = (booking: Booking | null): PaymentItem[] => {
  if (!booking) return [];
  if (Array.isArray(booking.payments)) return booking.payments;
  if (Array.isArray(booking.payment)) return booking.payment;
  if (booking.payment && typeof booking.payment === 'object') return [booking.payment];
  return [];
};

const BookingDetailPage: React.FC = () => {
  const { bookingId = '' } = useParams();
  const navigate = useNavigate();
  const user = authStorage.getUser();
  const [booking, setBooking] = useState<Booking | null>(null);
  const [payments, setPayments] = useState<PaymentItem[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [actionLoading, setActionLoading] = useState<boolean>(false);
  const [error, setError] = useState<string>('');

  const loadDetail = useCallback(async () => {
    if (!bookingId) {
      setError('Thiếu mã booking.');
      setLoading(false);
      return;
    }

    setLoading(true);
    setError('');
    try {
      const detail = await getBookingDetailUseCase.execute(bookingId);
      setBooking(detail);

      const embeddedPayments = extractPaymentsFromBooking(detail);
      if (embeddedPayments.length > 0) {
        setPayments(embeddedPayments.map((p) => ({ ...p, _id: p._id || p.id || '' })));
      } else {
        try {
          const res = await apiClient.get('/payment', { params: { bookingId } });
          const paymentItems = (res.data?.items || res.data?.payments || [])
            .map((p: any) => ({ ...p, _id: p._id || p.id || '' }))
            .filter((p: PaymentItem) => getObjectId(p.booking || p.bookingId) === bookingId || p.bookingId === bookingId);
          setPayments(paymentItems);
        } catch {
          // TODO: replace this fallback if backend adds a dedicated GET payment-by-booking endpoint.
          setPayments([]);
        }
      }
    } catch (e: any) {
      const status = e.response?.status;
      setBooking(null);
      setError(status === 404 ? 'Không tìm thấy booking.' : (e.response?.data?.message || e.message || 'Không thể tải chi tiết booking.'));
    } finally {
      setLoading(false);
    }
  }, [bookingId]);

  useEffect(() => {
    loadDetail();
  }, [loadDetail]);

  const customer = useMemo(() => {
    const raw = booking?.user || (typeof booking?.userId === 'object' ? booking.userId : null) || booking?.customer;
    const profile = raw?.profile || {};
    return {
      name: pickFirst(profile.fullName, profile.name, raw?.fullName, raw?.name, booking?.customerName, 'Khách hàng'),
      phone: pickFirst(profile.phone, raw?.phone, booking?.customerPhone),
      email: pickFirst(raw?.email, booking?.customerEmail),
    };
  }, [booking]);

  const court = booking?.court || (typeof booking?.courtId === 'object' ? booking.courtId : null);
  const facility = booking?.facility || court?.facility;
  const sport = booking?.sport || court?.sport;
  const mainPayment = payments[0];
  const effectivePaymentStatus = mainPayment?.status || booking?.paymentStatus || booking?.payment_status;
  const effectivePaymentMethod = mainPayment?.method || booking?.paymentMethod || booking?.payment_method;

  const handleStatusAction = async (status: Booking['status']) => {
    if (!booking) return;
    setActionLoading(true);
    try {
      await updateBookingStatusUseCase.execute(booking.id, status);
      message.success('Cập nhật trạng thái booking thành công.');
      await loadDetail();
    } catch (e: any) {
      message.error(e.response?.data?.message || e.message || 'Cập nhật trạng thái thất bại.');
    } finally {
      setActionLoading(false);
    }
  };

  const handleConfirmCashPayment = async (payment: PaymentItem) => {
    const paymentId = payment._id || payment.id;
    if (!paymentId) return;
    setActionLoading(true);
    try {
      await apiClient.put(`/payment/${paymentId}/status`, {
        status: 'SUCCESS',
        transactionId: payment.transactionId || `CASH_CONFIRM_${Date.now()}`,
      });
      message.success('Xác nhận thanh toán tiền mặt thành công.');
      await loadDetail();
    } catch (e: any) {
      message.error(e.response?.data?.message || e.message || 'Xác nhận thanh toán thất bại.');
    } finally {
      setActionLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-[360px] flex items-center justify-center">
        <Spin size="large" tip="Đang tải chi tiết booking..." />
      </div>
    );
  }

  if (error) {
    return (
      <Result
        status="error"
        title="Không thể tải booking"
        subTitle={error}
        extra={[
          <Button key="back" icon={<ArrowLeftOutlined />} onClick={() => navigate(-1)}>
            Quay lại
          </Button>,
          <Button key="retry" type="primary" icon={<ReloadOutlined />} onClick={loadDetail} className="bg-brand-orange border-none">
            Tải lại
          </Button>,
        ]}
      />
    );
  }

  if (!booking) {
    return (
      <Card className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        <Empty description="Không tìm thấy dữ liệu booking" />
      </Card>
    );
  }

  const pendingCashPayments = payments.filter((p) => p.status === 'PENDING' && p.method === 'CASH');

  return (
    <div className="space-y-6">
      <div className="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div className="space-y-2">
          <Button icon={<ArrowLeftOutlined />} onClick={() => navigate(-1)} className="rounded-md">
            Quay lại
          </Button>
          <div>
            <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
              Chi tiết booking
            </Title>
            <Text className="text-ink-muted dark:text-ink-darkMuted">
              Mã booking: <span className="font-semibold text-brand-orange">{booking.id}</span>
            </Text>
          </div>
        </div>

        <Space wrap>
          {booking.status === 'PENDING' && (
            <Button
              type="primary"
              icon={<CheckCircleOutlined />}
              loading={actionLoading}
              onClick={() => handleStatusAction('CONFIRMED')}
              className="bg-emerald-600 hover:bg-emerald-500 border-none"
            >
              Duyệt booking
            </Button>
          )}
          {booking.status === 'CONFIRMED' && (
            <Popconfirm title="Hoàn thành booking này?" okText="Hoàn thành" cancelText="Hủy" onConfirm={() => handleStatusAction('COMPLETED')}>
              <Button type="primary" icon={<PlayCircleOutlined />} loading={actionLoading} className="bg-indigo-600 hover:bg-indigo-500 border-none">
                Hoàn thành
              </Button>
            </Popconfirm>
          )}
          {booking.status !== 'CANCELLED' && booking.status !== 'COMPLETED' && (
            <Popconfirm title="Hủy booking này?" okText="Hủy booking" cancelText="Đóng" okButtonProps={{ danger: true }} onConfirm={() => handleStatusAction('CANCELLED')}>
              <Button danger icon={<CloseCircleOutlined />} loading={actionLoading}>
                Hủy booking
              </Button>
            </Popconfirm>
          )}
          {pendingCashPayments.map((payment) => (
            <Popconfirm
              key={payment._id || payment.id}
              title="Xác nhận đã thu tiền mặt?"
              okText="Xác nhận"
              cancelText="Đóng"
              onConfirm={() => handleConfirmCashPayment(payment)}
            >
              <Button icon={<DollarCircleOutlined />} loading={actionLoading} className="rounded-md">
                Xác nhận tiền mặt
              </Button>
            </Popconfirm>
          ))}
        </Space>
      </div>

      <Row gutter={[16, 16]}>
        <Col xs={24} lg={16}>
          <Card title="Thông tin booking" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 h-full">
            <Descriptions column={{ xs: 1, sm: 2 }} bordered size="small">
              <Descriptions.Item label="Mã booking">{booking.id}</Descriptions.Item>
              <Descriptions.Item label="Loại booking">{getBookingType(booking)}</Descriptions.Item>
              <Descriptions.Item label="Trạng thái booking">{bookingStatusTag(booking.status)}</Descriptions.Item>
              <Descriptions.Item label="Trạng thái thanh toán">{paymentStatusTag(effectivePaymentStatus)}</Descriptions.Item>
              <Descriptions.Item label="Cơ sở">{pickFirst(facility?.name, booking.facilityName, booking.facilityId)}</Descriptions.Item>
              <Descriptions.Item label="Sân">{pickFirst(court?.name, booking.courtName, getObjectId(booking.courtId))}</Descriptions.Item>
              <Descriptions.Item label="Môn thể thao">{pickFirst(sport?.name, booking.sportName)}</Descriptions.Item>
              <Descriptions.Item label="Ngày đặt">{formatDate(booking.bookingDate)}</Descriptions.Item>
              <Descriptions.Item label="Giờ bắt đầu">{booking.startMinutes !== undefined ? minutesToTimeStr(booking.startMinutes) : 'N/A'}</Descriptions.Item>
              <Descriptions.Item label="Giờ kết thúc">{booking.endMinutes !== undefined ? minutesToTimeStr(booking.endMinutes) : 'N/A'}</Descriptions.Item>
              <Descriptions.Item label="Tổng tiền">{formatVND(Number(booking.totalPrice || 0))}</Descriptions.Item>
              <Descriptions.Item label="Phương thức thanh toán">{paymentMethodLabel(effectivePaymentMethod)}</Descriptions.Item>
              <Descriptions.Item label="Ngày tạo">{formatDateTime(booking.createdAt)}</Descriptions.Item>
              <Descriptions.Item label="Cập nhật">{formatDateTime(booking.updatedAt)}</Descriptions.Item>
              <Descriptions.Item label="Ghi chú" span={2}>{pickFirst(booking.note, booking.notes)}</Descriptions.Item>
            </Descriptions>
          </Card>
        </Col>

        <Col xs={24} lg={8}>
          <Card title="Người đặt" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 h-full">
            <div className="space-y-3">
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Họ tên</Text>
                <div className="font-semibold dark:text-white">{customer.name}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Số điện thoại</Text>
                <div className="font-medium dark:text-white">{customer.phone}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Email</Text>
                <div className="font-medium dark:text-white break-all">{customer.email}</div>
              </div>
              <Divider className="my-3" />
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Vai trò xem</Text>
                <div>{user?.role === 'ADMIN' ? <Tag color="blue">Admin toàn hệ thống</Tag> : <Tag color="green">Staff cơ sở</Tag>}</div>
              </div>
            </div>
          </Card>
        </Col>
      </Row>

      <Card title="Thanh toán liên quan" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        {payments.length === 0 ? (
          <Empty description="Chưa có dữ liệu thanh toán cho booking này" />
        ) : (
          <List
            dataSource={payments}
            renderItem={(payment) => (
              <List.Item
                actions={[
                  payment.status === 'PENDING' && payment.method === 'CASH' ? (
                    <Popconfirm
                      key="confirm-cash"
                      title="Xác nhận đã thu tiền mặt?"
                      okText="Xác nhận"
                      cancelText="Đóng"
                      onConfirm={() => handleConfirmCashPayment(payment)}
                    >
                      <Button size="small" icon={<DollarCircleOutlined />} loading={actionLoading}>
                        Xác nhận tiền mặt
                      </Button>
                    </Popconfirm>
                  ) : null,
                ].filter(Boolean)}
              >
                <List.Item.Meta
                  title={
                    <Space wrap>
                      <span className="font-semibold text-brand-orange">{payment._id || payment.id || 'N/A'}</span>
                      {paymentStatusTag(payment.status)}
                      <Tag>{paymentMethodLabel(payment.method)}</Tag>
                    </Space>
                  }
                  description={
                    <div className="grid grid-cols-1 md:grid-cols-4 gap-3 text-xs text-ink-muted dark:text-ink-darkMuted mt-2">
                      <span>Số tiền: <b>{formatVND(Number(payment.amount || 0))}</b></span>
                      <span>Tạo lúc: {formatDateTime(payment.createdAt)}</span>
                      <span>Thanh toán: {formatDateTime(payment.paidAt || payment.updatedAt)}</span>
                      <span>Giao dịch: {payment.transactionId || 'N/A'}</span>
                    </div>
                  }
                />
              </List.Item>
            )}
          />
        )}
      </Card>
    </div>
  );
};

export default BookingDetailPage;
