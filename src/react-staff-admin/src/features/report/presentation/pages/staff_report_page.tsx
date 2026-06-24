import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Alert, Button, Card, Col, DatePicker, Empty, Input, Row, Select, Statistic, Table, Tag, Typography } from 'antd';
import { DollarOutlined, FireOutlined, ReloadOutlined, RiseOutlined, SearchOutlined, TrophyOutlined } from '@ant-design/icons';
import { Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip as ChartTooltip, XAxis, YAxis } from 'recharts';
import dayjs, { Dayjs } from 'dayjs';
import { authStorage } from '../../../../core/utils/auth_storage';
import { formatVND } from '../../../../core/utils/formatters';
import { apiClient } from '../../../../core/network/api_client';
import { reportApi } from '../../data/report_api';
import { CourtPerformanceItem, NormalizedPerformanceReport } from '../../data/report_types';

const { Title, Text } = Typography;
const { RangePicker } = DatePicker;
const COLORS = ['#FF5600', '#4F46E5', '#10B981', '#F59E0B', '#EC4899', '#06B6D4'];

interface CourtItem {
  _id?: string;
  id?: string;
  name: string;
  facilityId?: string;
  sportId?: string;
  sportName?: string;
}

interface SportItem {
  _id?: string;
  id?: string;
  name: string;
}

const numberValue = (value: any) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const percentText = (value: number) => `${(numberValue(value) * 100).toFixed(1)}%`;

const normalizeId = (value: any) => value?._id || value?.id || value || undefined;

const quickRange = (key: string): [Dayjs, Dayjs] => {
  const today = dayjs();
  if (key === 'today') return [today, today];
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

const StaffReportPage: React.FC = () => {
  const user = useMemo(() => authStorage.getUser(), []);
  const facilityId = user?.facilityId;
  const [report, setReport] = useState<NormalizedPerformanceReport>(emptyReport());
  const [courts, setCourts] = useState<CourtItem[]>([]);
  const [sports, setSports] = useState<SportItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [fallbackReason, setFallbackReason] = useState('');
  const [quick, setQuick] = useState('7days');
  const [range, setRange] = useState<[Dayjs, Dayjs]>(() => quickRange('7days'));
  const [courtId, setCourtId] = useState<string | undefined>();
  const [sportId, setSportId] = useState<string | undefined>();
  const [searchText, setSearchText] = useState('');

  const loadMasterData = useCallback(async () => {
    if (!facilityId) return;
    const [courtRes, sportRes] = await Promise.all([
      apiClient.get('/court', { params: { facilityId } }),
      apiClient.get('/sport'),
    ]);
    setCourts((courtRes.data.items || []).map((c: any) => ({
      ...c,
      _id: c._id || c.id || '',
      sportId: c.sportId || c.sport_id || normalizeId(c.sport),
      sportName: c.sportName || c.sport?.name || '',
    })));
    setSports((sportRes.data.items || []).map((s: any) => ({ ...s, _id: s._id || s.id || '' })));
  }, [facilityId]);

  const buildFallbackReport = useCallback(async (): Promise<NormalizedPerformanceReport> => {
    const [bookingRes, paymentRes] = await Promise.all([
      apiClient.get('/booking', { params: { dateFrom: range[0].format('YYYY-MM-DD'), dateTo: range[1].format('YYYY-MM-DD') } }),
      apiClient.get('/payment'),
    ]);
    const courtIds = new Set(courts.map((court) => court._id || court.id));
    const selectedCourtIds = new Set(
      courts
        .filter((court) => (!courtId || (court._id || court.id) === courtId) && (!sportId || court.sportId === sportId))
        .map((court) => court._id || court.id)
    );
    const hasCourtScopeFilter = Boolean(courtId || sportId);
    const bookings = (bookingRes.data.items || [])
      .filter((booking: any) => courtIds.has(booking.courtId || booking.court_id))
      .filter((booking: any) => !hasCourtScopeFilter || selectedCourtIds.has(booking.courtId || booking.court_id))
      .filter((booking: any) => {
        const date = dayjs(booking.bookingDate || booking.booking_date);
        return date.isValid() && !date.isBefore(range[0], 'day') && !date.isAfter(range[1], 'day');
      });
    const bookingIdSet = new Set(bookings.map((booking: any) => booking._id || booking.id));
    const payments = (paymentRes.data.items || []).filter((payment: any) => bookingIdSet.has(payment.bookingId || payment.booking_id));
    const paidRevenue = payments.filter((payment: any) => payment.status === 'SUCCESS').reduce((sum: number, payment: any) => sum + numberValue(payment.amount), 0);
    const pendingRevenue = payments.filter((payment: any) => payment.status === 'PENDING').reduce((sum: number, payment: any) => sum + numberValue(payment.amount), 0);

    const courtStats = courts
      .filter((court) => !hasCourtScopeFilter || selectedCourtIds.has(court._id || court.id))
      .map((court) => {
        const id = court._id || court.id || '';
        const courtBookings = bookings.filter((booking: any) => (booking.courtId || booking.court_id) === id);
        const courtBookingIds = new Set(courtBookings.map((booking: any) => booking._id || booking.id));
        const courtPaidRevenue = payments
          .filter((payment: any) => payment.status === 'SUCCESS' && courtBookingIds.has(payment.bookingId || payment.booking_id))
          .reduce((sum: number, payment: any) => sum + numberValue(payment.amount), 0);
        const bookedMinutes = courtBookings
          .filter((booking: any) => booking.status !== 'CANCELLED')
          .reduce((sum: number, booking: any) => sum + Math.max(0, numberValue(booking.endMinutes || booking.end_minutes) - numberValue(booking.startMinutes || booking.start_minutes)), 0);
        const sport = sports.find((item) => (item._id || item.id) === court.sportId);
        return {
          courtId: id,
          courtName: court.name,
          sportId: court.sportId,
          sportName: sport?.name || 'Khác',
          bookingCount: courtBookings.length,
          activeBookings: courtBookings.filter((booking: any) => booking.status !== 'CANCELLED').length,
          completedBookings: courtBookings.filter((booking: any) => booking.status === 'COMPLETED').length,
          cancelledBookings: courtBookings.filter((booking: any) => booking.status === 'CANCELLED').length,
          paidRevenue: courtPaidRevenue,
          pendingRevenue: 0,
          bookedMinutes,
          availableMinutes: 0,
          utilizationRate: 0,
        };
      });

    const sportMap = new Map<string, any>();
    courtStats.forEach((court) => {
      const key = court.sportName || 'Khác';
      const current = sportMap.get(key) || { sportName: key, bookingCount: 0, paidRevenue: 0 };
      current.bookingCount += court.bookingCount;
      current.paidRevenue += court.paidRevenue;
      sportMap.set(key, current);
    });

    const dateMap = new Map<string, any>();
    let cursor = range[0];
    while (!cursor.isAfter(range[1], 'day')) {
      dateMap.set(cursor.format('YYYY-MM-DD'), { date: cursor.format('YYYY-MM-DD'), label: cursor.format('DD/MM'), paidRevenue: 0, bookingCount: 0, activeBookings: 0 });
      cursor = cursor.add(1, 'day');
    }
    bookings.forEach((booking: any) => {
      const key = dayjs(booking.bookingDate || booking.booking_date).format('YYYY-MM-DD');
      const row = dateMap.get(key);
      if (row) {
        row.bookingCount += 1;
        if (booking.status !== 'CANCELLED') row.activeBookings += 1;
        row.paidRevenue += numberValue(booking.totalPrice || booking.total_price);
      }
    });

    const peakMap = new Map<string, any>();
    bookings.forEach((booking: any) => {
      const hour = Math.floor(numberValue(booking.startMinutes || booking.start_minutes) / 60);
      const row = peakMap.get(String(hour)) || { hour, label: `${String(hour).padStart(2, '0')}:00`, bookingCount: 0 };
      row.bookingCount += 1;
      peakMap.set(String(hour), row);
    });

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
        bookedMinutes: courtStats.reduce((sum, court) => sum + court.bookedMinutes, 0),
      },
      courtStats,
      facilityStats: [],
      sportStats: Array.from(sportMap.values()),
      dailyStats: Array.from(dateMap.values()),
      peakHours: Array.from(peakMap.values()).sort((a, b) => b.bookingCount - a.bookingCount),
      customerStats: [],
    };
  }, [courtId, courts, range, sportId, sports]);

  const loadReport = useCallback(async () => {
    if (!facilityId) return;
    setLoading(true);
    setFallbackReason('');
    try {
      const response = await reportApi.getCourtPerformanceReport({
        facilityId,
        courtId,
        sportId,
        dateFrom: range[0].format('YYYY-MM-DD'),
        dateTo: range[1].format('YYYY-MM-DD'),
      });
      setReport(response);
    } catch (error: any) {
      const reason = error.response?.data?.message || error.message || 'Report endpoint lỗi';
      console.warn('[StaffReport] Falling back to list aggregation:', reason);
      setFallbackReason(reason);
      setReport(await buildFallbackReport());
    } finally {
      setLoading(false);
    }
  }, [buildFallbackReport, courtId, facilityId, range, sportId]);

  useEffect(() => {
    loadMasterData();
  }, [loadMasterData]);

  useEffect(() => {
    loadReport();
  }, [loadReport]);

  useEffect(() => {
    if (!sportId || !courtId) return;
    const selectedCourt = courts.find((court) => (court._id || court.id) === courtId);
    if (selectedCourt && selectedCourt.sportId !== sportId) {
      setCourtId(undefined);
    }
  }, [courtId, courts, sportId]);

  const courtOptions = useMemo(
    () => courts
      .filter((court) => !sportId || court.sportId === sportId)
      .map((court) => ({
        value: court._id || court.id,
        label: court.sportName ? `${court.name} · ${court.sportName}` : court.name,
      })),
    [courts, sportId]
  );

  const sportChartData = useMemo(() => {
    const source = report.sportStats.length > 0 ? report.sportStats : report.courtStats;
    const map = new Map<string, number>();
    source.forEach((item: any) => {
      const name = item.sportName || item.name || 'Khác';
      map.set(name, (map.get(name) || 0) + numberValue(item.bookingCount || item.activeBookings));
    });
    return Array.from(map.entries()).map(([name, value]) => ({ name, value }));
  }, [report]);

  const filteredCourtStats = useMemo(() => {
    const query = searchText.trim().toLowerCase();
    return report.courtStats
      .filter((item) => !courtId || item.courtId === courtId)
      .filter((item) => !sportId || item.sportId === sportId)
      .filter((item) => !query || [item.courtName, item.facilityName, item.sportName].join(' ').toLowerCase().includes(query))
      .sort((a, b) => (
        (a.sportName || '').localeCompare(b.sportName || '', 'vi')
        || (a.courtName || '').localeCompare(b.courtName || '', 'vi')
      ));
  }, [courtId, report.courtStats, searchText, sportId]);

  const peakHour = report.peakHours.length > 0
    ? `${report.peakHours[0].label || report.peakHours[0].hour}: ${report.peakHours[0].bookingCount} ca`
    : 'Chưa có dữ liệu';

  const courtColumns = [
    {
      title: 'Sân / Môn thể thao',
      key: 'court',
      render: (_: any, record: CourtPerformanceItem) => (
        <div className="flex flex-col">
          <span className="font-semibold dark:text-white">{record.courtName || 'Chưa có dữ liệu'}</span>
          <div className="mt-1">
            <Tag color={record.sportName ? 'geekblue' : 'default'}>{record.sportName || 'Chưa rõ môn'}</Tag>
          </div>
        </div>
      ),
      sorter: (a: CourtPerformanceItem, b: CourtPerformanceItem) => (
        (a.sportName || '').localeCompare(b.sportName || '', 'vi')
        || (a.courtName || '').localeCompare(b.courtName || '', 'vi')
      ),
    },
    {
      title: 'Booking',
      dataIndex: 'bookingCount',
      key: 'bookingCount',
      render: (value: number) => <Tag color="processing">{numberValue(value)} ca</Tag>,
      sorter: (a: CourtPerformanceItem, b: CourtPerformanceItem) => numberValue(a.bookingCount) - numberValue(b.bookingCount),
    },
    {
      title: 'Hoàn tất',
      dataIndex: 'completedBookings',
      key: 'completedBookings',
      render: (value: number) => numberValue(value),
      sorter: (a: CourtPerformanceItem, b: CourtPerformanceItem) => numberValue(a.completedBookings) - numberValue(b.completedBookings),
    },
    {
      title: 'Đã hủy',
      dataIndex: 'cancelledBookings',
      key: 'cancelledBookings',
      render: (value: number) => numberValue(value),
      sorter: (a: CourtPerformanceItem, b: CourtPerformanceItem) => numberValue(a.cancelledBookings) - numberValue(b.cancelledBookings),
    },
    {
      title: 'Doanh thu',
      dataIndex: 'paidRevenue',
      key: 'paidRevenue',
      render: (value: number) => <span className="font-bold text-brand-orange">{formatVND(numberValue(value))}</span>,
      sorter: (a: CourtPerformanceItem, b: CourtPerformanceItem) => numberValue(a.paidRevenue) - numberValue(b.paidRevenue),
    },
    {
      title: 'Giờ đặt',
      dataIndex: 'bookedMinutes',
      key: 'bookedMinutes',
      render: (value: number) => `${(numberValue(value) / 60).toFixed(1)}h`,
      sorter: (a: CourtPerformanceItem, b: CourtPerformanceItem) => numberValue(a.bookedMinutes) - numberValue(b.bookedMinutes),
    },
    {
      title: 'Tỷ lệ sử dụng',
      dataIndex: 'utilizationRate',
      key: 'utilizationRate',
      render: (value: number) => percentText(value),
      sorter: (a: CourtPerformanceItem, b: CourtPerformanceItem) => numberValue(a.utilizationRate) - numberValue(b.utilizationRate),
    },
  ];

  if (user && user.role === 'STAFF' && !facilityId) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[400px] text-center p-6 bg-white dark:bg-surface-dark1 rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm">
        <Title level={4} className="m-0 dark:text-white" style={{ fontWeight: 600 }}>Chưa được gán cơ sở hoạt động</Title>
        <Text className="text-ink-muted dark:text-ink-darkMuted mt-2 max-w-md block">
          Tài khoản nhân viên của bạn chưa được liên kết với cơ sở thể thao nào.
        </Text>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col xl:flex-row xl:items-start xl:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div>
          <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>Báo cáo & Thống kê cơ sở</Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Dữ liệu ưu tiên từ endpoint báo cáo chuyên biệt, có fallback an toàn khi backend chưa sẵn sàng.
          </Text>
        </div>
        <Button icon={<ReloadOutlined />} onClick={loadReport} loading={loading}>Tải lại</Button>
      </div>

      {fallbackReason && (
        <Alert
          type="warning"
          showIcon
          message="Đang dùng dữ liệu fallback"
          description={`Report endpoint chưa dùng được: ${fallbackReason}`}
        />
      )}

      <Card className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        <div className="flex flex-col lg:flex-row gap-3">
          <Select
            value={quick}
            onChange={(value) => {
              setQuick(value);
              setRange(quickRange(value));
            }}
            className="w-full lg:w-52"
            options={[
              { value: 'today', label: 'Hôm nay' },
              { value: '7days', label: '7 ngày gần nhất' },
              { value: 'month', label: 'Tháng này' },
              { value: 'lastMonth', label: 'Tháng trước' },
            ]}
          />
          <RangePicker
            value={range}
            onChange={(value) => {
              if (value?.[0] && value?.[1]) {
                setRange([value[0], value[1]]);
                setQuick('custom');
              }
            }}
            className="w-full lg:w-72"
          />
          <Select
            allowClear
            placeholder="Tất cả sân"
            value={courtId}
            onChange={setCourtId}
            className="w-full lg:w-56"
            options={courtOptions}
          />
          <Select
            allowClear
            placeholder="Tất cả môn"
            value={sportId}
            onChange={(value) => {
              setSportId(value);
              if (value) {
                const selectedCourt = courts.find((court) => (court._id || court.id) === courtId);
                if (selectedCourt && selectedCourt.sportId !== value) setCourtId(undefined);
              }
            }}
            className="w-full lg:w-56"
            options={sports.map((sport) => ({ value: sport._id || sport.id, label: sport.name }))}
          />
        </div>
      </Card>

      <Row gutter={[24, 24]}>
        <Col xs={24} sm={6}>
          <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm h-full">
            <Statistic title="Tổng doanh thu" value={report.summary.paidRevenue} formatter={(val) => <span className="font-bold text-2xl text-brand-orange">{formatVND(numberValue(val))}</span>} prefix={<DollarOutlined />} />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm h-full">
            <Statistic title="Tổng booking" value={report.summary.totalBookings} formatter={(val) => <span className="font-bold text-2xl dark:text-white">{numberValue(val)} ca</span>} prefix={<RiseOutlined className="text-indigo-500" />} />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm h-full">
            <Statistic title="Hoàn tất / Hủy" value={`${report.summary.completedBookings} / ${report.summary.cancelledBookings}`} formatter={(val) => <span className="font-bold text-xl dark:text-white">{val}</span>} prefix={<TrophyOutlined className="text-amber-500" />} />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm h-full">
            <Statistic title="Giờ cao điểm" value={peakHour} formatter={(val) => <span className="font-bold text-sm dark:text-white block truncate">{val}</span>} prefix={<FireOutlined className="text-red-500" />} />
          </Card>
        </Col>
      </Row>

      <Row gutter={[24, 24]}>
        <Col xs={24} lg={16}>
          <Card title="Doanh thu theo ngày" className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm">
            {report.dailyStats.length === 0 ? (
              <Empty description="Chưa có dữ liệu doanh thu theo ngày" />
            ) : (
              <div className="h-[300px] w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={report.dailyStats.map((item) => ({ date: item.label || dayjs(item.date).format('DD/MM'), 'Doanh thu': item.paidRevenue }))}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} opacity={0.2} />
                    <XAxis dataKey="date" tick={{ fontSize: 12 }} />
                    <YAxis tick={{ fontSize: 12 }} />
                    <ChartTooltip formatter={(value) => [formatVND(numberValue(value)), 'Doanh thu']} />
                    <Bar dataKey="Doanh thu" fill="#FF5600" radius={[6, 6, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}
          </Card>
        </Col>
        <Col xs={24} lg={8}>
          <Card title="Booking theo môn" className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm h-full">
            {sportChartData.length === 0 ? (
              <Empty description="Chưa có dữ liệu" />
            ) : (
              <div className="h-[260px] w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={sportChartData} innerRadius={60} outerRadius={85} dataKey="value" paddingAngle={5}>
                      {sportChartData.map((_, index) => <Cell key={index} fill={COLORS[index % COLORS.length]} />)}
                    </Pie>
                    <ChartTooltip />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            )}
          </Card>
        </Col>
      </Row>

      <Row gutter={[24, 24]}>
        <Col xs={24} sm={6}><Card><Statistic title="Thanh toán thành công" value={formatVND(report.summary.paidRevenue)} /></Card></Col>
        <Col xs={24} sm={6}><Card><Statistic title="Thanh toán đang chờ" value={formatVND(report.summary.pendingRevenue)} /></Card></Col>
        <Col xs={24} sm={6}><Card><Statistic title="Hoàn tiền đang chờ" value={formatVND(report.summary.refundPendingAmount)} /></Card></Col>
        <Col xs={24} sm={6}><Card><Statistic title="Tỷ lệ sử dụng" value={percentText(report.summary.utilizationRate)} /></Card></Col>
      </Row>

      <Card
        title="Hiệu suất sân"
        extra={<Input allowClear prefix={<SearchOutlined />} value={searchText} onChange={(event) => setSearchText(event.target.value)} placeholder="Tìm sân..." />}
        className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm"
      >
        <Table
          dataSource={filteredCourtStats}
          columns={courtColumns}
          rowKey={(record) => record.courtId || record.courtName || Math.random().toString()}
          loading={loading}
          pagination={{ pageSize: 8 }}
        />
      </Card>
    </div>
  );
};

export default StaffReportPage;
