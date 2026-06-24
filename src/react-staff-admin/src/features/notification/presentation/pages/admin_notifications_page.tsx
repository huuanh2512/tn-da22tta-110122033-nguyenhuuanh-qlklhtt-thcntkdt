import React, { useState, useEffect, useCallback } from 'react';
import { Card, Tabs, Form, Input, Select, Button, Table, Tag, Typography, message, Row, Col } from 'antd';
import { SendOutlined, InfoCircleOutlined, SettingOutlined } from '@ant-design/icons';
import { createNotificationUseCase, getNotificationsUseCase } from '../../../../core/di/injection';
import { Notification } from '../../domain/entities/notification.entity';
import { apiClient } from '../../../../core/network/api_client';
import dayjs from 'dayjs';

const { Title, Text } = Typography;
const { TextArea } = Input;

interface UserItem {
  _id?: string;
  id: string;
  email: string;
  role: string;
  profile?: {
    fullName?: string;
  };
  name?: string;
}

interface NotificationTemplate {
  name: string;
  title: string;
  body: string;
  type: 'SYSTEM' | 'PROMOTION';
  metadataType: 'NONE' | 'BOOKING' | 'PROMOTION' | 'CUSTOM';
  bookingId?: string;
  promotionId?: string;
  customMetadata?: string;
}

const TEMPLATES: NotificationTemplate[] = [
  {
    name: '🛠️ Bảo trì hệ thống',
    title: '[Bảo trì] Hệ thống Sport Energy tạm dừng nâng cấp',
    body: 'Hệ thống sẽ tạm dừng để nâng cấp định kỳ nhằm nâng cao trải nghiệm dịch vụ từ 01:00 đến 03:00 sáng mai. Trân trọng cảm ơn sự thông cảm của quý khách!',
    type: 'SYSTEM',
    metadataType: 'CUSTOM',
    customMetadata: '{"maintenanceId": "MAINT_2026_05_30"}'
  },
  {
    name: '🔥 Giờ vàng ưu đãi',
    title: '[Ưu đãi] Khung giờ vàng - Giảm ngay 30% đặt sân',
    body: 'Nhận ngay ưu đãi 30% khi đặt sân và thanh toán trực tuyến trong hôm nay. Ưu đãi tự động áp dụng khi nhập mã GOLDEN_HOUR.',
    type: 'PROMOTION',
    metadataType: 'PROMOTION',
    promotionId: 'GOLDEN_HOUR'
  },
  {
    name: '🌦️ Cảnh báo thời tiết',
    title: '[Lưu ý] Khuyến cáo thời tiết xấu và phương án hỗ trợ',
    body: 'Do thời tiết mưa bão, các ca đặt sân ngoài trời sẽ được hỗ trợ dời lịch miễn phí hoặc hoàn tiền. Vui lòng liên hệ hotline/quầy lễ tân để được xử lý.',
    type: 'SYSTEM',
    metadataType: 'NONE'
  }
];

const AdminNotificationsPage: React.FC = () => {
  const [activeTab, setActiveTab] = useState<string>('SEND');
  const [form] = Form.useForm();
  const [users, setUsers] = useState<UserItem[]>([]);
  const [sentHistory, setSentHistory] = useState<Notification[]>([]);
  const [loadingHistory, setLoadingHistory] = useState<boolean>(false);
  const [sending, setSending] = useState<boolean>(false);
  const [sendTarget, setSendTarget] = useState<'ALL' | 'SPECIFIC'>('ALL');
  const [metadataType, setMetadataType] = useState<'NONE' | 'BOOKING' | 'PROMOTION' | 'CUSTOM'>('NONE');
  const [bookings, setBookings] = useState<any[]>([]);

  const handleApplyTemplate = (tmpl: NotificationTemplate) => {
    form.setFieldsValue({
      title: tmpl.title,
      body: tmpl.body,
      type: tmpl.type,
      bookingId: tmpl.bookingId,
      promotionId: tmpl.promotionId,
      customMetadata: tmpl.customMetadata
    });
    setMetadataType(tmpl.metadataType);
    message.success(`Đã áp dụng mẫu "${tmpl.name}"`);
  };

  // Load all users and bookings for selectors
  useEffect(() => {
    apiClient.get('/user/').then(res => {
      setUsers(res.data.items || []);
    }).catch(() => {
      message.error('Không thể tải danh sách người dùng');
    });

    apiClient.get('/booking').then(res => {
      setBookings(res.data.items || []);
    }).catch(() => {
      console.error('Không thể tải danh sách lịch đặt sân');
    });
  }, []);

  const loadSentHistory = useCallback(async () => {
    setLoadingHistory(true);
    try {
      const res = await getNotificationsUseCase.execute();
      setSentHistory(res.items || []);
    } catch {
      message.error('Không thể tải lịch sử thông báo đã gửi');
    } finally {
      setLoadingHistory(false);
    }
  }, []);

  useEffect(() => {
    if (activeTab === 'HISTORY') {
      loadSentHistory();
    }
  }, [activeTab, loadSentHistory]);

  const handleSubmit = async (values: any) => {
    setSending(true);
    try {
      let metadataObj: Record<string, any> = {};
      if (metadataType === 'BOOKING') {
        if (!values.bookingId) {
          message.error('Vui lòng chọn một lịch đặt sân!');
          setSending(false);
          return;
        }
        metadataObj = { bookingId: values.bookingId };
      } else if (metadataType === 'PROMOTION') {
        if (!values.promotionId) {
          message.error('Vui lòng nhập mã khuyến mãi!');
          setSending(false);
          return;
        }
        metadataObj = { promotionId: values.promotionId };
      } else if (metadataType === 'CUSTOM') {
        if (values.customMetadata) {
          try {
            metadataObj = JSON.parse(values.customMetadata);
          } catch {
            message.error('Định dạng Metadata JSON không hợp lệ!');
            setSending(false);
            return;
          }
        }
      }

      if (sendTarget === 'ALL') {
        if (users.length === 0) {
          message.error('Không có người dùng nào để gửi thông báo!');
          setSending(false);
          return;
        }

        // Send notification to each user in the system (required by backend schema)
        await Promise.all(
          users.map((u) =>
            createNotificationUseCase.execute({
              userId: u.id || u._id,
              title: values.title,
              body: values.body,
              type: values.type,
              metadata: metadataObj
            })
          )
        );
      } else {
        await createNotificationUseCase.execute({
          userId: values.userId,
          title: values.title,
          body: values.body,
          type: values.type,
          metadata: metadataObj
        });
      }

      message.success('Đã gửi thông báo thành công tới Mobile App và Web!');
      form.resetFields();
      form.setFieldsValue({ type: 'SYSTEM', target: 'ALL' });
      setSendTarget('ALL');
      setMetadataType('NONE');
    } catch (e: any) {
      message.error(e.response?.data?.message || e.message || 'Gửi thông báo thất bại');
    } finally {
      setSending(false);
    }
  };

  const getRecipientName = (userId: string) => {
    if (!userId) return <Tag color="blue">Tất cả người dùng (Broadcast)</Tag>;
    const u = users.find(user => (user.id || user._id) === userId);
    if (!u) return <span className="font-mono text-xs text-neutral-400">{userId}</span>;
    return (
      <div className="flex flex-col leading-tight">
        <span className="font-semibold text-sm dark:text-white">
          {u.profile?.fullName || u.name || 'Khách hàng'}
        </span>
        <span className="text-[10px] text-ink-subtle dark:text-ink-darkSubtle">{u.email}</span>
      </div>
    );
  };

  const columns = [
    {
      title: 'Thông báo đã gửi',
      key: 'content',
      render: (_: any, record: Notification) => (
        <div className="flex flex-col gap-1 py-1">
          <span className="font-bold text-sm dark:text-white">{record.title}</span>
          <span className="text-xs text-ink-muted dark:text-ink-darkMuted">{record.body}</span>
        </div>
      )
    },
    {
      title: 'Loại',
      dataIndex: 'type',
      key: 'type',
      width: 130,
      render: (type: Notification['type']) => {
        const colors: Record<string, string> = {
          SYSTEM: 'blue',
          PROMOTION: 'purple',
          BOOKING: 'success',
          PAYMENT: 'orange',
          MATCHING: 'processing',
        };
        const labels: Record<string, string> = {
          SYSTEM: 'Hệ thống',
          PROMOTION: 'Khuyến mãi',
          BOOKING: 'Đặt sân',
          PAYMENT: 'Thanh toán',
          MATCHING: 'Ghép trận',
        };
        return <Tag color={colors[type] || 'default'} className="border-none font-semibold px-2.5 py-0.5 rounded">{labels[type] || type}</Tag>;
      }
    },
    {
      title: 'Người nhận',
      dataIndex: 'userId',
      key: 'userId',
      width: 220,
      render: (userId: string) => getRecipientName(userId)
    },
    {
      title: 'Ngày gửi',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 180,
      render: (date: string) => (
        <span className="text-xs text-ink-muted dark:text-ink-darkMuted">
          {dayjs(date).format('HH:mm DD/MM/YYYY')}
        </span>
      )
    }
  ];

  return (
    <div className="space-y-6">
      <div className="border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
          Quản trị & Bắn thông báo (FCM Push)
          <Tag color="red" className="ml-2 border-none font-bold text-xs px-2.5 py-0.5 rounded-pill">MOBILE APP INTEGRATION</Tag>
        </Title>
        <Text className="text-ink-muted dark:text-ink-darkMuted">
          Gửi tin tức khuyến mãi hoặc thông báo bảo trì hệ thống tới ứng dụng di động của toàn bộ khách hàng hoặc nhân viên.
        </Text>
      </div>

      <Tabs
        activeKey={activeTab}
        onChange={setActiveTab}
        items={[
          { key: 'SEND', label: 'Soạn và Gửi thông báo' },
          { key: 'HISTORY', label: 'Lịch sử thông báo hệ thống đã gửi' }
        ]}
      />

      {activeTab === 'SEND' ? (
        <Row gutter={[24, 24]}>
          <Col xs={24} lg={14}>
            <Card 
              title={<span className="font-semibold dark:text-white">Nội dung thông báo</span>}
              className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm"
            >
              <div className="mb-6 p-4 rounded-lg bg-neutral-50 dark:bg-neutral-800/40 border border-semantic-border/10 dark:border-semantic-borderDark/10">
                <span className="text-xs font-semibold text-ink-muted dark:text-ink-darkMuted block mb-2">
                  MẪU THÔNG BÁO NHANH (QUICK TEMPLATES)
                </span>
                <div className="flex flex-wrap gap-2">
                  {TEMPLATES.map((tmpl) => (
                    <Button
                      key={tmpl.name}
                      type="dashed"
                      size="small"
                      onClick={() => handleApplyTemplate(tmpl)}
                      className="text-xs hover:border-brand-orange hover:text-brand-orange rounded-full py-1 h-auto"
                    >
                      {tmpl.name}
                    </Button>
                  ))}
                </div>
              </div>

              <Form
                form={form}
                layout="vertical"
                initialValues={{ type: 'SYSTEM', target: 'ALL' }}
                onFinish={handleSubmit}
              >
                <Row gutter={16}>
                  <Col span={12}>
                    <Form.Item
                      name="target"
                      label={<span className="font-semibold dark:text-white">Đối tượng nhận</span>}
                      rules={[{ required: true }]}
                    >
                      <Select onChange={(val) => setSendTarget(val)}>
                        <Select.Option value="ALL">Tất cả người dùng (Topic: All)</Select.Option>
                        <Select.Option value="SPECIFIC">Một người dùng cụ thể</Select.Option>
                      </Select>
                    </Form.Item>
                  </Col>
                  <Col span={12}>
                    <Form.Item
                      name="type"
                      label={<span className="font-semibold dark:text-white">Loại thông báo</span>}
                      rules={[{ required: true }]}
                    >
                      <Select>
                        <Select.Option value="SYSTEM">Hệ thống (SYSTEM)</Select.Option>
                        <Select.Option value="PROMOTION">Khuyến mãi (PROMOTION)</Select.Option>
                      </Select>
                    </Form.Item>
                  </Col>
                </Row>

                {sendTarget === 'SPECIFIC' && (
                  <Form.Item
                    name="userId"
                    label={<span className="font-semibold dark:text-white">Chọn người nhận</span>}
                    rules={[{ required: true, message: 'Vui lòng chọn người nhận!' }]}
                  >
                    <Select
                      showSearch
                      placeholder="Tìm theo email hoặc họ tên"
                      optionFilterProp="children"
                      filterOption={(input, option) =>
                        (option?.label ?? '').toLowerCase().includes(input.toLowerCase())
                      }
                      options={users.map(u => ({
                        value: u.id || u._id,
                        label: `${u.profile?.fullName || u.name || 'N/A'} (${u.email})`
                      }))}
                      className="rounded-md"
                    />
                  </Form.Item>
                )}

                <Form.Item
                  name="title"
                  label={<span className="font-semibold dark:text-white">Tiêu đề (Title)</span>}
                  rules={[{ required: true, message: 'Nhập tiêu đề thông báo!' }, { max: 100 }]}
                >
                  <Input placeholder="Nhập tiêu đề hiển thị trên thanh notification di động..." className="rounded-md" />
                </Form.Item>

                <Form.Item
                  name="body"
                  label={<span className="font-semibold dark:text-white">Nội dung chi tiết (Body)</span>}
                  rules={[{ required: true, message: 'Nhập nội dung thông báo!' }]}
                >
                  <TextArea rows={4} placeholder="Nhập nội dung chi tiết..." className="rounded-md" />
                </Form.Item>

                <Form.Item
                  label={<span className="font-semibold dark:text-white">Loại điều hướng (Deep Link Metadata)</span>}
                >
                  <Select value={metadataType} onChange={(val) => setMetadataType(val)} className="rounded-md">
                    <Select.Option value="NONE">Không kèm điều hướng (None)</Select.Option>
                    <Select.Option value="BOOKING">Chi tiết ca đặt sân (bookingId)</Select.Option>
                    <Select.Option value="PROMOTION">Chi tiết chương trình khuyến mãi (promotionId)</Select.Option>
                    <Select.Option value="CUSTOM">JSON Metadata tự thiết kế (Custom)</Select.Option>
                  </Select>
                </Form.Item>

                {metadataType === 'BOOKING' && (
                  <Form.Item
                    name="bookingId"
                    label={<span className="font-semibold dark:text-white">Chọn lịch đặt sân liên quan</span>}
                    rules={[{ required: true, message: 'Vui lòng chọn một lịch đặt!' }]}
                  >
                    <Select
                      showSearch
                      placeholder="Tìm kiếm theo mã đặt sân hoặc tên khách hàng..."
                      optionFilterProp="children"
                      filterOption={(input, option) =>
                        (option?.label ?? '').toLowerCase().includes(input.toLowerCase())
                      }
                      options={bookings.map((b: any) => {
                        const bUser = users.find(u => (u.id || u._id) === b.userId);
                        const userLabel = bUser?.profile?.fullName || bUser?.name || 'Khách vãng lai';
                        const dateStr = dayjs(b.bookingDate).format('DD/MM/YYYY');
                        return {
                          value: b._id || b.id,
                          label: `Mã: ${b._id || b.id} - ${userLabel} (${dateStr})`
                        };
                      })}
                      className="rounded-md"
                    />
                  </Form.Item>
                )}

                {metadataType === 'PROMOTION' && (
                  <Form.Item
                    name="promotionId"
                    label={<span className="font-semibold dark:text-white">Nhập Mã khuyến mãi</span>}
                    rules={[{ required: true, message: 'Nhập mã khuyến mãi để chuyển hướng!' }]}
                  >
                    <Input placeholder="Ví dụ: GOLDEN_HOUR, GIAM_50K" className="rounded-md" />
                  </Form.Item>
                )}

                {metadataType === 'CUSTOM' && (
                  <Form.Item
                    name="customMetadata"
                    label={<span className="font-semibold dark:text-white">Nhập JSON tùy biến</span>}
                    rules={[{ required: true, message: 'Vui lòng nhập định dạng JSON hợp lệ!' }]}
                    help="Ví dụ: {'maintenanceId': 'maintenance_29/05/2026'}"
                  >
                    <TextArea rows={4} placeholder='{"key": "value"}' className="font-mono rounded-md" />
                  </Form.Item>
                )}

                <Button
                  type="primary"
                  htmlType="submit"
                  icon={<SendOutlined />}
                  loading={sending}
                  block
                  size="large"
                  className="bg-brand-orange hover:bg-brand-orange/90 border-none font-semibold rounded-md shadow-md mt-4"
                >
                  Bắn thông báo (Push & Realtime)
                </Button>
              </Form>
            </Card>
          </Col>
          <Col xs={24} lg={10}>
            <Card 
              title={
                <span className="font-semibold dark:text-white flex items-center gap-2">
                  <InfoCircleOutlined className="text-brand-orange" /> Hướng dẫn tích hợp Mobile App
                </span>
              }
              className="rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1 shadow-sm h-full"
            >
              <div className="space-y-4 text-sm text-ink-muted dark:text-ink-darkMuted leading-relaxed">
                <p>
                  Hệ thống thông báo đồng bộ với **Firebase Admin SDK** ở backend. Khi Admin nhấn gửi:
                </p>
                <ol className="list-decimal pl-5 space-y-2 text-xs">
                  <li>
                    Backend lưu bản ghi thông báo vào MongoDB.
                  </li>
                  <li>
                    Backend bắn Socket.IO sự kiện `new_notification` tới người nhận đang online ở web hoặc di động.
                  </li>
                  <li>
                    Đồng thời, backend bóc tách danh sách **FCM Tokens** tương ứng từ user và gọi Firebase SDK bắn Push Notification tới thiết bị người dùng.
                  </li>
                </ol>
                <div className="p-3 bg-neutral-50 dark:bg-neutral-800/30 rounded-lg border border-semantic-border/10 dark:border-semantic-borderDark/10 mt-4">
                  <span className="font-semibold block text-xs dark:text-white mb-1 flex items-center gap-1.5">
                    <SettingOutlined /> Deep Link Định tuyến:
                  </span>
                  <ul className="list-disc pl-5 text-[11px] space-y-1">
                    <li>Đặt metadata <code className="bg-black/5 dark:bg-white/10 px-1 rounded">{"{"}"bookingId": "id"{"}"}</code> $\rightarrow$ Mobile chuyển hướng màn hình Chi tiết Lịch đặt.</li>
                    <li>Đặt metadata <code className="bg-black/5 dark:bg-white/10 px-1 rounded">{"{"}"promotionId": "id"{"}"}</code> $\rightarrow$ Mobile chuyển hướng màn hình Khuyến mãi.</li>
                  </ul>
                </div>
              </div>
            </Card>
          </Col>
        </Row>
      ) : (
        <Table
          dataSource={sentHistory}
          columns={columns}
          rowKey="id"
          loading={loadingHistory}
          pagination={{ pageSize: 8 }}
          className="border border-semantic-border/10 dark:border-semantic-borderDark/10 rounded-xl overflow-hidden shadow-sm bg-white dark:bg-surface-dark1"
        />
      )}
    </div>
  );
};

export default AdminNotificationsPage;
