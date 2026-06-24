import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Button, Card, Empty, Input, Result, Select, Space, Table, Tag, Tooltip, Typography, message } from 'antd';
import { CalendarOutlined, EyeOutlined, LinkOutlined, ReloadOutlined, SearchOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import { authStorage } from '../../../../core/utils/auth_storage';
import { minutesToTimeStr } from '../../../../core/utils/formatters';
import { matchingApi } from '../../data/matching_api';
import { MatchingSession } from '../../data/matching_types';

const { Title, Text } = Typography;

const STATUS_OPTIONS = ['ALL', 'OPEN', 'FULL', 'CANCELLED', 'COMPLETED'];

const valueText = (...values: any[]) => {
  const value = values.find((item) => item !== undefined && item !== null && item !== '' && item !== 'NaN');
  return value === undefined || value === null ? 'Chưa có dữ liệu' : String(value);
};

const safeMinutes = (value?: number) => Number.isFinite(Number(value)) ? minutesToTimeStr(Number(value)) : 'Chưa có dữ liệu';

const statusTag = (status?: string) => {
  const colors: Record<string, string> = {
    OPEN: 'processing',
    FULL: 'success',
    CANCELLED: 'error',
    COMPLETED: 'default',
  };
  const labels: Record<string, string> = {
    OPEN: 'Đang mở',
    FULL: 'Đã đủ người',
    CANCELLED: 'Đã hủy',
    COMPLETED: 'Hoàn thành',
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

const personName = (session: MatchingSession) => {
  const host = session.host || {};
  return valueText(host.profile?.fullName, host.profile?.name, host.name, session.hostId);
};

const MatchingListPage: React.FC = () => {
  const navigate = useNavigate();
  const user = authStorage.getUser();
  const rolePrefix = user?.role === 'ADMIN' ? '/admin' : '/staff';
  const [items, setItems] = useState<MatchingSession[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [searchText, setSearchText] = useState('');

  const loadData = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params: Record<string, any> = { limit: 500 };
      if (statusFilter !== 'ALL') params.status = statusFilter;
      const result = await matchingApi.getMatchingSessions(params);
      setItems(result.items);
    } catch (e: any) {
      const messageText = e.response?.data?.message || e.message || 'Không thể tải danh sách ghép trận.';
      setError(messageText);
      message.error(messageText);
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const filteredItems = useMemo(() => {
    const query = searchText.trim().toLowerCase();
    const byStatus = statusFilter === 'ALL' ? items : items.filter((item) => item.status === statusFilter);
    if (!query) return byStatus;
    return byStatus.filter((session) => {
      const haystack = [
        session.id,
        personName(session),
        session.host?.email,
        session.facility?.name,
        session.court?.name,
        session.courtId,
        session.sport?.name,
        session.bookingId,
        session.fixedScheduleId,
      ].join(' ').toLowerCase();
      return haystack.includes(query);
    });
  }, [items, searchText, statusFilter]);

  const columns = [
    {
      title: 'Mã phiên',
      dataIndex: 'id',
      key: 'id',
      render: (id: string) => <span className="font-semibold text-brand-orange text-xs">{valueText(id)}</span>,
    },
    {
      title: 'Host',
      key: 'host',
      render: (_: any, record: MatchingSession) => (
        <div className="flex flex-col leading-tight">
          <span className="font-semibold text-sm dark:text-white">{personName(record)}</span>
          <span className="text-xs text-ink-muted dark:text-ink-darkMuted">{valueText(record.host?.email, record.hostId)}</span>
        </div>
      ),
    },
    {
      title: 'Cơ sở / Sân',
      key: 'place',
      render: (_: any, record: MatchingSession) => (
        <div className="flex flex-col leading-tight">
          <span className="font-medium dark:text-white">{valueText(record.court?.name, record.courtId)}</span>
          <span className="text-xs text-brand-orange">{valueText(record.facility?.name, record.facilityId)}</span>
        </div>
      ),
    },
    {
      title: 'Môn',
      key: 'sport',
      render: (_: any, record: MatchingSession) => <span className="dark:text-white">{valueText(record.sport?.name)}</span>,
    },
    {
      title: 'Ngày',
      key: 'date',
      render: (_: any, record: MatchingSession) => (
        <span className="font-medium dark:text-white">
          {record.bookingDate && dayjs(record.bookingDate).isValid() ? dayjs(record.bookingDate).format('DD/MM/YYYY') : valueText(record.bookingDate)}
        </span>
      ),
    },
    {
      title: 'Khung giờ',
      key: 'time',
      render: (_: any, record: MatchingSession) => (
        <span className="font-medium dark:text-white">
          {safeMinutes(record.startMinutes)} - {safeMinutes(record.endMinutes)}
        </span>
      ),
    },
    {
      title: 'Kiểu',
      key: 'mode',
      render: (_: any, record: MatchingSession) => <Tag color="purple">{modeLabel(record.teamMode)}</Tag>,
    },
    {
      title: 'Người chơi',
      key: 'players',
      render: (_: any, record: MatchingSession) => {
        const current = Number(record.approvedCount || 0) + Number(record.hostRepresentedCount || 1);
        const required = record.teamMode === 'INDIVIDUAL'
          ? Number(record.totalPlayersNeeded || 0) + 1
          : Number(record.teamSize || 0) * 2;
        return <span className="font-semibold">{current}/{required || valueText(record.totalPlayersNeeded)}</span>;
      },
    },
    {
      title: 'Trạng thái',
      dataIndex: 'status',
      key: 'status',
      render: statusTag,
    },
    {
      title: 'Booking',
      key: 'booking',
      width: 100,
      render: (_: any, record: MatchingSession) => record.bookingId ? (
        <Tooltip title="Mở booking">
          <Button
            shape="circle"
            icon={<LinkOutlined />}
            onClick={(event) => {
              event.stopPropagation();
              navigate(`${rolePrefix}/bookings/${record.bookingId}`);
            }}
          />
        </Tooltip>
      ) : <span className="text-ink-muted dark:text-ink-darkMuted text-xs">Không có</span>,
    },
    {
      title: 'Thao tác',
      key: 'actions',
      width: 96,
      render: (_: any, record: MatchingSession) => (
        <Space onClick={(event) => event.stopPropagation()}>
          <Tooltip title="Chi tiết">
            <Button shape="circle" icon={<EyeOutlined />} onClick={() => navigate(`${rolePrefix}/matching/${record.id}`)} />
          </Tooltip>
        </Space>
      ),
    },
  ];

  if (error && !loading && items.length === 0) {
    return (
      <Result
        status="error"
        title="Không thể tải danh sách ghép trận"
        subTitle={error}
        extra={<Button type="primary" icon={<ReloadOutlined />} onClick={loadData} className="bg-brand-orange border-none">Tải lại</Button>}
      />
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div>
          <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
            Ghép trận
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Theo dõi các phiên ghép trận, booking liên quan và tình trạng đủ người.
          </Text>
        </div>
        <Button icon={<ReloadOutlined />} onClick={loadData} loading={loading} className="rounded-md">
          Tải lại
        </Button>
      </div>

      <div className="flex flex-col md:flex-row md:items-center gap-3">
        <Select
          value={statusFilter}
          onChange={setStatusFilter}
          className="w-full md:w-56"
          options={STATUS_OPTIONS.map((status) => ({
            value: status,
            label: status === 'ALL' ? 'Tất cả trạng thái' : status,
          }))}
        />
        <Input
          allowClear
          prefix={<SearchOutlined />}
          value={searchText}
          onChange={(event) => setSearchText(event.target.value)}
          placeholder="Tìm theo mã, host, sân, cơ sở, môn..."
          className="w-full md:w-96"
        />
      </div>

      <Card className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 shadow-sm">
        {filteredItems.length === 0 && !loading ? (
          <Empty image={<CalendarOutlined className="text-5xl text-ink-subtle" />} description="Chưa có phiên ghép trận phù hợp" />
        ) : (
          <Table
            dataSource={filteredItems}
            columns={columns}
            rowKey="id"
            loading={loading}
            pagination={{ pageSize: 10 }}
            scroll={{ x: 1180 }}
            onRow={(record) => ({
              onClick: () => navigate(`${rolePrefix}/matching/${record.id}`),
              className: 'cursor-pointer',
            })}
          />
        )}
      </Card>
    </div>
  );
};

export default MatchingListPage;
