import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Button, Card, Col, Descriptions, Empty, Result, Row, Space, Spin, Table, Tag, Typography } from 'antd';
import { ArrowLeftOutlined, CalendarOutlined, LinkOutlined, ReloadOutlined, TeamOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { apiClient } from '../../../../core/network/api_client';
import { authStorage } from '../../../../core/utils/auth_storage';
import { formatVND, minutesToTimeStr } from '../../../../core/utils/formatters';
import { matchingApi } from '../../data/matching_api';
import { MatchingMember, MatchingSession, MatchingTeam } from '../../data/matching_types';

const { Title, Text } = Typography;

const valueText = (...values: any[]) => {
  const value = values.find((item) => item !== undefined && item !== null && item !== '' && item !== 'NaN');
  return value === undefined || value === null ? 'Chưa có dữ liệu' : String(value);
};

const getObjectId = (value: any): string => {
  if (!value) return '';
  if (typeof value === 'string') return value;
  return value.id || value._id || '';
};

const safeNumber = (value: any, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const safeMinutes = (value?: number) => Number.isFinite(Number(value)) ? minutesToTimeStr(Number(value)) : 'Chưa có dữ liệu';

const formatDate = (value?: string) => {
  if (!value) return 'Chưa có dữ liệu';
  const parsed = dayjs(value);
  return parsed.isValid() ? parsed.format('DD/MM/YYYY') : value;
};

const formatDateTime = (value?: string | null) => {
  if (!value) return 'Chưa có dữ liệu';
  const parsed = dayjs(value);
  return parsed.isValid() ? parsed.format('HH:mm DD/MM/YYYY') : value;
};

const statusTag = (status?: string) => {
  const colors: Record<string, string> = {
    OPEN: 'processing',
    FULL: 'success',
    CANCELLED: 'error',
    COMPLETED: 'default',
    PENDING: 'warning',
    APPROVED: 'success',
    REJECTED: 'error',
    SUCCESS: 'success',
    FAILED: 'error',
  };
  const labels: Record<string, string> = {
    OPEN: 'Đang mở',
    FULL: 'Đã đủ người',
    CANCELLED: 'Đã hủy',
    COMPLETED: 'Hoàn thành',
    PENDING: 'Chờ xử lý',
    APPROVED: 'Đã duyệt',
    REJECTED: 'Từ chối',
    SUCCESS: 'Thành công',
    FAILED: 'Thất bại',
  };
  return <Tag color={colors[status || ''] || 'default'}>{labels[status || ''] || valueText(status)}</Tag>;
};

const modeLabel = (mode?: string) => {
  const labels: Record<string, string> = {
    INDIVIDUAL: 'Cá nhân',
    TEAM_FILL: 'Bổ sung đội',
    TEAM_VS_TEAM: 'Đội gặp đội',
  };
  return labels[mode || ''] || valueText(mode);
};

const policyLabel = (policy?: string) => {
  const labels: Record<string, string> = {
    HOST_PAY_ALL: 'Host thanh toán',
    SPLIT_EQUALLY: 'Chia đều',
    TEAM_REPRESENTATIVES_SPLIT: 'Đại diện đội chia tiền',
  };
  return labels[policy || ''] || valueText(policy);
};

const userName = (value: any) => valueText(value?.profile?.fullName, value?.profile?.name, value?.name, value?.email, getObjectId(value));

const extractPaymentsFromBooking = (booking: any): any[] => {
  if (!booking) return [];
  if (Array.isArray(booking.payments)) return booking.payments;
  if (Array.isArray(booking.payment)) return booking.payment;
  if (booking.payment && typeof booking.payment === 'object') return [booking.payment];
  return [];
};

const extractPaymentsFromSession = (session: MatchingSession | null, booking: any): any[] => {
  if (!session) return extractPaymentsFromBooking(booking);
  if (Array.isArray(session.payments)) return session.payments;
  if (Array.isArray(session.payment)) return session.payment;
  if (session.payment && typeof session.payment === 'object') return [session.payment];
  return extractPaymentsFromBooking(booking);
};

const MatchingDetailPage: React.FC = () => {
  const { matchingId = '' } = useParams();
  const navigate = useNavigate();
  const user = authStorage.getUser();
  const rolePrefix = user?.role === 'ADMIN' ? '/admin' : '/staff';
  const [session, setSession] = useState<MatchingSession | null>(null);
  const [booking, setBooking] = useState<any>(null);
  const [payments, setPayments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadDetail = useCallback(async () => {
    if (!matchingId) {
      setError('Thiếu mã phiên ghép trận.');
      setLoading(false);
      return;
    }

    setLoading(true);
    setError('');
    try {
      const detail = await matchingApi.getMatchingSessionById(matchingId);
      if (!detail) {
        setSession(null);
        setError('Không tìm thấy phiên ghép trận.');
        return;
      }
      setSession(detail);

      let bookingDetail = detail.booking || null;
      if (!bookingDetail && detail.bookingId) {
        try {
          const bookingResponse = await apiClient.get(`/booking/${detail.bookingId}`);
          bookingDetail = bookingResponse.data?.booking || bookingResponse.data?.data?.booking || bookingResponse.data?.data || bookingResponse.data;
        } catch {
          bookingDetail = null;
        }
      }
      setBooking(bookingDetail);

      const embeddedPayments = extractPaymentsFromSession(detail, bookingDetail);
      if (embeddedPayments.length > 0) {
        setPayments(embeddedPayments.map((payment) => ({ ...payment, id: payment.id || payment._id || '' })));
      } else if (detail.bookingId) {
        try {
          const paymentResponse = await apiClient.get('/payment', { params: { bookingId: detail.bookingId } });
          const paymentItems = (paymentResponse.data?.items || paymentResponse.data?.payments || paymentResponse.data?.data?.items || [])
            .filter((payment: any) => getObjectId(payment.booking || payment.bookingId) === detail.bookingId || payment.bookingId === detail.bookingId)
            .map((payment: any) => ({ ...payment, id: payment.id || payment._id || '' }));
          setPayments(paymentItems);
        } catch {
          setPayments([]);
        }
      } else {
        setPayments([]);
      }
    } catch (e: any) {
      setSession(null);
      setError(e.response?.data?.message || e.message || 'Không thể tải chi tiết ghép trận.');
    } finally {
      setLoading(false);
    }
  }, [matchingId]);

  useEffect(() => {
    loadDetail();
  }, [loadDetail]);

  const participants = useMemo(() => {
    if (!session) return [];
    const rows: Array<MatchingMember & { key: string; role: string }> = [];
    if (session.host) {
      rows.push({
        key: `host-${session.hostId || session.host.id}`,
        role: 'Host',
        user: session.host,
        userId: session.hostId,
        name: userName(session.host),
        status: 'APPROVED',
        teamCode: session.hostTeamCode || 'A',
        representedCount: safeNumber(session.hostRepresentedCount, 1),
        joinMode: 'HOST',
        teamName: '',
        note: session.description || '',
      });
    }
    (session.members || []).forEach((member, index) => {
      rows.push({
        ...member,
        key: `member-${member.userId || member.user?.id || index}`,
        role: 'Thành viên',
        name: valueText(member.name, userName(member.user)),
      });
    });
    return rows;
  }, [session]);

  const teams = useMemo(() => {
    if (!session) return [];
    if (session.teams && session.teams.length > 0) return session.teams;
    if (session.teamMode === 'INDIVIDUAL') return [];
    return [
      { teamCode: 'A', name: session.teamA?.name || 'Team A', maxPlayers: session.teamSize || 0 },
      { teamCode: 'B', name: session.teamB?.name || 'Team B', maxPlayers: session.teamSize || 0 },
    ];
  }, [session]);

  if (loading) {
    return (
      <div className="min-h-[360px] flex items-center justify-center">
        <Spin size="large" tip="Đang tải chi tiết ghép trận..." />
      </div>
    );
  }

  if (error) {
    return (
      <Result
        status="error"
        title="Không thể tải ghép trận"
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

  if (!session) {
    return (
      <Card className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        <Empty description="Không tìm thấy dữ liệu ghép trận" />
      </Card>
    );
  }

  const bookingId = session.bookingId || getObjectId(booking);
  const fixedScheduleId = session.fixedScheduleId || getObjectId(session.fixedSchedule);
  const requiredPlayers = session.teamMode === 'INDIVIDUAL'
    ? safeNumber(session.totalPlayersNeeded, 0) + 1
    : safeNumber(session.teamSize, 0) * 2;
  const currentPlayers = session.teamMode === 'INDIVIDUAL'
    ? safeNumber(session.approvedCount, 0) + safeNumber(session.hostRepresentedCount, 1)
    : safeNumber(session.teamAOccupancy, 0) + safeNumber(session.teamBOccupancy, 0);

  const participantColumns = [
    {
      title: 'Người chơi',
      key: 'player',
      render: (_: any, record: any) => (
        <div className="flex flex-col leading-tight">
          <span className="font-semibold dark:text-white">{valueText(record.name, userName(record.user))}</span>
          <span className="text-xs text-ink-muted dark:text-ink-darkMuted">{valueText(record.user?.email, record.userId)}</span>
        </div>
      ),
    },
    { title: 'Vai trò', dataIndex: 'role', key: 'role', render: (role: string) => <Tag>{role}</Tag> },
    { title: 'Trạng thái', dataIndex: 'status', key: 'status', render: statusTag },
    { title: 'Đội', dataIndex: 'teamCode', key: 'teamCode', render: (teamCode: string) => valueText(teamCode) },
    { title: 'Số người đại diện', dataIndex: 'representedCount', key: 'representedCount', render: (count: number) => safeNumber(count, 1) },
    { title: 'Thời gian tham gia', dataIndex: 'joinedAt', key: 'joinedAt', render: formatDateTime },
  ];

  const teamColumns = [
    { title: 'Đội', dataIndex: 'teamCode', key: 'teamCode', render: (code: string) => <Tag color="purple">{valueText(code)}</Tag> },
    { title: 'Tên đội', dataIndex: 'name', key: 'name', render: valueText },
    { title: 'Tối đa', dataIndex: 'maxPlayers', key: 'maxPlayers', render: (value: number) => safeNumber(value, 0) },
    {
      title: 'Đại diện',
      dataIndex: 'representativeUserId',
      key: 'representativeUserId',
      render: (value: string, record: MatchingTeam) => valueText(value, record.representative_user_id),
    },
  ];

  const paymentColumns = [
    { title: 'Mã thanh toán', key: 'id', render: (_: any, record: any) => <span className="font-semibold text-brand-orange">{valueText(record.id, record._id)}</span> },
    { title: 'Số tiền', dataIndex: 'amount', key: 'amount', render: (amount: number) => formatVND(safeNumber(amount, 0)) },
    { title: 'Phương thức', dataIndex: 'method', key: 'method', render: valueText },
    { title: 'Trạng thái', dataIndex: 'status', key: 'status', render: statusTag },
    { title: 'Tạo lúc', dataIndex: 'createdAt', key: 'createdAt', render: formatDateTime },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div className="space-y-2">
          <Button icon={<ArrowLeftOutlined />} onClick={() => navigate(-1)} className="rounded-md">
            Quay lại
          </Button>
          <div>
            <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
              Chi tiết ghép trận
            </Title>
            <Text className="text-ink-muted dark:text-ink-darkMuted">
              Mã phiên: <span className="font-semibold text-brand-orange">{session.id}</span>
            </Text>
          </div>
        </div>
        <Space wrap>
          {bookingId && (
            <Button icon={<LinkOutlined />} onClick={() => navigate(`${rolePrefix}/bookings/${bookingId}`)}>
              Mở booking
            </Button>
          )}
          {fixedScheduleId && (
            <Button icon={<CalendarOutlined />} onClick={() => navigate(`${rolePrefix}/fixed-schedules/${fixedScheduleId}`)}>
              Mở lịch cố định
            </Button>
          )}
          <Button icon={<ReloadOutlined />} onClick={loadDetail}>
            Tải lại
          </Button>
        </Space>
      </div>

      <Row gutter={[16, 16]}>
        <Col xs={24} lg={15}>
          <Card title="Thông tin chung" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 h-full">
            <Descriptions column={{ xs: 1, sm: 2 }} bordered size="small">
              <Descriptions.Item label="Trạng thái">{statusTag(session.status)}</Descriptions.Item>
              <Descriptions.Item label="Kiểu ghép">{modeLabel(session.teamMode)}</Descriptions.Item>
              <Descriptions.Item label="Host">{userName(session.host)}</Descriptions.Item>
              <Descriptions.Item label="Thanh toán">{policyLabel(session.paymentPolicy)}</Descriptions.Item>
              <Descriptions.Item label="Cơ sở">{valueText(session.facility?.name, session.facilityId)}</Descriptions.Item>
              <Descriptions.Item label="Sân">{valueText(session.court?.name, session.courtId)}</Descriptions.Item>
              <Descriptions.Item label="Môn thể thao">{valueText(session.sport?.name)}</Descriptions.Item>
              <Descriptions.Item label="Ngày chơi">{formatDate(session.bookingDate)}</Descriptions.Item>
              <Descriptions.Item label="Giờ bắt đầu">{safeMinutes(session.startMinutes)}</Descriptions.Item>
              <Descriptions.Item label="Giờ kết thúc">{safeMinutes(session.endMinutes)}</Descriptions.Item>
              <Descriptions.Item label="Người chơi">{currentPlayers}/{requiredPlayers || valueText(session.totalPlayersNeeded)}</Descriptions.Item>
              <Descriptions.Item label="Còn thiếu">{safeNumber(session.availableSpots, 0)}</Descriptions.Item>
              <Descriptions.Item label="Tự duyệt">{session.autoApprove ? 'Có' : 'Không'}</Descriptions.Item>
              <Descriptions.Item label="Ngày tạo">{formatDateTime(session.createdAt)}</Descriptions.Item>
              <Descriptions.Item label="Mô tả" span={2}>{valueText(session.description)}</Descriptions.Item>
            </Descriptions>
          </Card>
        </Col>

        <Col xs={24} lg={9}>
          <Card title="Booking liên quan" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 h-full">
            <div className="space-y-3 text-sm">
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Mã booking</Text>
                <div className="font-semibold text-brand-orange break-all">{valueText(bookingId)}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Trạng thái booking</Text>
                <div>{statusTag(booking?.status)}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Tổng tiền</Text>
                <div className="font-semibold">{formatVND(safeNumber(booking?.totalPrice ?? booking?.total_price, 0))}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Trạng thái thanh toán</Text>
                <div>{statusTag(booking?.paymentStatus || booking?.payment_status || payments[0]?.status)}</div>
              </div>
              {bookingId && (
                <Button block icon={<LinkOutlined />} onClick={() => navigate(`${rolePrefix}/bookings/${bookingId}`)}>
                  Xem chi tiết booking
                </Button>
              )}
            </div>
          </Card>
        </Col>
      </Row>

      <Card title="Lịch cố định" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        {fixedScheduleId ? (
          <Space wrap>
            <Tag color="blue">Có lịch cố định</Tag>
            <span className="font-semibold text-brand-orange break-all">{fixedScheduleId}</span>
            <Button size="small" icon={<LinkOutlined />} onClick={() => navigate(`${rolePrefix}/fixed-schedules/${fixedScheduleId}`)}>
              Mở lịch cố định
            </Button>
          </Space>
        ) : (
          <Empty description="Phiên ghép trận này không gắn lịch cố định" />
        )}
      </Card>

      <Card title="Người tham gia" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        {participants.length === 0 ? (
          <Empty image={<TeamOutlined className="text-5xl text-ink-subtle" />} description="Chưa có người tham gia" />
        ) : (
          <Table dataSource={participants} columns={participantColumns} rowKey="key" pagination={false} scroll={{ x: 900 }} />
        )}
      </Card>

      <Card title="Đội" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        {teams.length === 0 ? (
          <Empty description="Phiên ghép cá nhân không có cấu hình đội" />
        ) : (
          <Table dataSource={teams} columns={teamColumns} rowKey={(record) => record.teamCode || record.name || String(Math.random())} pagination={false} />
        )}
      </Card>

      <Card title="Thanh toán" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        {payments.length === 0 ? (
          <Empty description="Chưa có dữ liệu thanh toán" />
        ) : (
          <Table dataSource={payments} columns={paymentColumns} rowKey={(record) => record.id || record._id || record.transactionId || String(Math.random())} pagination={false} scroll={{ x: 760 }} />
        )}
      </Card>
    </div>
  );
};

export default MatchingDetailPage;
