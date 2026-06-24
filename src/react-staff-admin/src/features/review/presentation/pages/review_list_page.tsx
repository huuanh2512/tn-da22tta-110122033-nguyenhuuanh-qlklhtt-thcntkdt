import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Button, Card, DatePicker, Empty, Input, Rate, Result, Select, Space, Table, Tag, Tooltip, Typography, message } from 'antd';
import { EyeOutlined, ReloadOutlined, SearchOutlined, StarOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import dayjs, { Dayjs } from 'dayjs';
import { authStorage } from '../../../../core/utils/auth_storage';
import { reviewApi } from '../../data/review_api';
import { ReviewItem } from '../../data/review_types';

const { Title, Text } = Typography;
const { RangePicker } = DatePicker;

const STATUS_OPTIONS = ['ALL', 'VISIBLE', 'HIDDEN', 'PENDING', 'REPORTED'];

const valueText = (...values: any[]) => {
  const value = values.find((item) => item !== undefined && item !== null && item !== '' && item !== 'NaN');
  return value === undefined || value === null ? 'Chưa có dữ liệu' : String(value);
};

const userName = (review: ReviewItem) => {
  const user = review.user || review.customer || {};
  return valueText(user.profile?.fullName, user.profile?.name, user.name, user.email, review.userId);
};

const shortContent = (review: ReviewItem) => {
  const text = valueText(review.comment, review.content);
  return text.length > 96 ? `${text.slice(0, 96)}...` : text;
};

const reviewStatusTag = (review: ReviewItem) => {
  const status = review.status || (review.isHidden ? 'HIDDEN' : 'VISIBLE');
  const colors: Record<string, string> = {
    VISIBLE: 'success',
    HIDDEN: 'default',
    PENDING: 'warning',
    REPORTED: 'error',
    DELETED: 'red',
  };
  const labels: Record<string, string> = {
    VISIBLE: 'Hiển thị',
    HIDDEN: 'Đã ẩn',
    PENDING: 'Chờ xử lý',
    REPORTED: 'Bị báo cáo',
    DELETED: 'Đã xóa',
  };
  return <Tag color={colors[status] || 'default'}>{labels[status] || valueText(status)}</Tag>;
};

const ReviewListPage: React.FC = () => {
  const navigate = useNavigate();
  const user = authStorage.getUser();
  const rolePrefix = user?.role === 'ADMIN' ? '/admin' : '/staff';
  const [items, setItems] = useState<ReviewItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [ratingFilter, setRatingFilter] = useState<number | 'ALL'>('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [searchText, setSearchText] = useState('');
  const [dateRange, setDateRange] = useState<[Dayjs | null, Dayjs | null] | null>(null);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params: Record<string, any> = { limit: 500 };
      if (ratingFilter !== 'ALL') params.rating = ratingFilter;
      const result = await reviewApi.getReviews(params);
      setItems(result.items);
    } catch (e: any) {
      const messageText = e.response?.data?.message || e.message || 'Không thể tải danh sách đánh giá.';
      setError(messageText);
      message.error(messageText);
    } finally {
      setLoading(false);
    }
  }, [ratingFilter]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const filteredItems = useMemo(() => {
    const query = searchText.trim().toLowerCase();
    return items.filter((review) => {
      if (statusFilter !== 'ALL' && review.status !== statusFilter) return false;
      if (dateRange?.[0] && review.createdAt && dayjs(review.createdAt).isBefore(dateRange[0], 'day')) return false;
      if (dateRange?.[1] && review.createdAt && dayjs(review.createdAt).isAfter(dateRange[1], 'day')) return false;
      if (!query) return true;
      const haystack = [
        review.id,
        userName(review),
        review.comment,
        review.content,
        review.court?.name,
        review.facility?.name,
        review.sport?.name,
        review.bookingId,
      ].join(' ').toLowerCase();
      return haystack.includes(query);
    });
    // TODO: move status/date/search/facility/court filters server-side when review API supports them.
  }, [items, searchText, statusFilter, dateRange]);

  const columns = [
    {
      title: 'Mã review',
      dataIndex: 'id',
      key: 'id',
      render: (id: string) => <span className="font-semibold text-brand-orange text-xs">{valueText(id)}</span>,
    },
    {
      title: 'Người đánh giá',
      key: 'user',
      render: (_: any, record: ReviewItem) => (
        <div className="flex flex-col leading-tight">
          <span className="font-semibold text-sm dark:text-white">{userName(record)}</span>
          <span className="text-xs text-ink-muted dark:text-ink-darkMuted">{valueText(record.user?.email, record.userId)}</span>
        </div>
      ),
    },
    {
      title: 'Sao',
      dataIndex: 'rating',
      key: 'rating',
      width: 130,
      render: (rating: number) => <Rate disabled allowHalf value={Number(rating || 0)} className="text-sm" />,
    },
    {
      title: 'Nội dung',
      key: 'content',
      render: (_: any, record: ReviewItem) => <span className="text-sm dark:text-white">{shortContent(record)}</span>,
    },
    {
      title: 'Cơ sở / Sân',
      key: 'place',
      render: (_: any, record: ReviewItem) => (
        <div className="flex flex-col leading-tight">
          <span className="font-medium dark:text-white">{valueText(record.court?.name, record.courtId)}</span>
          <span className="text-xs text-brand-orange">{valueText(record.facility?.name, record.facilityId)}</span>
        </div>
      ),
    },
    {
      title: 'Môn',
      key: 'sport',
      render: (_: any, record: ReviewItem) => <span>{valueText(record.sport?.name)}</span>,
    },
    {
      title: 'Booking',
      key: 'booking',
      render: (_: any, record: ReviewItem) => record.bookingId ? <Tag color="blue">{record.bookingId}</Tag> : <span className="text-xs text-ink-muted">Không có</span>,
    },
    {
      title: 'Trạng thái',
      key: 'status',
      render: (_: any, record: ReviewItem) => (
        <Space size={4} wrap>
          {reviewStatusTag(record)}
          {Number(record.reportedCount || 0) > 0 && <Tag color="red">Báo cáo: {record.reportedCount}</Tag>}
        </Space>
      ),
    },
    {
      title: 'Ngày tạo',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 150,
      render: (date: string) => date && dayjs(date).isValid() ? dayjs(date).format('DD/MM/YYYY') : valueText(date),
    },
    {
      title: 'Thao tác',
      key: 'actions',
      width: 96,
      render: (_: any, record: ReviewItem) => (
        <Space onClick={(event) => event.stopPropagation()}>
          <Tooltip title="Chi tiết">
            <Button shape="circle" icon={<EyeOutlined />} onClick={() => navigate(`${rolePrefix}/reviews/${record.id}`)} />
          </Tooltip>
        </Space>
      ),
    },
  ];

  if (error && !loading && items.length === 0) {
    return (
      <Result
        status="error"
        title="Không thể tải đánh giá"
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
            Đánh giá
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Theo dõi đánh giá sân/cơ sở và các phản hồi liên quan từ khách hàng.
          </Text>
        </div>
        <Button icon={<ReloadOutlined />} onClick={loadData} loading={loading} className="rounded-md">
          Tải lại
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3">
        <Select
          value={ratingFilter}
          onChange={setRatingFilter}
          options={[
            { value: 'ALL', label: 'Tất cả số sao' },
            ...[5, 4, 3, 2, 1].map((rating) => ({ value: rating, label: `${rating} sao` })),
          ]}
        />
        <Select
          value={statusFilter}
          onChange={setStatusFilter}
          options={STATUS_OPTIONS.map((status) => ({
            value: status,
            label: status === 'ALL' ? 'Tất cả trạng thái' : status,
          }))}
        />
        <RangePicker value={dateRange as any} onChange={(value) => setDateRange(value as any)} />
        <Input
          allowClear
          prefix={<SearchOutlined />}
          value={searchText}
          onChange={(event) => setSearchText(event.target.value)}
          placeholder="Tìm người đánh giá, nội dung, sân..."
        />
      </div>

      <Card className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 shadow-sm">
        {filteredItems.length === 0 && !loading ? (
          <Empty image={<StarOutlined className="text-5xl text-ink-subtle" />} description="Chưa có đánh giá phù hợp" />
        ) : (
          <Table
            dataSource={filteredItems}
            columns={columns}
            rowKey="id"
            loading={loading}
            pagination={{ pageSize: 10 }}
            scroll={{ x: 1200 }}
            onRow={(record) => ({
              onClick: () => navigate(`${rolePrefix}/reviews/${record.id}`),
              className: 'cursor-pointer',
            })}
          />
        )}
      </Card>
    </div>
  );
};

export default ReviewListPage;
