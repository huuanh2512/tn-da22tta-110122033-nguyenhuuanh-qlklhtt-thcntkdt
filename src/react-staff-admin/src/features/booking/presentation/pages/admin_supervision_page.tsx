import React, { useState, useEffect } from 'react';
import { Table, Tabs, Input, Tag, Card, Typography, DatePicker, Row, Col, Statistic, Space, Button, Tooltip } from 'antd';
import { SearchOutlined, DollarOutlined, CalendarOutlined, TransactionOutlined, EyeOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { useNavigate } from 'react-router-dom';
import { MockBooking, MockPayment, MockCourt, MockFacility } from '../../../../core/network/mock_db';
import { formatVND, minutesToTimeStr } from '../../../../core/utils/formatters';
import { apiClient } from '../../../../core/network/api_client';
import { UserSession } from '../../../../core/utils/auth_storage';

const { Search } = Input;
const { Title, Text } = Typography;

const AdminSupervisionPage: React.FC = () => {
  const navigate = useNavigate();
  const [bookings, setBookings] = useState<MockBooking[]>([]);
  const [payments, setPayments] = useState<MockPayment[]>([]);
  const [courts, setCourts] = useState<MockCourt[]>([]);
  const [facilities, setFacilities] = useState<MockFacility[]>([]);
  const [users, setUsers] = useState<UserSession[]>([]);
  
  const [loading, setLoading] = useState(false);
  const [activeTab, setActiveTab] = useState<string>('BOOKINGS');
  const [searchText, setSearchText] = useState<string>('');
  const [selectedDate, setSelectedDate] = useState<string>('');

  const loadData = async () => {
    setLoading(true);
    try {
      const resBookings = await apiClient.get('/booking');
      setBookings(resBookings.data.items || []);

      const resPayments = await apiClient.get('/payment');
      setPayments(resPayments.data.items || []);

      const resCourts = await apiClient.get('/court');
      setCourts(resCourts.data.items || []);

      const resFac = await apiClient.get('/facility');
      setFacilities(resFac.data.items || []);

      const resUsers = await apiClient.get('/user/');
      setUsers(resUsers.data.items || []);
    } catch (e: any) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // System financial stats
  const totalStats = React.useMemo(() => {
    const successPayments = payments.filter(p => p.status === 'SUCCESS');
    const totalRevenue = successPayments.reduce((sum, p) => sum + p.amount, 0);
    const totalBookingsCount = bookings.filter(b => b.status !== 'CANCELLED').length;
    
    // Count active cash payments pending
    const pendingCash = payments.filter(p => p.status === 'PENDING').reduce((sum, p) => sum + p.amount, 0);

    return {
      revenue: totalRevenue,
      bookingsCount: totalBookingsCount,
      pendingCash
    };
  }, [bookings, payments]);

  // Bookings list filtered
  const filteredBookings = React.useMemo(() => {
    return bookings
      .filter(b => {
        if (selectedDate && b.bookingDate !== selectedDate) return false;
        
        if (searchText) {
          const user = users.find(u => u._id === b.userId || u.id === b.userId);
          const userName = user?.profile?.fullName?.toLowerCase() || '';
          const userPhone = user?.profile?.phone || '';
          const court = courts.find(c => c._id === b.courtId);
          const courtName = court?.name.toLowerCase() || '';
          const query = searchText.toLowerCase();

          return b._id.toLowerCase().includes(query) || userName.includes(query) || userPhone.includes(query) || courtName.includes(query);
        }
        return true;
      })
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }, [bookings, searchText, selectedDate, users, courts]);

  // Payments list filtered
  const filteredPayments = React.useMemo(() => {
    return payments
      .filter(p => {
        if (searchText) {
          const booking = bookings.find(b => b._id === p.bookingId);
          const user = users.find(u => u._id === booking?.userId || u.id === booking?.userId);
          const userName = user?.profile?.fullName?.toLowerCase() || '';
          const txnId = p.transactionId.toLowerCase();
          const query = searchText.toLowerCase();

          return p._id.toLowerCase().includes(query) || userName.includes(query) || txnId.includes(query);
        }
        return true;
      })
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }, [payments, bookings, searchText, users]);

  // Columns definitions
  const bookingColumns = [
    {
      title: 'Mã đặt lịch',
      dataIndex: '_id',
      key: 'id',
      render: (id: string) => <span className="font-semibold text-brand-orange text-xs">{id}</span>
    },
    {
      title: 'Khách hàng',
      key: 'customer',
      render: (_: any, record: MockBooking) => {
        const user = users.find(u => u._id === record.userId || u.id === record.userId);
        return (
          <div className="flex flex-col leading-tight">
            <span className="font-semibold text-sm dark:text-white">{user?.profile?.fullName || 'Khách vãng lai'}</span>
            <span className="text-xs text-ink-muted dark:text-ink-darkMuted mt-0.5">{user?.profile?.phone || 'N/A'}</span>
          </div>
        );
      }
    },
    {
      title: 'Cơ sở & Sân',
      key: 'facility_court',
      render: (_: any, record: MockBooking) => {
        const court = courts.find(c => c._id === record.courtId);
        const fac = facilities.find(f => f._id === court?.facilityId);
        return (
          <div className="flex flex-col leading-tight">
            <span className="font-medium dark:text-white">{court?.name}</span>
            <span className="text-xs text-brand-orange mt-0.5">{fac?.name}</span>
          </div>
        );
      }
    },
    {
      title: 'Khung giờ',
      key: 'time',
      render: (_: any, record: MockBooking) => (
        <div className="flex flex-col leading-tight">
          <span className="font-medium text-indigo-500">{dayjs(record.bookingDate).format('DD/MM/YYYY')}</span>
          <span className="text-xs text-ink-muted mt-0.5">{minutesToTimeStr(record.startMinutes)} - {minutesToTimeStr(record.endMinutes)}</span>
        </div>
      )
    },
    {
      title: 'Thành tiền',
      dataIndex: 'totalPrice',
      key: 'totalPrice',
      render: (price: number) => <span className="font-bold dark:text-white">{formatVND(price)}</span>
    },
    {
      title: 'Trạng thái',
      dataIndex: 'status',
      key: 'status',
      render: (status: MockBooking['status']) => {
        const colors = {
          PENDING: 'warning',
          CONFIRMED: 'processing',
          COMPLETED: 'success',
          CANCELLED: 'error'
        };
        const labels = {
          PENDING: 'Chờ duyệt',
          CONFIRMED: 'Đã xác nhận',
          COMPLETED: 'Hoàn thành',
          CANCELLED: 'Đã hủy'
        };
        return <Tag color={colors[status]} className="border-none font-semibold px-2 py-0.5 rounded">{labels[status]}</Tag>;
      }
    },
    {
      title: 'Thao tác',
      key: 'actions',
      width: 96,
      render: (_: any, record: MockBooking) => (
        <Space size="small" onClick={(event) => event.stopPropagation()}>
          <Tooltip title="Chi tiết">
            <Button
              shape="circle"
              icon={<EyeOutlined />}
              onClick={() => navigate(`/admin/bookings/${record._id}`)}
            />
          </Tooltip>
        </Space>
      )
    }
  ];

  const paymentColumns = [
    {
      title: 'Mã Hóa đơn',
      dataIndex: '_id',
      key: 'id',
      render: (id: string) => <span className="font-semibold text-brand-orange text-xs">{id}</span>
    },
    {
      title: 'Mã Đặt lịch',
      dataIndex: 'bookingId',
      key: 'bookingId',
      render: (bid: string) => <span className="font-medium text-indigo-500 text-xs">{bid}</span>
    },
    {
      title: 'Số tiền',
      dataIndex: 'amount',
      key: 'amount',
      render: (amount: number) => <span className="font-bold text-brand-orange">{formatVND(amount)}</span>
    },
    {
      title: 'Phương thức',
      dataIndex: 'method',
      key: 'method',
      render: (method: MockPayment['method']) => (
        <Tag color={method === 'BANK_TRANSFER' ? 'blue' : 'orange'}>
          {method === 'BANK_TRANSFER' ? 'Chuyển khoản' : 'Tiền mặt'}
        </Tag>
      )
    },
    {
      title: 'Mã Giao dịch',
      dataIndex: 'transactionId',
      key: 'txn',
      render: (txn: string) => <span className="text-xs font-mono dark:text-white">{txn || 'Chưa có'}</span>
    },
    {
      title: 'Ngày thanh toán',
      dataIndex: 'createdAt',
      key: 'time',
      render: (time: string) => <span className="text-xs text-ink-muted dark:text-ink-darkMuted">{dayjs(time).format('HH:mm DD/MM/YYYY')}</span>
    },
    {
      title: 'Trạng thái',
      dataIndex: 'status',
      key: 'status',
      render: (status: MockPayment['status']) => (
        <Tag color={status === 'SUCCESS' ? 'success' : status === 'FAILED' ? 'error' : 'warning'} className="border-none font-semibold px-2 py-0.5 rounded">
          {status === 'SUCCESS' ? 'Đã thanh toán' : status === 'FAILED' ? 'Thất bại' : 'Chờ thanh toán'}
        </Tag>
      )
    }
  ];

  return (
    <div className="space-y-6">
      {/* Title */}
      <div className="border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
          Giám sát Hệ thống (Supervision Panel)
        </Title>
        <Text className="text-ink-muted dark:text-ink-darkMuted">
          Xem toàn bộ giao dịch, lịch đặt sân và quản lý luồng doanh thu trên toàn hệ thống Sport Energy.
        </Text>
      </div>

      {/* KPI Stats cards */}
      <Row gutter={[24, 24]}>
        <Col xs={24} sm={8}>
          <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm">
            <Statistic
              title={<span className="text-ink-muted dark:text-ink-darkMuted font-medium text-sm">Tổng doanh thu hệ thống</span>}
              value={totalStats.revenue}
              formatter={(val) => <span className="font-bold text-2xl text-brand-orange">{formatVND(val as number)}</span>}
              prefix={<DollarOutlined className="text-brand-orange mr-1" />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={8}>
          <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm">
            <Statistic
              title={<span className="text-ink-muted dark:text-ink-darkMuted font-medium text-sm">Tổng ca đặt sân hoạt động</span>}
              value={totalStats.bookingsCount}
              formatter={(val) => <span className="font-bold text-2xl text-ink dark:text-white">{val} lượt</span>}
              prefix={<CalendarOutlined className="text-indigo-500 mr-1" />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={8}>
          <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm">
            <Statistic
              title={<span className="text-ink-muted dark:text-ink-darkMuted font-medium text-sm">Tiền mặt chờ thu tại các quầy</span>}
              value={totalStats.pendingCash}
              formatter={(val) => <span className="font-bold text-2xl text-amber-500">{formatVND(val as number)}</span>}
              prefix={<TransactionOutlined className="text-amber-500 mr-1" />}
            />
          </Card>
        </Col>
      </Row>

      {/* Filtering and Tabs */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <Tabs
          activeKey={activeTab}
          onChange={setActiveTab}
          items={[
            { key: 'BOOKINGS', label: 'Danh sách Lịch đặt' },
            { key: 'PAYMENTS', label: 'Báo cáo Thanh toán' }
          ]}
          className="w-full md:w-auto"
        />

        <Space wrap size="middle" className="w-full md:w-auto">
          {activeTab === 'BOOKINGS' && (
            <DatePicker
              placeholder="Lọc theo ngày"
              onChange={(date) => setSelectedDate(date ? date.format('YYYY-MM-DD') : '')}
              className="w-40 rounded-md"
            />
          )}
          <Search
            placeholder={activeTab === 'BOOKINGS' ? "Tìm theo mã đặt, sân, khách hàng..." : "Tìm theo hóa đơn, giao dịch..."}
            allowClear
            enterButton={<SearchOutlined />}
            onSearch={setSearchText}
            onChange={(e) => setSearchText(e.target.value)}
            className="w-full md:w-80 custom-search"
          />
        </Space>
      </div>

      {/* Tables */}
      {activeTab === 'BOOKINGS' ? (
        <Table
          dataSource={filteredBookings}
          columns={bookingColumns}
          rowKey="_id"
          loading={loading}
          pagination={{ pageSize: 8 }}
          onRow={(record) => ({
            onClick: () => navigate(`/admin/bookings/${record._id}`),
            className: 'cursor-pointer',
          })}
          className="border border-semantic-border/10 dark:border-semantic-borderDark/10 rounded-xl overflow-hidden shadow-sm bg-white dark:bg-surface-dark1"
        />
      ) : (
        <Table
          dataSource={filteredPayments}
          columns={paymentColumns}
          rowKey="_id"
          loading={loading}
          pagination={{ pageSize: 8 }}
          className="border border-semantic-border/10 dark:border-semantic-borderDark/10 rounded-xl overflow-hidden shadow-sm bg-white dark:bg-surface-dark1"
        />
      )}
    </div>
  );
};

export default AdminSupervisionPage;
