import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Button, Card, Empty, Input, Result, Select, Space, Table, Tag, Tooltip, Typography, message } from 'antd';
import { EyeOutlined, ReloadOutlined, SearchOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import { authStorage } from '../../../../core/utils/auth_storage';
import { minutesToTimeStr } from '../../../../core/utils/formatters';
import { fixedScheduleApi } from '../../data/fixed_schedule_api';
import { FixedScheduleItem } from '../../data/fixed_schedule_types';

const { Title, Text } = Typography;

const STATUS_OPTIONS = ['ALL', 'PENDING_APPROVAL', 'ACTIVE', 'PAUSED', 'CANCELLED', 'REJECTED', 'EXPIRED'];

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
  return <Tag color={colors[status || ''] || 'default'}>{labels[status || ''] || status || 'Chưa có dữ liệu'}</Tag>;
};

const valueText = (...values: any[]) => {
  const value = values.find((item) => item !== undefined && item !== null && item !== '');
  return value === undefined || value === null ? 'Chưa có dữ liệu' : String(value);
};

const personName = (schedule: FixedScheduleItem) => {
  const user = schedule.user || schedule.customer;
  return valueText(user?.profile?.fullName, user?.profile?.name, user?.name, schedule.customerName);
};

const recurringText = (schedule: FixedScheduleItem) => {
  if (schedule.frequency === 'DAILY') return 'Hằng ngày';
  const days = schedule.daysOfWeek || [];
  if (days.length === 0) return 'Chưa có dữ liệu';
  const labels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
  return days.map((day) => labels[day] || `Thứ ${day}`).join(', ');
};

const FixedScheduleListPage: React.FC = () => {
  const navigate = useNavigate();
  const user = authStorage.getUser();
  const rolePrefix = user?.role === 'ADMIN' ? '/admin' : '/staff';
  const [items, setItems] = useState<FixedScheduleItem[]>([]);
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
      const result = await fixedScheduleApi.getFixedSchedules(params);
      setItems(result.items);
    } catch (e: any) {
      const messageText = e.response?.data?.message || e.message || 'Không thể tải lịch cố định.';
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
    if (!query) return items;
    // TODO: switch to server-side search/facility/date filters when backend exposes them.
    return items.filter((schedule) => {
      const haystack = [
        schedule.id,
        schedule.fixedScheduleCode,
        personName(schedule),
        schedule.court?.name,
        schedule.facility?.name,
        schedule.sport?.name,
      ].join(' ').toLowerCase();
      return haystack.includes(query);
    });
  }, [items, searchText]);

  const columns = [
    {
      title: 'Mã lịch',
      dataIndex: 'id',
      key: 'id',
      render: (_: string, record: FixedScheduleItem) => (
        <span className="font-semibold text-brand-orange text-xs">{record.fixedScheduleCode || record.id}</span>
      ),
    },
    {
      title: 'Người đặt',
      key: 'customer',
      render: (_: any, record: FixedScheduleItem) => (
        <div className="flex flex-col leading-tight">
          <span className="font-semibold text-sm dark:text-white">{personName(record)}</span>
          <span className="text-xs text-ink-muted dark:text-ink-darkMuted">{valueText(record.user?.phone, record.customer?.phone, record.user?.email)}</span>
        </div>
      ),
    },
    {
      title: 'Cơ sở / Sân',
      key: 'place',
      render: (_: any, record: FixedScheduleItem) => (
        <div className="flex flex-col leading-tight">
          <span className="font-medium dark:text-white">{valueText(record.court?.name, record.courtId)}</span>
          <span className="text-xs text-brand-orange">{valueText(record.facility?.name, record.facilityId)}</span>
        </div>
      ),
    },
    {
      title: 'Môn',
      key: 'sport',
      render: (_: any, record: FixedScheduleItem) => <span className="dark:text-white">{valueText(record.sport?.name)}</span>,
    },
    {
      title: 'Lặp',
      key: 'repeat',
      render: (_: any, record: FixedScheduleItem) => <span className="font-medium text-indigo-500">{recurringText(record)}</span>,
    },
    {
      title: 'Khung giờ',
      key: 'time',
      render: (_: any, record: FixedScheduleItem) => (
        <span className="font-medium dark:text-white">
          {record.startMinutes !== undefined ? minutesToTimeStr(record.startMinutes) : valueText(record.startTime)}
          {' - '}
          {record.endMinutes !== undefined ? minutesToTimeStr(record.endMinutes) : valueText(record.endTime)}
        </span>
      ),
    },
    {
      title: 'Hiệu lực',
      key: 'range',
      render: (_: any, record: FixedScheduleItem) => (
        <div className="flex flex-col leading-tight text-xs">
          <span>{record.startDate ? dayjs(record.startDate).format('DD/MM/YYYY') : 'Chưa có dữ liệu'}</span>
          <span className="text-ink-muted dark:text-ink-darkMuted">{record.endDate ? dayjs(record.endDate).format('DD/MM/YYYY') : 'Không giới hạn'}</span>
        </div>
      ),
    },
    {
      title: 'Loại',
      key: 'type',
      render: (_: any, record: FixedScheduleItem) => (
        <Tag color={record.type === 'MATCHING' || record.isMatching ? 'purple' : 'blue'}>
          {record.type === 'MATCHING' || record.isMatching ? 'Matching' : 'Thường'}
        </Tag>
      ),
    },
    {
      title: 'Trạng thái',
      dataIndex: 'status',
      key: 'status',
      render: statusTag,
    },
    {
      title: 'Thao tác',
      key: 'actions',
      width: 96,
      render: (_: any, record: FixedScheduleItem) => (
        <Space onClick={(event) => event.stopPropagation()}>
          <Tooltip title="Chi tiết">
            <Button shape="circle" icon={<EyeOutlined />} onClick={() => navigate(`${rolePrefix}/fixed-schedules/${record.id}`)} />
          </Tooltip>
        </Space>
      ),
    },
  ];

  if (error && !loading && items.length === 0) {
    return (
      <Result
        status="error"
        title="Không thể tải lịch cố định"
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
            Lịch cố định
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Theo dõi và quản trị các đăng ký lịch cố định của khách hàng.
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
          placeholder="Tìm theo mã lịch, khách hàng, sân, cơ sở..."
          className="w-full md:w-96"
        />
      </div>

      <Card className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 shadow-sm">
        {filteredItems.length === 0 && !loading ? (
          <Empty description="Chưa có lịch cố định phù hợp" />
        ) : (
          <Table
            dataSource={filteredItems}
            columns={columns}
            rowKey="id"
            loading={loading}
            pagination={{ pageSize: 10 }}
            onRow={(record) => ({
              onClick: () => navigate(`${rolePrefix}/fixed-schedules/${record.id}`),
              className: 'cursor-pointer',
            })}
          />
        )}
      </Card>
    </div>
  );
};

export default FixedScheduleListPage;
