import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Alert, Button, Card, Col, Empty, Row, Select, Space, Statistic, Table, Typography } from 'antd';
import { BarChartOutlined, DollarOutlined, EnvironmentOutlined, ReloadOutlined, RiseOutlined, TeamOutlined } from '@ant-design/icons';
import { Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip as ChartTooltip, XAxis, YAxis } from 'recharts';
import dayjs from 'dayjs';
import { formatVND } from '../../../../core/utils/formatters';
import { apiClient } from '../../../../core/network/api_client';
import { reportApi } from '../../data/report_api';
import { FacilityPerformanceItem, NormalizedPerformanceReport } from '../../data/report_types';

const { Title, Text } = Typography;
const COLORS = ['#FF5600', '#4F46E5', '#10B981', '#F59E0B', '#EC4899', '#8B5CF6'];

const numberValue = (value: any) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const quickRange = (key: string) => {
  const today = dayjs();
  if (key === '30days') return [today.subtract(29, 'day'), today];
  if (key === 'month') return [today.startOf('month'), today.endOf('month')];
  if (key === 'lastMonth') {
    const last = today.subtract(1, 'month');
    return [last.startOf('month'), last.endOf('month')];
  }
  return [today.subtract(6, 'day'), today];
};

const emptyReport = (): NormalizedPerformanceReport => ({
  source: 'fallback',
  summary: {
    totalRevenue: 0,
    paidRevenue: 0,
    pendingRevenue: 0,
    refundPendingAmount: 0,
    paidCancelledAmount: 0,
    totalBookings: 0,
    activeBookings: 0,
    pendingBookings: 0,
    confirmedBookings: 0,
    completedBookings: 0,
    cancelledBookings: 0,
    bookedMinutes: 0,
    availableMinutes: 0,
    utilizationRate: 0,
  },
  courtStats: [],
  facilityStats: [],
  sportStats: [],
  dailyStats: [],
  peakHours: [],
  customerStats: [],
});

const AdminOverviewPage: React.FC = () => {
  const [report, setReport] = useState<NormalizedPerformanceReport>(emptyReport());
  const [loading, setLoading] = useState(false);
  const [fallbackReason, setFallbackReason] = useState('');
  const [timeRange, setTimeRange] = useState('7days');
  const [usersCount, setUsersCount] = useState(0);
  const [recentBookings, setRecentBookings] = useState<any[]>([]);

  const range = useMemo(() => quickRange(timeRange), [timeRange]);

  const loadUsersCount = useCallback(async () => {
    try {
      const resUsers = await apiClient.get('/user');
      setUsersCount((resUsers.data.items || []).length);
    } catch {
      setUsersCount(0);
    }
  }, []);

  const buildFallbackReport = useCallback(async (): Promise<NormalizedPerformanceReport> => {
    const [bookingRes, paymentRes, courtRes, facilityRes, sportRes] = await Promise.all([
      apiClient.get('/booking'),
      apiClient.get('/payment'),
      apiClient.get('/court'),
      apiClient.get('/facility'),
      apiClient.get('/sport'),
    ]);
    const bookings = (bookingRes.data.items || []).filter((booking: any) => {
      const date = dayjs(booking.bookingDate || booking.booking_date);
      return date.isValid() && !date.isBefore(range[0], 'day') && !date.isAfter(range[1], 'day');
    });
    const bookingIds = new Set(bookings.map((booking: any) => booking._id || booking.id));
    const payments = (paymentRes.data.items || []).filter((payment: any) => bookingIds.has(payment.bookingId || payment.booking_id));
    const courts = courtRes.data.items || [];
    const facilities = facilityRes.data.items || [];
    const sports = sportRes.data.items || [];

    const paidRevenue = payments.filter((payment: any) => payment.status === 'SUCCESS').reduce((sum: number, payment: any) => sum + numberValue(payment.amount), 0);
    const pendingRevenue = payments.filter((payment: any) => payment.status === 'PENDING').reduce((sum: number, payment: any) => sum + numberValue(payment.amount), 0);

    const facilityStats = facilities.map((facility: any) => {
      const facilityCourtIds = new Set(courts.filter((court: any) => court.facilityId === (facility._id || facility.id)).map((court: any) => court._id || court.id));
      const facilityBookings = bookings.filter((booking: any) => facilityCourtIds.has(booking.courtId || booking.court_id));
      const facilityBookingIds = new Set(facilityBookings.map((booking: any) => booking._id || booking.id));
      return {
        facilityId: facility._id || facility.id,
        facilityName: facility.name,
        courtName: facility.name,
        bookingCount: facilityBookings.length,
        activeBookings: facilityBookings.filter((booking: any) => booking.status !== 'CANCELLED').length,
        completedBookings: facilityBookings.filter((booking: any) => booking.status === 'COMPLETED').length,
        cancelledBookings: facilityBookings.filter((booking: any) => booking.status === 'CANCELLED').length,
        paidRevenue: payments.filter((payment: any) => payment.status === 'SUCCESS' && facilityBookingIds.has(payment.bookingId || payment.booking_id)).reduce((sum: number, payment: any) => sum + numberValue(payment.amount), 0),
        pendingRevenue: 0,
        bookedMinutes: 0,
        availableMinutes: 0,
        utilizationRate: 0,
      };
    });

    const courtStats = courts.map((court: any) => {
      const id = court._id || court.id;
      const courtBookings = bookings.filter((booking: any) => (booking.courtId || booking.court_id) === id);
      const courtBookingIds = new Set(courtBookings.map((booking: any) => booking._id || booking.id));
      const sport = sports.find((item: any) => (item._id || item.id) === court.sportId);
      return {
        courtId: id,
        courtName: court.name,
        facilityId: court.facilityId,
        sportId: court.sportId,
        sportName: sport?.name || 'Khác',
        bookingCount: courtBookings.length,
        activeBookings: courtBookings.filter((booking: any) => booking.status !== 'CANCELLED').length,
        completedBookings: courtBookings.filter((booking: any) => booking.status === 'COMPLETED').length,
        cancelledBookings: courtBookings.filter((booking: any) => booking.status === 'CANCELLED').length,
        paidRevenue: payments.filter((payment: any) => payment.status === 'SUCCESS' && courtBookingIds.has(payment.bookingId || payment.booking_id)).reduce((sum: number, payment: any) => sum + numberValue(payment.amount), 0),
        pendingRevenue: 0,
        bookedMinutes: 0,
        availableMinutes: 0,
        utilizationRate: 0,
      };
    });

    const sportMap = new Map<string, any>();
    courtStats.forEach((court: any) => {
      const current = sportMap.get(court.sportName) || { sportName: court.sportName, bookingCount: 0, paidRevenue: 0 };
      current.bookingCount += court.bookingCount;
      current.paidRevenue += court.paidRevenue;
      sportMap.set(court.sportName, current);
    });

    const dateMap = new Map<string, any>();
    let cursor = range[0];
    while (!cursor.isAfter(range[1], 'day')) {
      dateMap.set(cursor.format('YYYY-MM-DD'), { date: cursor.format('YYYY-MM-DD'), label: cursor.format('DD/MM'), paidRevenue: 0, bookingCount: 0, activeBookings: 0 });
      cursor = cursor.add(1, 'day');
    }
    bookings.forEach((booking: any) => {
      const row = dateMap.get(dayjs(booking.bookingDate || booking.booking_date).format('YYYY-MM-DD'));
      if (row) {
        row.bookingCount += 1;
        if (booking.status !== 'CANCELLED') row.activeBookings += 1;
      }
    });
    payments.filter((payment: any) => payment.status === 'SUCCESS').forEach((payment: any) => {
      const booking = bookings.find((item: any) => (item._id || item.id) === (payment.bookingId || payment.booking_id));
      const row = booking ? dateMap.get(dayjs(booking.bookingDate || booking.booking_date).format('YYYY-MM-DD')) : null;
      if (row) row.paidRevenue += numberValue(payment.amount);
    });

    setRecentBookings(bookings.slice(0, 5));
    return {
      source: 'fallback',
      summary: {
        ...emptyReport().summary,
        totalRevenue: paidRevenue,
        paidRevenue,
        pendingRevenue,
        totalBookings: bookings.length,
        activeBookings: bookings.filter((booking: any) => booking.status !== 'CANCELLED').length,
        pendingBookings: bookings.filter((booking: any) => booking.status === 'PENDING').length,
        confirmedBookings: bookings.filter((booking: any) => booking.status === 'CONFIRMED').length,
        completedBookings: bookings.filter((booking: any) => booking.status === 'COMPLETED').length,
        cancelledBookings: bookings.filter((booking: any) => booking.status === 'CANCELLED').length,
      },
      courtStats,
      facilityStats,
      sportStats: Array.from(sportMap.values()),
      dailyStats: Array.from(dateMap.values()),
      peakHours: [],
      customerStats: [],
    };
  }, [range]);

  const loadReport = useCallback(async () => {
    setLoading(true);
    setFallbackReason('');
    try {
      const response = await reportApi.getAdvancedPerformanceReport({
        dateFrom: range[0].format('YYYY-MM-DD'),
        dateTo: range[1].format('YYYY-MM-DD'),
        include: 'summary,courtStats,facilityStats,sportStats,dailyStats,peakHours,customerStats',
      });
      setReport(response);
      setRecentBookings([]);
    } catch (error: any) {
      const reason = error.response?.data?.message || error.message || 'Report endpoint lỗi';
      console.warn('[AdminOverview] Falling back to list aggregation:', reason);
      setFallbackReason(reason);
      setReport(await buildFallbackReport());
    } finally {
      setLoading(false);
    }
  }, [buildFallbackReport, range]);

  useEffect(() => {
    loadUsersCount();
  }, [loadUsersCount]);

  useEffect(() => {
    loadReport();
  }, [loadReport]);

  const topFacilityName = report.facilityStats[0]?.facilityName || '';
  const topFacilityRevenue = numberValue(report.facilityStats[0]?.paidRevenue);
  const topFacilityText = topFacilityName
    ? `${topFacilityName} (${formatVND(topFacilityRevenue)})`
    : 'Chưa có dữ liệu';

  const sportPieData = report.sportStats.map((item: any) => ({
    name: item.sportName || item.name || 'Khác',
    value: numberValue(item.bookingCount || item.activeBookings),
  }));

  const activityColumns = [
    {
      title: 'Hoạt động',
      key: 'action',
      render: (_: any, record: any) => (
        <span className="dark:text-white">
          Booking <strong>{record._id || record.id}</strong> ngày {dayjs(record.bookingDate || record.booking_date).format('DD/MM/YYYY')} - trạng thái <strong>{record.status}</strong>
        </span>
      ),
    },
    {
      title: 'Thời gian',
      dataIndex: 'createdAt',
      key: 'time',
      render: (time: string) => <span className="text-xs text-ink-muted">{time ? dayjs(time).format('HH:mm DD/MM/YYYY') : 'Chưa có dữ liệu'}</span>,
    },
  ];

  const facilityColumns = [
    {
      title: 'Cơ sở',
      key: 'facility',
      render: (_: any, record: FacilityPerformanceItem) => <span className="font-semibold dark:text-white">{record.facilityName || record.courtName || 'Chưa có dữ liệu'}</span>,
    },
    {
      title: 'Booking',
      key: 'bookings',
      render: (_: any, record: FacilityPerformanceItem) => numberValue(record.bookingCount || record.activeBookings),
    },
    {
      title: 'Hoàn tất',
      dataIndex: 'completedBookings',
      key: 'completedBookings',
      render: numberValue,
    },
    {
      title: 'Đã hủy',
      dataIndex: 'cancelledBookings',
      key: 'cancelledBookings',
      render: numberValue,
    },
    {
      title: 'Doanh thu',
      dataIndex: 'paidRevenue',
      key: 'paidRevenue',
      render: (value: number) => <span className="font-bold text-brand-orange">{formatVND(numberValue(value))}</span>,
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div>
          <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>Tổng quan Hệ thống</Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">Ưu tiên dữ liệu từ advanced performance report cho toàn hệ thống.</Text>
        </div>
        <Space>
          <Select
            value={timeRange}
            onChange={setTimeRange}
            className="w-48 rounded-md"
            size="large"
            options={[
              { value: '7days', label: '7 ngày qua' },
              { value: '30days', label: '30 ngày qua' },
              { value: 'month', label: 'Tháng này' },
              { value: 'lastMonth', label: 'Tháng trước' },
            ]}
          />
          <Button icon={<ReloadOutlined />} onClick={loadReport} loading={loading}>Tải lại</Button>
        </Space>
      </div>

      {fallbackReason && <Alert type="warning" showIcon message="Đang dùng dữ liệu fallback" description={`Advanced report chưa dùng được: ${fallbackReason}`} />}

      <Row gutter={[24, 24]}>
        <Col xs={24} sm={6}>
          <Card className="rounded-xl border border-semantic-border/20 bg-white dark:bg-surface-dark1 shadow-sm">
            <Statistic title="Doanh thu toàn hệ thống" value={report.summary.paidRevenue} formatter={(val) => <span className="font-bold text-2xl text-brand-orange">{formatVND(numberValue(val))}</span>} prefix={<DollarOutlined className="text-brand-orange" />} />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card className="rounded-xl border border-semantic-border/20 bg-white dark:bg-surface-dark1 shadow-sm">
            <Statistic title="Tổng booking" value={report.summary.totalBookings} formatter={(val) => <span className="font-bold text-2xl dark:text-white">{numberValue(val)} ca</span>} prefix={<RiseOutlined className="text-indigo-500" />} />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card className="rounded-xl border border-semantic-border/20 bg-white dark:bg-surface-dark1 shadow-sm h-full overflow-hidden">
            <div className="text-ink-muted dark:text-ink-darkMuted text-sm mb-3 truncate">
              Cơ sở doanh thu cao nhất
            </div>
            <div className="flex items-center gap-3 min-w-0">
              <EnvironmentOutlined className="text-emerald-500 text-2xl shrink-0" />
              <span
                className="font-bold text-sm leading-5 dark:text-white min-w-0 flex-1 truncate"
                title={topFacilityText}
              >
                {topFacilityText}
              </span>
            </div>
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card className="rounded-xl border border-semantic-border/20 bg-white dark:bg-surface-dark1 shadow-sm">
            <Statistic title="Số lượng thành viên" value={usersCount} formatter={(val) => <span className="font-bold text-2xl dark:text-white">{numberValue(val)} users</span>} prefix={<TeamOutlined className="text-amber-500" />} />
          </Card>
        </Col>
      </Row>

      <Row gutter={[24, 24]}>
        <Col xs={24} sm={6}><Card><Statistic title="Hoàn tất" value={report.summary.completedBookings} /></Card></Col>
        <Col xs={24} sm={6}><Card><Statistic title="Đã hủy" value={report.summary.cancelledBookings} /></Card></Col>
        <Col xs={24} sm={6}><Card><Statistic title="Thanh toán thành công" value={formatVND(report.summary.paidRevenue)} /></Card></Col>
        <Col xs={24} sm={6}><Card><Statistic title="Thanh toán đang chờ" value={formatVND(report.summary.pendingRevenue)} /></Card></Col>
      </Row>

      <Row gutter={[24, 24]}>
        <Col xs={24} lg={16}>
          <Card title="Doanh thu theo ngày" className="rounded-xl border border-semantic-border/20 bg-white dark:bg-surface-dark1 shadow-sm">
            {report.dailyStats.length === 0 ? (
              <Empty description="Không có dữ liệu theo ngày" />
            ) : (
              <div className="h-[300px] w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={report.dailyStats.map((item) => ({ date: item.label || dayjs(item.date).format('DD/MM'), 'Doanh thu': item.paidRevenue }))}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} opacity={0.15} />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                    <YAxis tick={{ fontSize: 11 }} />
                    <ChartTooltip formatter={(value) => [formatVND(numberValue(value)), 'Doanh thu']} />
                    <Bar dataKey="Doanh thu" fill="#FF5600" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}
          </Card>
        </Col>
        <Col xs={24} lg={8}>
          <Card title="Môn thể thao phổ biến" className="rounded-xl border border-semantic-border/20 bg-white dark:bg-surface-dark1 shadow-sm h-full">
            {sportPieData.length === 0 ? (
              <Empty description="Không có dữ liệu booking" />
            ) : (
              <div className="h-[240px] w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={sportPieData} innerRadius={60} outerRadius={80} paddingAngle={5} dataKey="value">
                      {sportPieData.map((_, index) => <Cell key={index} fill={COLORS[index % COLORS.length]} />)}
                    </Pie>
                    <ChartTooltip />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            )}
          </Card>
        </Col>
      </Row>

      <Card title="Hiệu suất theo cơ sở" className="rounded-xl border border-semantic-border/20 bg-white dark:bg-surface-dark1 shadow-sm">
        <Table dataSource={report.facilityStats} columns={facilityColumns} rowKey={(record) => record.facilityId || record.facilityName || Math.random().toString()} loading={loading} pagination={{ pageSize: 6 }} />
      </Card>

      <Card title={<span className="font-semibold dark:text-white"><BarChartOutlined className="text-brand-orange mr-1.5" /> Hoạt động đặt lịch gần đây</span>} className="rounded-xl border border-semantic-border/20 bg-white dark:bg-surface-dark1 shadow-sm">
        {recentBookings.length === 0 && !fallbackReason ? (
          <Text className="text-ink-muted dark:text-ink-darkMuted">Advanced report không trả danh sách booking thô. Bảng này chỉ hiển thị khi dùng fallback.</Text>
        ) : (
          <Table dataSource={recentBookings} columns={activityColumns} rowKey={(record) => record._id || record.id} loading={loading} pagination={false} />
        )}
      </Card>
    </div>
  );
};

export default AdminOverviewPage;
