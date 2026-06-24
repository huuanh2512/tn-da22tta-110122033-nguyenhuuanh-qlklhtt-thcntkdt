import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { Table, Button, Tabs, Input, Tag, Space, Avatar, Modal, Form, Select, DatePicker, Radio, message, Tooltip, Typography, Row, Col, Card } from 'antd';
import {
  SearchOutlined,
  PlusOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  PlayCircleOutlined,
  UserOutlined,
  EyeOutlined,
  CalendarOutlined,
  TeamOutlined
} from '@ant-design/icons';
import dayjs from 'dayjs';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { authStorage, UserSession } from '../../../../core/utils/auth_storage';
import { getBookingsUseCase, createBookingUseCase, updateBookingStatusUseCase } from '../../../../core/di/injection';
import { Booking } from '../../domain/entities/booking.entity';
import { formatVND, minutesToTimeStr } from '../../../../core/utils/formatters';
import { apiClient } from '../../../../core/network/api_client';

interface CourtItem {
  _id: string;
  name: string;
  code: string;
  facilityId: string;
  sportId: string;
  status: string;
  pricePerHour: number;
}

interface SportItem {
  _id: string;
  name: string;
}

interface SlotItem {
  slotIndex: number;
  startMinutes: number;
  endMinutes: number;
  isAvailable: boolean;
}

const { Search } = Input;
const { Title, Text } = Typography;

const StaffBookingsPage: React.FC = () => {
  const navigate = useNavigate();
  // Khởi tạo user 1 lần duy nhất bằng useMemo
  const user = useMemo(() => authStorage.getUser(), []);
  const [searchParams, setSearchParams] = useSearchParams();

  const [bookings, setBookings] = useState<Booking[]>([]);
  const [users, setUsers] = useState<UserSession[]>([]);
  const [courts, setCourts] = useState<CourtItem[]>([]);
  const [sports, setSports] = useState<SportItem[]>([]);
  const [courtSlots, setCourtSlots] = useState<Record<string, SlotItem[]>>({});
  const [facilityName, setFacilityName] = useState<string>('');

  // UI States
  const [activeTab, setActiveTab] = useState<string>('ALL');
  const [searchText, setSearchText] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [isModalOpen, setIsModalOpen] = useState<boolean>(false);

  // Walk-in booking form state
  const [form] = Form.useForm();
  const [selectedSport, setSelectedSport] = useState<string>('');
  const [selectedCourt, setSelectedCourt] = useState<string>('');
  const [bookingDate, setBookingDate] = useState<string>(dayjs().format('YYYY-MM-DD'));
  const [selectedSlotIndex, setSelectedSlotIndex] = useState<number>(-1);
  const [bookingPrice, setBookingPrice] = useState<number>(0);
  const [submittingBooking, setSubmittingBooking] = useState<boolean>(false);

  const facilityId = user?.facilityId;
  const userRole = user?.role;

  // Redirect if not staff
  useEffect(() => {
    if (!user || userRole !== 'STAFF') {
      navigate('/sign-in');
    }
  }, [user, userRole, navigate]);

  // Load all master data - Tối ưu bằng primitive dependencies và JSON.stringify
  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      // Fetch bookings via usecase
      const list = await getBookingsUseCase.execute();
      setBookings(prev => JSON.stringify(prev) !== JSON.stringify(list) ? list : prev);

      // Fetch courts of this facility
      if (facilityId) {
        const resCourts = await apiClient.get('/court', { params: { facilityId } });
        const courtItems: CourtItem[] = (resCourts.data.items || []).map((c: any) => ({
          ...c, _id: c._id || c.id || ''
        }));
        setCourts(prev => JSON.stringify(prev) !== JSON.stringify(courtItems) ? courtItems : prev);

        // Fetch slot configs for all courts in parallel
        const slotsMap: Record<string, SlotItem[]> = {};
        await Promise.all(courtItems.map(async (court) => {
          try {
            const res = await apiClient.get(`/court/${court._id}/slot-config`);
            const rawSlots = res.data.config?.slots || [];
            slotsMap[court._id] = rawSlots.map((s: any, idx: number) => ({
              slotIndex: s.slotIndex || idx + 1,
              startMinutes: s.startMinutes,
              endMinutes: s.endMinutes,
              isAvailable: s.mode === 'AVAILABLE' || s.isAvailable || false,
            }));
          } catch { slotsMap[court._id] = []; }
        }));
        setCourtSlots(prev => JSON.stringify(prev) !== JSON.stringify(slotsMap) ? slotsMap : prev);

        // Fetch facility name
        try {
          const resFacs = await apiClient.get('/facility');
          const fac = (resFacs.data.items || []).find((f: any) => (f._id || f.id) === facilityId);
          if (fac?.name) setFacilityName(prev => prev !== fac.name ? fac.name : prev);
        } catch { /* ignore */ }
      }

      // Fetch sports
      const resSports = await apiClient.get('/sport');
      const sportItems = (resSports.data.items || []).map((s: any) => ({ ...s, _id: s._id || s.id || '' }));
      setSports(prev => JSON.stringify(prev) !== JSON.stringify(sportItems) ? sportItems : prev);

      // Fetch users (ADMIN ONLY)
      if (userRole === 'ADMIN') {
        const resUsers = await apiClient.get('/user/');
        const userItems = resUsers.data.items || [];
        setUsers(prev => JSON.stringify(prev) !== JSON.stringify(userItems) ? userItems : prev);
      } else {
        setUsers(prev => prev.length !== 0 ? [] : prev);
      }
    } catch (e: any) {
      message.error('Không thể tải danh sách đặt sân');
    } finally {
      setLoading(false);
    }
  }, [facilityId, userRole]); // <-- Đã đổi dependency thành primitive types

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Handle URL redirect query params to auto-open booking modal
  useEffect(() => {
    const courtIdParam = searchParams.get('courtId');
    const startMinutesParam = searchParams.get('startMinutes');
    const dateParam = searchParams.get('date');

    if (courtIdParam && startMinutesParam && dateParam && courts.length > 0) {
      const matchedCourt = courts.find(c => c._id === courtIdParam);
      if (matchedCourt) {
        const slots = courtSlots[courtIdParam] || [];
        setIsModalOpen(true);
        form.setFieldsValue({
          sportId: matchedCourt.sportId,
          courtId: courtIdParam,
          date: dayjs(dateParam),
          paymentMethod: 'CASH'
        });
        setSelectedSport(matchedCourt.sportId);
        setSelectedCourt(courtIdParam);
        setBookingDate(dateParam);

        const matchedSlot = slots.find((s: SlotItem) => s.startMinutes === Number(startMinutesParam));
        if (matchedSlot) {
          setSelectedSlotIndex(matchedSlot.slotIndex);
          const price = Math.round(matchedCourt.pricePerHour * 1);
          setBookingPrice(price);
        }
      }
      setSearchParams({});
    }
  }, [searchParams, courts, courtSlots, form, setSearchParams]);

  // Handle URL search params for booking search/highlight
  useEffect(() => {
    const bookingIdParam = searchParams.get('bookingId') || searchParams.get('search');
    if (bookingIdParam) {
      setSearchText(bookingIdParam);
    }
  }, [searchParams]);

  // Action status changes
  const handleUpdateStatus = async (bookingId: string, status: Booking['status']) => {
    try {
      await updateBookingStatusUseCase.execute(bookingId, status);
      message.success('Cập nhật trạng thái đặt sân thành công!');
      loadData();
    } catch (e: any) {
      message.error(e.message || 'Cập nhật trạng thái thất bại');
    }
  };

  // 5-Step transaction walk-in booking workflow
  const handleCreateWalkinBooking = async (values: any) => {
    if (selectedSlotIndex === -1) {
      message.warning('Vui lòng chọn một ca đấu còn trống!');
      return;
    }
    const matchedCourt = courts.find(c => c._id === selectedCourt);
    const slots = courtSlots[selectedCourt] || [];
    const slot = slots.find((s: SlotItem) => s.slotIndex === selectedSlotIndex);
    if (!matchedCourt || !slot) return;

    setSubmittingBooking(true);
    try {
      const booking = await createBookingUseCase.execute(
        selectedCourt,
        bookingDate,
        slot.startMinutes,
        slot.endMinutes,
        bookingPrice,
        values.customerId || undefined
      );

      const paymentResponse = await apiClient.post('/payment', {
        bookingId: booking.id,
        amount: bookingPrice,
        method: values.paymentMethod,
        transactionId: values.paymentMethod === 'CASH' ? `CASH_${Date.now()}` : undefined
      });
      const paymentId = paymentResponse.data.payment?._id || paymentResponse.data.payment?.id;

      await apiClient.put(`/payment/${paymentId}/status`, {
        status: 'SUCCESS',
        transactionId: values.paymentMethod === 'BANK_TRANSFER' ? `OFF_${Date.now()}` : `CASH_CONFIRM_${Date.now()}`
      });

      await updateBookingStatusUseCase.execute(booking.id, 'CONFIRMED');

      message.success('Đặt lịch và thanh toán tại quầy thành công!');
      setIsModalOpen(false);
      form.resetFields();
      setSelectedSlotIndex(-1);
      setBookingPrice(0);
      loadData();
    } catch (e: any) {
      message.error(e.response?.data?.message || e.message || 'Giao dịch đặt lịch tại quầy thất bại.');
    } finally {
      setSubmittingBooking(false);
    }
  };

  // Available slots calculating logic
  const availableSlots = useMemo(() => {
    if (!selectedCourt) return [];
    const slots = courtSlots[selectedCourt] || [];

    return slots.map((slot: SlotItem) => {
      const isBooked = bookings.some(
        b => b.courtId === selectedCourt &&
          b.bookingDate === bookingDate &&
          b.status !== 'CANCELLED' &&
          !(slot.endMinutes <= b.startMinutes || slot.startMinutes >= b.endMinutes)
      );

      const isToday = bookingDate === dayjs().format('YYYY-MM-DD');
      let isPast = false;
      if (isToday) {
        const now = new Date();
        const currentMinutes = now.getHours() * 60 + now.getMinutes();
        isPast = slot.endMinutes <= currentMinutes;
      }

      return {
        ...slot,
        isAvailable: slot.isAvailable && !isBooked && !isPast
      };
    });
  }, [selectedCourt, bookingDate, bookings, courtSlots]);

  const handleCourtChange = (courtId: string) => {
    setSelectedCourt(courtId);
    setSelectedSlotIndex(-1);
    const matchedCourt = courts.find(c => c._id === courtId);
    if (matchedCourt) {
      const price = Math.round(matchedCourt.pricePerHour * 1);
      setBookingPrice(price);
    }
  };

  // Filter list of bookings
  const filteredBookings = useMemo(() => {
    return bookings
      .filter(b => courts.some(c => c._id === b.courtId))
      .filter(b => {
        if (activeTab !== 'ALL' && b.status !== activeTab) return false;

        if (searchText) {
          const recordUser = (b as any).user || (typeof b.userId === 'object' ? b.userId : null);
          const userProfile = recordUser || users.find(u => u._id === b.userId || u.id === b.userId);
          const userName = (userProfile?.profile?.fullName || userProfile?.name || '').toLowerCase();
          const userPhone = userProfile?.profile?.phone || userProfile?.phone || '';
          const bookingId = b.id.toLowerCase();
          const query = searchText.toLowerCase();

          return bookingId.includes(query) || userName.includes(query) || userPhone.includes(query);
        }

        return true;
      })
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }, [bookings, activeTab, searchText, users, courts]);

  const columns = [
    {
      title: 'Mã Đặt Lịch',
      dataIndex: 'id',
      key: 'id',
      render: (id: string, record: Booking) => {
        const isFixed = Boolean(record.isFixedSchedule || record.fixedScheduleId);
        const isMatching = Boolean(record.matchingSessionId || (record as any).matching_session_id);
        const isFixedMatching = isFixed && isMatching;
        return (
          <div>
            <span className="font-semibold text-brand-orange text-xs block">{id}</span>
            {isFixedMatching && (
              <Tag icon={<TeamOutlined />} color="purple" className="border-none text-[10px] px-1 py-0 mt-1 rounded">Ghép cố định</Tag>
            )}
            {!isFixedMatching && isFixed && (
              <Tag icon={<CalendarOutlined />} color="blue" className="border-none text-[10px] px-1 py-0 mt-1 rounded">Lịch cố định</Tag>
            )}
            {!isFixedMatching && !isFixed && isMatching && (
              <Tag icon={<TeamOutlined />} color="orange" className="border-none text-[10px] px-1 py-0 mt-1 rounded">Ghép trận</Tag>
            )}
          </div>
        );
      },
    },
    {
      title: 'Khách hàng',
      key: 'customer',
      render: (_: any, record: Booking) => {
        const recordUser = (record as any).user || (typeof record.userId === 'object' ? record.userId : null);
        const customer = recordUser || users.find(u => u._id === record.userId || u.id === record.userId);
        return (
          <div className="flex items-center gap-2">
            <Avatar
              src={customer?.profile?.avatar || `https://api.dicebear.com/7.x/adventurer/svg?seed=${record.userId}`}
              icon={<UserOutlined />}
              className="bg-brand-orange"
            />
            <div className="flex flex-col leading-tight">
              <span className="font-semibold text-sm dark:text-white">
                {customer?.profile?.fullName || customer?.name || 'Khách hàng Quầy'}
              </span>
              <span className="text-xs text-ink-muted dark:text-ink-darkMuted mt-0.5">
                {customer?.profile?.phone || customer?.phone || 'N/A'}
              </span>
            </div>
          </div>
        );
      }
    },
    {
      title: 'Sân đấu',
      key: 'court',
      render: (_: any, record: Booking) => {
        const court = courts.find(c => c._id === record.courtId);
        return <span className="font-medium dark:text-white">{court?.name || 'Sân trống'}</span>;
      }
    },
    {
      title: 'Ngày đặt',
      dataIndex: 'bookingDate',
      key: 'bookingDate',
      render: (date: string) => <span className="dark:text-white">{dayjs(date).format('DD/MM/YYYY')}</span>
    },
    {
      title: 'Khung giờ',
      key: 'time',
      render: (_: any, record: Booking) => (
        <span className="font-medium text-indigo-500">
          {minutesToTimeStr(record.startMinutes)} - {minutesToTimeStr(record.endMinutes)}
        </span>
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
      render: (status: Booking['status']) => {
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
      render: (_: any, record: Booking) => {
        const isFixed = Boolean(record.isFixedSchedule || record.fixedScheduleId);
        if (record.status === 'PENDING') {
          return (
            <Space size="small" onClick={(event) => event.stopPropagation()}>
              <Tooltip title="Chi tiết">
                <Button
                  shape="circle"
                  icon={<EyeOutlined />}
                  onClick={() => navigate(`/staff/bookings/${record.id}`)}
                />
              </Tooltip>
              {isFixed ? (
                <Tooltip title="Lịch cố định — hệ thống tự quản lý, không cần duyệt">
                  <Tag color="blue" className="border-none font-semibold px-2 py-0.5 rounded cursor-default">
                    <CalendarOutlined /> Tự động
                  </Tag>
                </Tooltip>
              ) : (
                <>
                  <Tooltip title="Duyệt Check-in">
                    <Button
                      type="primary"
                      shape="circle"
                      icon={<CheckCircleOutlined />}
                      onClick={() => handleUpdateStatus(record.id, 'CONFIRMED')}
                      className="bg-emerald-600 hover:bg-emerald-500 border-none"
                    />
                  </Tooltip>
                  <Tooltip title="Từ chối / Hủy">
                    <Button
                      danger
                      shape="circle"
                      icon={<CloseCircleOutlined />}
                      onClick={() => handleUpdateStatus(record.id, 'CANCELLED')}
                    />
                  </Tooltip>
                </>
              )}
            </Space>
          );
        }
        if (record.status === 'CONFIRMED') {
          return (
            <Space size="small" onClick={(event) => event.stopPropagation()}>
              <Tooltip title="Chi tiết">
                <Button
                  shape="circle"
                  icon={<EyeOutlined />}
                  onClick={() => navigate(`/staff/bookings/${record.id}`)}
                />
              </Tooltip>
              <Button
                type="primary"
                size="small"
                icon={<PlayCircleOutlined />}
                onClick={() => handleUpdateStatus(record.id, 'COMPLETED')}
                className="bg-indigo-600 hover:bg-indigo-500 border-none rounded-md"
              >
                Kết thúc ca
              </Button>
              <Tooltip title="Hủy ca">
                <Button
                  danger
                  shape="circle"
                  size="small"
                  icon={<CloseCircleOutlined />}
                  onClick={() => handleUpdateStatus(record.id, 'CANCELLED')}
                />
              </Tooltip>
            </Space>
          );
        }
        return (
          <Space size="small" onClick={(event) => event.stopPropagation()}>
            <Tooltip title="Chi tiết">
              <Button
                shape="circle"
                icon={<EyeOutlined />}
                onClick={() => navigate(`/staff/bookings/${record.id}`)}
              />
            </Tooltip>
          </Space>
        );
      }
    }
  ];

  if (user && userRole === 'STAFF' && !facilityId) {
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
            Quản lý Lịch đặt
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Duyệt yêu cầu đặt lịch, check-in, và tạo giao dịch đặt lịch tại quầy cho khách vãng lai.
          </Text>
        </div>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={() => {
            setIsModalOpen(true);
            form.setFieldsValue({ date: dayjs(), paymentMethod: 'CASH' });
          }}
          size="large"
          className="bg-brand-orange hover:bg-brand-orange/90 border-none rounded-md font-semibold shrink-0 shadow-md shadow-brand-orange/20"
        >
          Đặt lịch tại quầy
        </Button>
      </div>

      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <Tabs
          activeKey={activeTab}
          onChange={setActiveTab}
          items={[
            { key: 'ALL', label: 'Tất cả' },
            { key: 'PENDING', label: 'Chờ duyệt' },
            { key: 'CONFIRMED', label: 'Đã xác nhận' },
            { key: 'COMPLETED', label: 'Đã hoàn thành' },
            { key: 'CANCELLED', label: 'Đã hủy' }
          ]}
          className="w-full md:w-auto"
        />
        <Search
          placeholder="Tìm theo mã đặt, tên khách, số điện thoại..."
          allowClear
          enterButton={<SearchOutlined />}
          size="large"
          onSearch={setSearchText}
          onChange={(e) => setSearchText(e.target.value)}
          className="w-full md:w-80 shrink-0 custom-search"
        />
      </div>

      <Table
        dataSource={filteredBookings}
        columns={columns}
        rowKey="id"
        loading={loading}
        pagination={{ pageSize: 8 }}
        onRow={(record) => ({
          onClick: () => navigate(`/staff/bookings/${record.id}`),
          className: 'cursor-pointer',
        })}
        className="border border-semantic-border/10 dark:border-semantic-borderDark/10 rounded-xl overflow-hidden shadow-sm bg-white dark:bg-surface-dark1"
      />

      <Modal
        title={<span className="font-bold text-lg dark:text-white">Đặt Lịch & Thanh Toán Tại Quầy</span>}
        open={isModalOpen}
        onCancel={() => {
          setIsModalOpen(false);
          form.resetFields();
          setSelectedSlotIndex(-1);
          setBookingPrice(0);
        }}
        footer={null}
        width={600}
        destroyOnClose
        className="dark:bg-surface-dark1"
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleCreateWalkinBooking}
          className="mt-4"
        >
          <Form.Item label={<span className="font-semibold dark:text-white">Cơ sở vận hành</span>}>
            <Input
              value={facilityName || 'Cơ sở của tôi'}
              disabled
              className="rounded-md font-semibold text-brand-orange bg-canvas/30 dark:bg-surface-dark2"
            />
          </Form.Item>

          <Row gutter={16}>
            <Col span={12}>
              <Form.Item
                name="sportId"
                label={<span className="font-semibold dark:text-white">Môn thể thao</span>}
                rules={[{ required: true, message: 'Vui lòng chọn môn thể thao!' }]}
              >
                <Select
                  placeholder="Chọn môn thể thao"
                  onChange={(val) => {
                    setSelectedSport(val);
                    setSelectedCourt('');
                    setSelectedSlotIndex(-1);
                    form.setFieldsValue({ courtId: undefined });
                  }}
                  className="rounded-md"
                >
                  {sports.map(s => (
                    <Select.Option key={s._id} value={s._id}>{s.name}</Select.Option>
                  ))}
                </Select>
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item
                name="courtId"
                label={<span className="font-semibold dark:text-white">Sân đấu</span>}
                rules={[{ required: true, message: 'Vui lòng chọn sân đấu!' }]}
              >
                <Select
                  placeholder="Chọn sân"
                  disabled={!selectedSport}
                  onChange={handleCourtChange}
                  className="rounded-md"
                >
                  {courts
                    .filter(c => c.sportId === selectedSport && c.status === 'ACTIVE')
                    .map(c => (
                      <Select.Option key={c._id} value={c._id}>{c.name} ({c.code})</Select.Option>
                    ))}
                </Select>
              </Form.Item>
            </Col>
          </Row>

          <Form.Item
            name="date"
            label={<span className="font-semibold dark:text-white">Ngày đặt lịch</span>}
            rules={[{ required: true, message: 'Vui lòng chọn ngày đặt!' }]}
          >
            <DatePicker
              value={dayjs(bookingDate)}
              onChange={(date) => {
                if (date) {
                  setBookingDate(date.format('YYYY-MM-DD'));
                  setSelectedSlotIndex(-1);
                }
              }}
              allowClear={false}
              className="w-full rounded-md"
            />
          </Form.Item>

          {selectedCourt && (
            <div className="mb-6">
              <span className="block font-semibold mb-2 dark:text-white">Chọn Ca đấu (Slot):</span>
              <div className="grid grid-cols-4 gap-2">
                {availableSlots.map(slot => (
                  <Button
                    key={slot.slotIndex}
                    type={selectedSlotIndex === slot.slotIndex ? 'primary' : 'default'}
                    disabled={!slot.isAvailable}
                    onClick={() => setSelectedSlotIndex(slot.slotIndex)}
                    className={`h-auto py-2 rounded-md flex flex-col items-center justify-center border ${selectedSlotIndex === slot.slotIndex
                        ? 'bg-brand-orange border-brand-orange text-white'
                        : slot.isAvailable
                          ? 'border-emerald-200 bg-emerald-50/30 text-emerald-700 hover:border-emerald-400'
                          : 'bg-neutral-100 dark:bg-neutral-800 border-neutral-200 text-neutral-400 cursor-not-allowed'
                      }`}
                  >
                    <span className="font-bold text-xs">Ca {slot.slotIndex}</span>
                    <span className="text-[10px] mt-0.5">{minutesToTimeStr(slot.startMinutes)} - {minutesToTimeStr(slot.endMinutes)}</span>
                  </Button>
                ))}
              </div>
            </div>
          )}

          <Form.Item
            name="paymentMethod"
            label={<span className="font-semibold dark:text-white">Phương thức thanh toán</span>}
            rules={[{ required: true, message: 'Chọn phương thức thanh toán!' }]}
          >
            <Radio.Group className="w-full">
              <Radio value="CASH" className="font-medium dark:text-white">Tiền mặt (Offline)</Radio>
              <Radio value="BANK_TRANSFER" className="font-medium dark:text-white">Chuyển khoản / QR (Online)</Radio>
            </Radio.Group>
          </Form.Item>

          {bookingPrice > 0 && selectedSlotIndex !== -1 && (
            <Card className="bg-brand-orange/5 border border-brand-orange/20 rounded-md py-1 mb-6 text-center">
              <span className="text-ink-muted dark:text-ink-darkMuted text-xs block">TỔNG TIỀN THANH TOÁN TẠI QUẦY</span>
              <span className="text-2xl font-bold text-brand-orange block mt-1">{formatVND(bookingPrice)}</span>
            </Card>
          )}

          <div className="flex gap-3 justify-end border-t border-semantic-border/10 dark:border-semantic-borderDark/10 pt-4 mt-6">
            <Button
              onClick={() => {
                setIsModalOpen(false);
                form.resetFields();
                setSelectedSlotIndex(-1);
                setBookingPrice(0);
              }}
              className="rounded-md"
            >
              Hủy bỏ
            </Button>
            <Button
              type="primary"
              htmlType="submit"
              loading={submittingBooking}
              className="bg-brand-orange hover:bg-brand-orange/90 border-none font-semibold rounded-md shadow-md"
            >
              Xác nhận Đặt & Thu tiền
            </Button>
          </div>
        </Form>
      </Modal>
    </div>
  );
};

export default StaffBookingsPage;
