import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Alert, Button, Card, Col, Descriptions, Empty, Image, Rate, Result, Row, Space, Spin, Tag, Typography } from 'antd';
import { ArrowLeftOutlined, LinkOutlined, ReloadOutlined, StarOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { apiClient } from '../../../../core/network/api_client';
import { authStorage } from '../../../../core/utils/auth_storage';
import { formatVND } from '../../../../core/utils/formatters';
import { reviewApi } from '../../data/review_api';
import { ReviewItem } from '../../data/review_types';

const { Title, Text, Paragraph } = Typography;

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

const formatDateTime = (value?: string | null) => {
  if (!value) return 'Chưa có dữ liệu';
  const parsed = dayjs(value);
  return parsed.isValid() ? parsed.format('HH:mm DD/MM/YYYY') : value;
};

const userName = (review: ReviewItem | null) => {
  const user = review?.user || review?.customer || {};
  return valueText(user.profile?.fullName, user.profile?.name, user.name, user.email, review?.userId);
};

const statusTag = (review: ReviewItem) => {
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

const ReviewDetailPage: React.FC = () => {
  const { reviewId = '' } = useParams();
  const navigate = useNavigate();
  const user = authStorage.getUser();
  const rolePrefix = user?.role === 'ADMIN' ? '/admin' : '/staff';
  const [review, setReview] = useState<ReviewItem | null>(null);
  const [booking, setBooking] = useState<any>(null);
  const [payments, setPayments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadDetail = useCallback(async () => {
    if (!reviewId) {
      setError('Thiếu mã đánh giá.');
      setLoading(false);
      return;
    }

    setLoading(true);
    setError('');
    try {
      const detail = await reviewApi.getReviewById(reviewId);
      if (!detail) {
        setReview(null);
        setError('Không tìm thấy đánh giá.');
        return;
      }
      setReview(detail);

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

      const bookingPaymentSource = bookingDetail || {};
      const embeddedPayments = Array.isArray(bookingPaymentSource.payments)
        ? bookingPaymentSource.payments
        : bookingPaymentSource.payment && typeof bookingPaymentSource.payment === 'object'
          ? [bookingPaymentSource.payment]
          : [];
      setPayments(embeddedPayments);
    } catch (e: any) {
      setReview(null);
      setError(e.response?.data?.message || e.message || 'Không thể tải chi tiết đánh giá.');
    } finally {
      setLoading(false);
    }
  }, [reviewId]);

  useEffect(() => {
    loadDetail();
  }, [loadDetail]);

  const bookingId = review?.bookingId || getObjectId(booking);
  const replyContent = useMemo(() => {
    const reply = review?.staffReply || review?.reply;
    if (!reply) return '';
    if (typeof reply === 'string') return reply;
    return reply.content || reply.message || reply.text || '';
  }, [review]);

  if (loading) {
    return (
      <div className="min-h-[360px] flex items-center justify-center">
        <Spin size="large" tip="Đang tải chi tiết đánh giá..." />
      </div>
    );
  }

  if (error) {
    return (
      <Result
        status="error"
        title="Không thể tải đánh giá"
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

  if (!review) {
    return (
      <Card className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10">
        <Empty description="Không tìm thấy dữ liệu đánh giá" />
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div className="space-y-2">
          <Button icon={<ArrowLeftOutlined />} onClick={() => navigate(-1)} className="rounded-md">
            Quay lại
          </Button>
          <div>
            <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
              Chi tiết đánh giá
            </Title>
            <Text className="text-ink-muted dark:text-ink-darkMuted">
              Mã review: <span className="font-semibold text-brand-orange">{review.id}</span>
            </Text>
          </div>
        </div>
        <Space wrap>
          {bookingId && (
            <Button icon={<LinkOutlined />} onClick={() => navigate(`${rolePrefix}/bookings/${bookingId}`)}>
              Mở booking
            </Button>
          )}
          <Button icon={<ReloadOutlined />} onClick={loadDetail}>
            Tải lại
          </Button>
        </Space>
      </div>

      <Alert
        type="info"
        showIcon
        message="Moderation"
        description="Backend hiện chỉ có GET /review/, POST /review/ và DELETE /review/:id cho ADMIN. Chưa có API ẩn/hiện, phản hồi hoặc xóa mềm review nên web chỉ bật chế độ xem/list/detail."
      />

      <Row gutter={[16, 16]}>
        <Col xs={24} lg={15}>
          <Card title="Thông tin đánh giá" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 h-full">
            <Descriptions column={{ xs: 1, sm: 2 }} bordered size="small">
              <Descriptions.Item label="Mã review">{review.id}</Descriptions.Item>
              <Descriptions.Item label="Trạng thái">
                <Space wrap>
                  {statusTag(review)}
                  {Number(review.reportedCount || 0) > 0 && <Tag color="red">Bị báo cáo: {review.reportedCount}</Tag>}
                </Space>
              </Descriptions.Item>
              <Descriptions.Item label="Số sao">
                <Rate disabled allowHalf value={safeNumber(review.rating, 0)} />
              </Descriptions.Item>
              <Descriptions.Item label="Ngày tạo">{formatDateTime(review.createdAt)}</Descriptions.Item>
              <Descriptions.Item label="Cập nhật">{formatDateTime(review.updatedAt)}</Descriptions.Item>
              <Descriptions.Item label="Lý do xử lý">{valueText(review.moderationReason)}</Descriptions.Item>
              <Descriptions.Item label="Người ẩn">{valueText(typeof review.hiddenBy === 'string' ? review.hiddenBy : review.hiddenBy?.name || review.hiddenBy?.id)}</Descriptions.Item>
              <Descriptions.Item label="Thời điểm ẩn">{formatDateTime(review.hiddenAt)}</Descriptions.Item>
              <Descriptions.Item label="Nội dung" span={2}>
                <Paragraph className="m-0 whitespace-pre-wrap">{valueText(review.comment, review.content)}</Paragraph>
              </Descriptions.Item>
              <Descriptions.Item label="Phản hồi" span={2}>{valueText(replyContent)}</Descriptions.Item>
            </Descriptions>

            <div className="mt-5">
              <Text className="font-semibold dark:text-white">Hình ảnh</Text>
              {review.images && review.images.length > 0 ? (
                <Image.PreviewGroup>
                  <div className="flex flex-wrap gap-3 mt-3">
                    {review.images.map((src) => (
                      <Image key={src} src={src} width={112} height={84} className="object-cover rounded-md" />
                    ))}
                  </div>
                </Image.PreviewGroup>
              ) : (
                <Empty image={<StarOutlined className="text-4xl text-ink-subtle" />} description="Không có hình ảnh" />
              )}
            </div>
          </Card>
        </Col>

        <Col xs={24} lg={9}>
          <Card title="Người đánh giá" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 h-full">
            <div className="space-y-3 text-sm">
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Họ tên</Text>
                <div className="font-semibold dark:text-white">{userName(review)}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Email</Text>
                <div className="font-medium break-all">{valueText(review.user?.email, review.customer?.email)}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Số điện thoại</Text>
                <div className="font-medium">{valueText(review.user?.phone, review.user?.profile?.phone, review.customer?.phone)}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">User id</Text>
                <div className="font-mono text-xs break-all">{valueText(review.userId)}</div>
              </div>
            </div>
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]}>
        <Col xs={24} lg={12}>
          <Card title="Sân / Cơ sở liên quan" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 h-full">
            <Descriptions column={1} bordered size="small">
              <Descriptions.Item label="Cơ sở">{valueText(review.facility?.name, review.facilityId)}</Descriptions.Item>
              <Descriptions.Item label="Sân">{valueText(review.court?.name, review.courtId)}</Descriptions.Item>
              <Descriptions.Item label="Môn thể thao">{valueText(review.sport?.name)}</Descriptions.Item>
              <Descriptions.Item label="Court id">{valueText(review.courtId)}</Descriptions.Item>
              <Descriptions.Item label="Facility id">{valueText(review.facilityId)}</Descriptions.Item>
            </Descriptions>
          </Card>
        </Col>

        <Col xs={24} lg={12}>
          <Card title="Booking / Thanh toán liên quan" className="rounded-xl border border-semantic-border/10 dark:border-semantic-borderDark/10 h-full">
            <div className="space-y-3 text-sm">
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Mã booking</Text>
                <div className="font-semibold text-brand-orange break-all">{valueText(bookingId)}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Trạng thái booking</Text>
                <div>{valueText(booking?.status)}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Tổng tiền</Text>
                <div className="font-semibold">{formatVND(safeNumber(booking?.totalPrice ?? booking?.total_price, 0))}</div>
              </div>
              <div>
                <Text className="text-ink-muted dark:text-ink-darkMuted text-xs">Payment embedded</Text>
                <div>{payments.length > 0 ? `${payments.length} giao dịch` : 'Chưa có dữ liệu'}</div>
              </div>
              {bookingId && (
                <Button block icon={<LinkOutlined />} onClick={() => navigate(`${rolePrefix}/bookings/${bookingId}`)}>
                  Xem booking
                </Button>
              )}
            </div>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default ReviewDetailPage;
