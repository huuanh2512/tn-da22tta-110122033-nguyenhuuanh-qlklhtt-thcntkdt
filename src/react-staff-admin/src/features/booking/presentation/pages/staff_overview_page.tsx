import React, { useState, useEffect, useMemo } from 'react';
import { Card, Col, Row, Statistic, DatePicker, Tag, Typography } from 'antd';
import {
  DollarOutlined,
  CalendarOutlined,
  PercentageOutlined,
  ClockCircleOutlined
} from '@ant-design/icons';
import dayjs from 'dayjs';
import { useNavigate } from 'react-router-dom';
import { authStorage } from '../../../../core/utils/auth_storage';
import { apiClient } from '../../../../core/network/api_client';
import { formatVND, minutesToTimeStr } from '../../../../core/utils/formatters';

const { Title, Text } = Typography;

interface CourtSlot {
  slotIndex: number;
  startMinutes: number;
  endMinutes: number;
  isAvailable: boolean;
}

interface Court {
  _id: string;
  name: string;
  code: string;
  facilityId: string;
  sportId: string;
  sport?: { id?: string; _id?: string; name?: string };
  sportName?: string;
  status: string;
  pricePerHour: number;
  slots: CourtSlot[];
  slotDurationMinutes: number;
}

interface SportItem {
  _id: string;
  id?: string;
  name: string;
}

interface BookingItem {
  _id: string;
  id?: string;
  courtId: string;
  userId: string;
  bookingDate: string;
  startMinutes: number;
  endMinutes: number;
  totalPrice: number;
  status: 'PENDING' | 'CONFIRMED' | 'COMPLETED' | 'CANCELLED';
  fixedScheduleId?: string;
  fixed_schedule_id?: string;
  isFixedSchedule?: boolean;
  is_fixed_schedule?: boolean;
  isMatching?: boolean;
  matchingSessionId?: string;
  matching_session_id?: string;
}

const StaffOverviewPage: React.FC = () => {
  const navigate = useNavigate();
  // Khởi tạo user 1 lần duy nhất để tránh bị tạo mới object mỗi lần render
  const user = useMemo(() => authStorage.getUser(), []);

  const [selectedDate, setSelectedDate] = useState<string>(dayjs().format('YYYY-MM-DD'));
  const [courts, setCourts] = useState<Court[]>([]);
  const [bookings, setBookings] = useState<BookingItem[]>([]);
  const [loading, setLoading] = useState(false);

  const facilityId = user?.facilityId;

  const getSportName = (court: Court, sports: SportItem[]) => {
    if (court.sport?.name) return court.sport.name;
    if (court.sportName) return court.sportName;
    const sport = sports.find((item) => item._id === court.sportId || item.id === court.sportId);
    return sport?.name || 'Chưa gán môn';
  };

  const getSlotBadge = (
    label: string,
    isPending: boolean,
    isCompleted: boolean,
    isFixedSchedule: boolean,
    isMatching: boolean,
  ) => {
    const isFixedMatching = isFixedSchedule && isMatching;
    if (isFixedMatching) return { color: 'purple', text: 'Ghép cố định' };
    if (isFixedSchedule) return { color: 'blue', text: 'Lịch cố định' };
    if (isMatching) return { color: 'magenta', text: 'Ghép trận' };
    if (isPending) return { color: 'warning', text: label };
    if (isCompleted) return { color: 'default', text: label };
    return { color: 'processing', text: label };
  };

  // 1. Kiểm tra quyền truy cập
  useEffect(() => {
    if (!user || user.role !== 'STAFF') {
      navigate('/sign-in');
    }
  }, [user, navigate]);

  // 2. Logic gọi API siêu an toàn chống lặp vô tận (Infinite Loop Prevention)
  useEffect(() => {
    if (!facilityId) return;

    let isMounted = true; // Cờ hiệu ngăn chặn update state khi component đã unmount

    const fetchAllData = async () => {
      try {
        // Lấy danh sách sân
        const [resCourts, resSports] = await Promise.all([
          apiClient.get('/court', { params: { facilityId } }),
          apiClient.get('/sport'),
        ]);
        const sports: SportItem[] = (resSports.data.items || []).map((sport: any) => ({
          ...sport,
          _id: sport._id || sport.id || '',
        }));
        const courtItems: Court[] = (resCourts.data.items || []).map((c: any) => ({
          ...c,
          _id: c._id || c.id || '',
          sportId: c.sportId || c.sport_id || c.sport?.id || c.sport?._id || '',
          sportName: getSportName({
            ...c,
            _id: c._id || c.id || '',
            sportId: c.sportId || c.sport_id || c.sport?.id || c.sport?._id || '',
            slots: [],
            slotDurationMinutes: 60,
          }, sports),
          slots: [],
          slotDurationMinutes: 60,
        }));

        if (courtItems.length === 0) {
          if (isMounted) {
            setCourts([]);
            setBookings([]);
          }
          return;
        }

        // Lấy cấu hình Slot của từng sân (Chạy song song không chặn nhau)
        const courtsWithSlots = await Promise.allSettled(
          courtItems.map(async (court) => {
            try {
              const resSlot = await apiClient.get(`/court/${court._id}/slot-config`);
              const config = resSlot.data.config;
              const rawSlots = config?.slots || [];
              const mappedSlots = rawSlots.map((s: any, idx: number) => ({
                slotIndex: s.slotIndex || idx + 1,
                startMinutes: s.startMinutes,
                endMinutes: s.endMinutes,
                isAvailable: s.mode === 'AVAILABLE' || s.isAvailable || false,
              }));
              return { ...court, slots: mappedSlots, slotDurationMinutes: config?.slotDurationMinutes || 60 };
            } catch (error) {
              return { ...court, slots: [], slotDurationMinutes: 60 };
            }
          })
        );

        const validCourts = courtsWithSlots.map((res, idx) =>
          res.status === 'fulfilled' ? res.value : courtItems[idx]
        );

        // Lấy danh sách Booking theo ngày
        const resBookings = await apiClient.get('/booking', { params: { bookingDate: selectedDate } });
        const bookingItems: BookingItem[] = (resBookings.data.items || []).map((b: any) => ({
          ...b,
          _id: b._id || b.id || '',
          id: b.id || b._id || '',
          courtId: b.courtId || b.court_id || b.court?.id || b.court?._id || '',
          fixedScheduleId: b.fixedScheduleId || b.fixed_schedule_id || b.fixedSchedule?.id || b.fixedSchedule?._id || '',
          isFixedSchedule: Boolean(b.isFixedSchedule || b.is_fixed_schedule || b.fixedScheduleId || b.fixed_schedule_id || b.fixedSchedule),
          isMatching: Boolean(b.isMatching || b.is_matching || b.matchingSessionId || b.matching_session_id || b.source === 'MATCHING'),
          matchingSessionId: b.matchingSessionId || b.matching_session_id || b.matchingSession?.id || b.matchingSession?._id || '',
        }));

        // Chỉ cập nhật state nếu component chưa bị hủy
        if (isMounted) {
          setCourts(validCourts);
          setBookings(bookingItems);
        }
      } catch (error: any) {
        console.error('[ERROR] Failed to fetch dashboard data:', error);
      }
    };

    // A. Chạy lần đầu tiên & Hiển thị Loading
    setLoading(true);
    fetchAllData().finally(() => {
      if (isMounted) setLoading(false);
    });

    // B. Đặt lịch chạy ngầm mỗi 15 giây (Không hiển thị Loading để UX mượt mà)
    const intervalId = setInterval(() => {
      fetchAllData();
    }, 15000);

    // C. Dọn dẹp bộ nhớ khi chuyển trang hoặc đổi ngày
    return () => {
      isMounted = false;
      clearInterval(intervalId);
    };
  }, [facilityId, selectedDate]); // <- Dependency chỉ chứa các giá trị nguyên thủy (string), đảm bảo KHÔNG BAO GIỜ lặp.

  // 3. Tính toán số liệu thống kê (Sử dụng useMemo để tối ưu hiệu năng)
  const stats = useMemo(() => {
    const dailyBookings = bookings.filter(b =>
      b.bookingDate === selectedDate &&
      courts.some(c => c._id === b.courtId) &&
      (b.status === 'CONFIRMED' || b.status === 'COMPLETED' || b.status === 'PENDING')
    );

    const revenue = dailyBookings
      .filter(b => b.status === 'CONFIRMED' || b.status === 'COMPLETED')
      .reduce((sum, b) => sum + b.totalPrice, 0);

    const totalBookedSlots = dailyBookings.length;
    const totalSlots = courts.reduce((sum, c) => sum + c.slots.filter(s => s.isAvailable).length, 0);
    const occupancyRate = totalSlots > 0 ? Math.round((totalBookedSlots / totalSlots) * 100) : 0;

    return { revenue, totalBookings: totalBookedSlots, occupancyRate };
  }, [bookings, courts, selectedDate]);

  // 4. Helper function để xác định trạng thái hiển thị của từng Slot
  const getSlotStatus = (court: Court, slot: CourtSlot) => {
    if (court.status === 'MAINTENANCE' || court.status === 'INACTIVE') {
      return { status: 'UNAVAILABLE', label: 'Bảo trì', booking: null };
    }
    if (!slot.isAvailable) {
      return { status: 'UNAVAILABLE', label: 'Không hoạt động', booking: null };
    }

    const isToday = selectedDate === dayjs().format('YYYY-MM-DD');
    if (isToday) {
      const now = new Date();
      const currentMinutes = now.getHours() * 60 + now.getMinutes();
      if (slot.endMinutes <= currentMinutes) {
        return { status: 'UNAVAILABLE', label: 'Đã quá giờ', booking: null };
      }
    }

    const booking = bookings.find(
      b => b.courtId === court._id &&
        b.bookingDate === selectedDate &&
        b.status !== 'CANCELLED' &&
        !(slot.endMinutes <= b.startMinutes || slot.startMinutes >= b.endMinutes)
    );

    if (booking) {
      const statusLabels: Record<string, string> = {
        PENDING: 'Chờ duyệt',
        CONFIRMED: 'Đã đặt',
        COMPLETED: 'Hoàn thành',
        CANCELLED: 'Đã hủy'
      };
      return { status: 'BOOKED', label: statusLabels[booking.status] || 'Đã đặt', booking };
    }

    return { status: 'AVAILABLE', label: 'Còn trống', booking: null };
  };

  const handleSlotClick = (courtId: string, slot: CourtSlot, status: string, booking: BookingItem | null) => {
    const bookingId = booking?.id || booking?._id;
    if (status === 'BOOKED' && booking?.matchingSessionId) {
      navigate(`/staff/matching/${booking.matchingSessionId}`);
      return;
    }

    if (status === 'BOOKED' && booking?.status === 'PENDING' && bookingId) {
      navigate(`/staff/bookings/${bookingId}`);
      return;
    }

    if (status === 'AVAILABLE') {
      navigate(`/staff/bookings?courtId=${courtId}&startMinutes=${slot.startMinutes}&endMinutes=${slot.endMinutes}&date=${selectedDate}`);
    }
  };

  // Màn hình báo lỗi nếu nhân viên chưa có cơ sở
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
      {/* Header and Date Filter */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div>
          <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
            Tổng quan Sơ đồ Sân
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Xem trạng thái thời gian thực và quản lý nhanh các khung giờ đặt sân.
          </Text>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <span className="font-semibold text-sm text-ink-muted dark:text-ink-darkMuted">Chọn ngày:</span>
          <DatePicker
            value={dayjs(selectedDate)}
            onChange={(date) => {
              if (date) setSelectedDate(date.format('YYYY-MM-DD'));
            }}
            allowClear={false}
            size="large"
            className="rounded-md dark:bg-surface-dark2 dark:text-white dark:border-semantic-borderDark"
          />
        </div>
      </div>

      {/* KPI Cards */}
      <Row gutter={[24, 24]}>
        <Col xs={24} sm={8}>
          <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm hover:shadow-md transition-shadow">
            <Statistic
              title={<span className="text-ink-muted dark:text-ink-darkMuted font-medium text-sm">Doanh thu ngày ({selectedDate})</span>}
              value={stats.revenue}
              formatter={(val) => <span className="font-bold text-2xl text-brand-orange">{formatVND(val as number)}</span>}
              prefix={<DollarOutlined className="text-brand-orange mr-1" />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={8}>
          <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm hover:shadow-md transition-shadow">
            <Statistic
              title={<span className="text-ink-muted dark:text-ink-darkMuted font-medium text-sm">Ca đấu đã đặt</span>}
              value={stats.totalBookings}
              formatter={(val) => <span className="font-bold text-2xl text-ink dark:text-white">{val} ca</span>}
              prefix={<CalendarOutlined className="text-indigo-500 mr-1" />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={8}>
          <Card className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm hover:shadow-md transition-shadow">
            <Statistic
              title={<span className="text-ink-muted dark:text-ink-darkMuted font-medium text-sm">Tỷ lệ lấp đầy sân</span>}
              value={stats.occupancyRate}
              formatter={(val) => <span className="font-bold text-2xl text-ink dark:text-white">{val}%</span>}
              prefix={<PercentageOutlined className="text-semantic-success mr-1" />}
            />
          </Card>
        </Col>
      </Row>

      {/* Timeline Board */}
      <Card
        title={<span className="font-semibold text-base dark:text-white">Lưới Sơ đồ Sân & Ca đấu</span>}
        loading={loading}
        className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm overflow-hidden"
      >
        {courts.length === 0 ? (
          <div className="text-center py-12 text-ink-muted dark:text-ink-darkMuted">
            Không tìm thấy sân đấu nào cho cơ sở của bạn.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <div className="min-w-[800px] divide-y divide-semantic-border/20 dark:divide-semantic-borderDark/20">
              {courts.map((court) => (
                <div key={court._id} className="py-4 flex items-center">
                  {/* Left Column: Court Info */}
                  <div className="w-48 pr-4 flex-shrink-0">
                    <span className="block font-bold text-base dark:text-white">{court.name}</span>
                    <span className="text-xs text-brand-orange font-semibold block mt-0.5">{court.sportName || 'Chưa gán môn'}</span>
                    <span className="text-xs text-ink-subtle dark:text-ink-darkSubtle block mt-1">
                      {formatVND(court.pricePerHour)}/giờ
                    </span>
                  </div>

                  {/* Right Column: Horizontally Scrolling Slots Grid */}
                  <div className="flex-1 overflow-x-auto flex gap-3 py-1 px-2">
                    {court.slots.length === 0 ? (
                      <span className="text-xs text-ink-muted dark:text-ink-darkMuted italic py-2">Chưa có cấu hình slot</span>
                    ) : court.slots.map((slot) => {
                      const { status, label, booking } = getSlotStatus(court, slot);

                      let cardClass = '';
                      let badge = null;

                      if (status === 'AVAILABLE') {
                        cardClass = 'bg-emerald-50 dark:bg-emerald-950/20 border border-emerald-200 dark:border-emerald-800/40 hover:bg-emerald-100 dark:hover:bg-emerald-950/30 cursor-pointer';
                        badge = <Tag color="success" className="m-0 border-none px-2 rounded-md font-medium text-xs">Còn trống</Tag>;
                      } else if (status === 'BOOKED') {
                        const isPending = (booking as BookingItem)?.status === 'PENDING';
                        const isCompleted = (booking as BookingItem)?.status === 'COMPLETED';
                        const isFixedSchedule = Boolean((booking as BookingItem)?.isFixedSchedule || (booking as BookingItem)?.fixedScheduleId);
                        const isMatching = Boolean((booking as BookingItem)?.isMatching || (booking as BookingItem)?.matchingSessionId);
                        const isFixedMatching = isFixedSchedule && isMatching;

                        cardClass = isPending
                          ? isFixedMatching
                            ? 'bg-violet-50 dark:bg-violet-950/20 border border-violet-200 dark:border-violet-800/40 opacity-95 hover:bg-violet-100 dark:hover:bg-violet-950/30 cursor-pointer'
                            : 'bg-amber-50 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-800/40 opacity-90 hover:bg-amber-100 dark:hover:bg-amber-950/30 cursor-pointer'
                          : isCompleted
                            ? 'bg-gray-100 dark:bg-neutral-800/40 border border-neutral-300 dark:border-neutral-700/40 opacity-70'
                            : 'bg-indigo-50 dark:bg-indigo-950/20 border border-indigo-200 dark:border-indigo-800/40 opacity-90';

                        const slotBadge = getSlotBadge(label, isPending, isCompleted, isFixedSchedule, isMatching);
                        badge = (
                          <>
                            <Tag color={slotBadge.color} className="m-0 border-none px-2 rounded-md font-medium text-xs max-w-full truncate">
                              {isFixedMatching ? 'Ghép cố định' : isFixedSchedule ? 'Lịch cố định' : isMatching ? 'Ghép trận' : label}
                            </Tag>
                            {false ? (
                              <Tag color="processing" className="m-0 border-none px-2 rounded-md font-medium text-xs">
                                Đã có trận
                              </Tag>
                            ) : false && (
                              <Tag color={isPending ? 'warning' : isCompleted ? 'default' : 'processing'} className="m-0 border-none px-2 rounded-md font-medium text-xs">
                                {label}
                              </Tag>
                            )}
                          </>
                        );
                      } else {
                        cardClass = 'bg-neutral-100 dark:bg-neutral-800/20 border border-neutral-200 dark:border-neutral-800/40 opacity-50 cursor-not-allowed';
                        badge = <Tag color="default" className="m-0 border-none px-2 rounded-md font-medium text-xs">{label}</Tag>;
                      }

                      return (
                        <div
                          key={slot.slotIndex}
                          onClick={() => handleSlotClick(court._id, slot, status, booking as BookingItem | null)}
                          className={`w-36 flex-shrink-0 p-3 rounded-lg flex flex-col justify-between h-24 transition-all shadow-sm overflow-hidden ${cardClass}`}
                        >
                          <div className="flex items-center justify-between">
                            <span className="font-bold text-sm text-ink dark:text-white">
                              Ca {slot.slotIndex}
                            </span>
                            <ClockCircleOutlined className="text-xs text-ink-subtle dark:text-ink-darkSubtle" />
                          </div>

                          <div className="text-xs text-ink-muted dark:text-ink-darkMuted font-medium mt-1">
                            {minutesToTimeStr(slot.startMinutes)} - {minutesToTimeStr(slot.endMinutes)}
                          </div>

                          <div className="mt-2 flex">
                            {badge}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </Card>
    </div>
  );
};

export default StaffOverviewPage;
