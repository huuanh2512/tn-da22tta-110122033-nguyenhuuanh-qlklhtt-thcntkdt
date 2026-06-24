import React, { useState, useEffect, useCallback } from 'react';
import { Table, Button, Tabs, Tag, message, Typography } from 'antd';
import { CheckOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { useSearchParams } from 'react-router-dom';
import { authStorage, UserSession } from '../../../../core/utils/auth_storage';
import { formatVND, minutesToTimeStr } from '../../../../core/utils/formatters';
import { apiClient } from '../../../../core/network/api_client';

const { Title, Text } = Typography;

interface PaymentItem {
  _id: string;
  userId?: string;
  bookingId: string;
  amount: number;
  method: string;
  transactionId?: string;
  status: 'PENDING' | 'SUCCESS' | 'FAILED';
  createdAt: string;
}

interface BookingItem {
  _id: string;
  courtId: string;
  userId: string;
  bookingDate: string;
  startMinutes: number;
  endMinutes: number;
  totalPrice: number;
  status: string;
}

interface CourtItem {
  _id: string;
  name: string;
  facilityId: string;
}


const StaffCashierPage: React.FC = () => {
  const user = authStorage.getUser();
  const [searchParams] = useSearchParams();
  const [payments, setPayments] = useState<PaymentItem[]>([]);
  const [bookings, setBookings] = useState<BookingItem[]>([]);
  const [courts, setCourts] = useState<CourtItem[]>([]);
  const [users, setUsers] = useState<UserSession[]>([]);
  const [loading, setLoading] = useState(false);
  const [activeTab, setActiveTab] = useState<string>('PENDING');

  // Auto switch tab based on paymentId/bookingId param status
  useEffect(() => {
    const paymentIdParam = searchParams.get('paymentId');
    const bookingIdParam = searchParams.get('bookingId');
    if ((paymentIdParam || bookingIdParam) && payments.length > 0) {
      const match = payments.find(p => p._id === paymentIdParam || p.bookingId === bookingIdParam);
      if (match) {
        setActiveTab(match.status === 'PENDING' ? 'PENDING' : 'SUCCESS');
      }
    }
  }, [payments, searchParams]);


  // Load all payment transactions
  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const resPayments = await apiClient.get('/payment');
      setPayments((resPayments.data.items || []).map((p: any) => ({ ...p, _id: p._id || p.id || '' })));

      const resBookings = await apiClient.get('/booking');
      setBookings((resBookings.data.items || []).map((b: any) => ({ ...b, _id: b._id || b.id || '' })));

      // Fetch courts for facility filtering
      if (user?.facilityId) {
        const resCourts = await apiClient.get('/court', { params: { facilityId: user.facilityId } });
        setCourts((resCourts.data.items || []).map((c: any) => ({ ...c, _id: c._id || c.id || '' })));
      }

      // Fetch users for customer name lookup (ADMIN ONLY)
      if (user?.role === 'ADMIN') {
        const resUsers = await apiClient.get('/user/');
        setUsers(resUsers.data.items || []);
      } else {
        setUsers([]);
      }
    } catch (e: any) {
      message.error('Không thể tải danh sách hóa đơn');
    } finally {
      setLoading(false);
    }
  }, [user?.facilityId, user?.role]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleConfirmPayment = async (paymentId: string) => {
    try {
      await apiClient.put(`/payment/${paymentId}/status`, {
        status: 'SUCCESS',
        transactionId: `CASH_CONFIRM_${Date.now()}`
      });
      message.success('Xác nhận thu tiền mặt thành công!');
      loadData();
    } catch (e: any) {
      message.error('Lỗi khi cập nhật trạng thái hóa đơn');
    }
  };

  // Filter payments — only from bookings at this staff's facility
  const filteredPayments = React.useMemo(() => {
    const paymentIdParam = searchParams.get('paymentId');
    const bookingIdParam = searchParams.get('bookingId');

    return payments
      .filter(p => {
        // Match specific IDs from query parameters if present
        if (paymentIdParam && p._id !== paymentIdParam) return false;
        if (bookingIdParam && p.bookingId !== bookingIdParam) return false;

        const booking = bookings.find(b => b._id === p.bookingId);
        if (!booking) return false;
        
        // Match facility via courts state (from API)
        const isFacilityMatch = courts.length === 0 || courts.some(c => c._id === booking.courtId);
        if (!isFacilityMatch) return false;

        if (activeTab === 'PENDING') return p.status === 'PENDING';
        return p.status === 'SUCCESS' || p.status === 'FAILED';
      })
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }, [payments, bookings, courts, activeTab, searchParams]);

  const columns = [
    {
      title: 'Mã Hóa Đơn',
      dataIndex: '_id',
      key: 'id',
      render: (id: string) => <span className="font-semibold text-brand-orange text-xs">{id}</span>,
    },
    {
      title: 'Khách hàng',
      key: 'customer',
      render: (_: any, record: PaymentItem) => {
        const booking = bookings.find(b => b._id === record.bookingId);
        const recordUser = booking ? ((booking as any).user || (typeof booking.userId === 'object' ? booking.userId : null)) : null;
        const customer = recordUser || users.find(u => u._id === booking?.userId || u.id === booking?.userId);
        return (
          <div className="flex flex-col leading-tight">
            <span className="font-semibold text-sm dark:text-white">
              {customer?.profile?.fullName || customer?.name || 'Khách hàng Quầy'}
            </span>
            <span className="text-xs text-ink-muted dark:text-ink-darkMuted mt-0.5">
              SĐT: {customer?.profile?.phone || customer?.phone || 'N/A'}
            </span>
          </div>
        );
      }
    },
    {
      title: 'Sân & Ca đấu',
      key: 'bookingDetails',
      render: (_: any, record: PaymentItem) => {
        const booking = bookings.find(b => b._id === record.bookingId);
        const court = courts.find(c => c._id === booking?.courtId);
        if (!booking) return <span className="text-ink-subtle">-</span>;
        return (
          <div className="flex flex-col leading-tight">
            <span className="font-medium dark:text-white">{court?.name || booking.courtId}</span>
            <span className="text-xs text-indigo-500 font-semibold mt-0.5">
              {dayjs(booking.bookingDate).format('DD/MM/YYYY')} | {minutesToTimeStr(booking.startMinutes)} - {minutesToTimeStr(booking.endMinutes)}
            </span>
          </div>
        );
      }
    },
    {
      title: 'Số tiền cần thu',
      dataIndex: 'amount',
      key: 'amount',
      render: (amount: number) => <span className="font-bold text-base text-brand-orange">{formatVND(amount)}</span>
    },
    {
      title: 'Hình thức',
      dataIndex: 'method',
      key: 'method',
      render: (method: string) => (
        <Tag color={method === 'BANK_TRANSFER' ? 'blue' : 'orange'}>
          {method === 'BANK_TRANSFER' ? 'Chuyển khoản' : 'Tiền mặt'}
        </Tag>
      )
    },
    {
      title: 'Mã Giao Dịch',
      dataIndex: 'transactionId',
      key: 'txn',
      render: (txn: string) => <span className="text-xs dark:text-white font-mono">{txn || 'Chưa có'}</span>
    },
    {
      title: 'Thời gian tạo',
      dataIndex: 'createdAt',
      key: 'time',
      render: (time: string) => <span className="text-xs text-ink-muted dark:text-ink-darkMuted">{dayjs(time).format('HH:mm DD/MM/YYYY')}</span>
    },
    {
      title: 'Trạng thái',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => (
        <Tag color={status === 'SUCCESS' ? 'success' : status === 'FAILED' ? 'error' : 'warning'} className="border-none font-semibold px-2 py-0.5 rounded">
          {status === 'SUCCESS' ? 'Đã thanh toán' : status === 'FAILED' ? 'Thất bại' : 'Chờ thanh toán'}
        </Tag>
      )
    },
    {
      title: 'Thao tác',
      key: 'actions',
      render: (_: any, record: PaymentItem) => {
        if (record.status === 'PENDING') {
          return (
            <Button
              type="primary"
              size="small"
              icon={<CheckOutlined />}
              onClick={() => handleConfirmPayment(record._id)}
              className="bg-emerald-600 hover:bg-emerald-500 border-none rounded-md font-semibold"
            >
              Thu tiền mặt
            </Button>
          );
        }
        return <span className="text-ink-subtle dark:text-ink-darkSubtle text-xs">-</span>;
      }
    }
  ];

  if (user && user.role === 'STAFF' && !user.facilityId) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[400px] text-center p-6 bg-white dark:bg-surface-dark1 rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm">
        <div className="text-brand-orange text-5xl mb-4">⚠️</div>
        <Title level={4} className="m-0 dark:text-white" style={{ fontWeight: 600 }}>
          Chưa được gán Cơ sở hoạt động
        </Title>
        <Text className="text-ink-muted dark:text-ink-darkMuted mt-2 max-w-md block">
          Tài khoản Nhân viên của bạn chưa được liên kết với cơ sở thể thao nào. Vui lòng liên hệ với Quản trị viên hệ thống để gán cơ sở trước khi thực hiện các nghiệp vụ quản lý.
        </Text>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div>
          <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
            Thu ngân & Thanh toán tại quầy (Cashier)
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Quản lý hóa đơn, kiểm tra giao dịch chuyển khoản trực tuyến và xác nhận thu tiền mặt trực tiếp.
          </Text>
        </div>
      </div>

      <Tabs
        activeKey={activeTab}
        onChange={setActiveTab}
        items={[
          { key: 'PENDING', label: 'Chờ thu tiền tại quầy' },
          { key: 'SUCCESS', label: 'Hóa đơn đã xử lý' }
        ]}
      />

      <Table
        dataSource={filteredPayments}
        columns={columns}
        rowKey="_id"
        loading={loading}
        pagination={{ pageSize: 8 }}
        className="border border-semantic-border/10 dark:border-semantic-borderDark/10 rounded-xl overflow-hidden shadow-sm bg-white dark:bg-surface-dark1"
      />
    </div>
  );
};

export default StaffCashierPage;
