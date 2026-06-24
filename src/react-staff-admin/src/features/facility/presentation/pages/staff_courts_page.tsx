import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { DeleteOutlined, EditOutlined, PlusOutlined } from '@ant-design/icons';
import { Button, Form, Input, InputNumber, Modal, Popconfirm, Select, Space, Table, Tag, Typography, message } from 'antd';
import { authStorage } from '../../../../core/utils/auth_storage';
import { formatVND } from '../../../../core/utils/formatters';
import { apiClient } from '../../../../core/network/api_client';

const { Title, Text } = Typography;

interface SportItem {
  _id: string;
  id?: string;
  name: string;
}

interface CourtItem {
  _id: string;
  id?: string;
  name: string;
  code: string;
  status: string;
  pricePerHour: number;
  facility?: { id: string; name: string };
  sport?: { id: string; name: string };
  sportId?: string;
  openingMinutes?: number | null;
  closingMinutes?: number | null;
  slotDurationMinutes?: number | null;
}

const normalizeCourt = (court: any): CourtItem => ({
  ...court,
  _id: court.id || court._id || '',
  code: court.code || '',
  sportId: court.sportId || court.sport_id || court.sport?.id || court.sport?._id,
  pricePerHour: Number(court.pricePerHour ?? court.price_per_hour ?? 0),
});

const StaffCourtsPage: React.FC = () => {
  const user = useMemo(() => authStorage.getUser(), []);
  const facilityId = user?.facilityId;

  const [courts, setCourts] = useState<CourtItem[]>([]);
  const [sports, setSports] = useState<SportItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingCourt, setEditingCourt] = useState<CourtItem | null>(null);
  const [form] = Form.useForm();

  const loadCourtsAndSports = useCallback(async () => {
    if (!facilityId) return;

    setLoading(true);
    try {
      const [resCourts, resSports] = await Promise.all([
        apiClient.get('/court', { params: { facilityId } }),
        apiClient.get('/sport'),
      ]);

      const courtItems: CourtItem[] = (resCourts.data.items || []).map(normalizeCourt);
      const courtsWithConfig = await Promise.allSettled(
        courtItems.map(async (court) => {
          try {
            const resSlot = await apiClient.get(`/court/${court._id}/slot-config`);
            const config = resSlot.data.config;
            return {
              ...court,
              openingMinutes: config?.openingMinutes,
              closingMinutes: config?.closingMinutes,
              slotDurationMinutes: config?.slotDurationMinutes,
            };
          } catch {
            return {
              ...court,
              openingMinutes: null,
              closingMinutes: null,
              slotDurationMinutes: null,
            };
          }
        })
      );

      setCourts(courtsWithConfig.map((result, index) =>
        result.status === 'fulfilled' ? result.value : courtItems[index]
      ));
      setSports((resSports.data.items || []).map((sport: any) => ({
        ...sport,
        _id: sport.id || sport._id || '',
      })));
    } catch (error) {
      console.error('[StaffCourts] Error loading courts or sports:', error);
      message.error('Không thể tải danh sách sân đấu.');
    } finally {
      setLoading(false);
    }
  }, [facilityId]);

  useEffect(() => {
    loadCourtsAndSports();
  }, [loadCourtsAndSports]);

  const openAddModal = () => {
    setEditingCourt(null);
    form.resetFields();
    form.setFieldsValue({ status: 'ACTIVE' });
    setIsModalOpen(true);
  };

  const openEditModal = (court: CourtItem) => {
    setEditingCourt(court);
    form.resetFields();
    form.setFieldsValue({
      name: court.name,
      sportId: court.sportId || court.sport?.id,
      pricePerHour: court.pricePerHour,
      status: court.status,
    });
    setIsModalOpen(true);
  };

  const handleSave = async (values: any) => {
    if (!facilityId) return;

    const payload = {
      name: values.name,
      facilityId,
      sportId: values.sportId,
      pricePerHour: values.pricePerHour,
      status: values.status,
    };

    try {
      if (editingCourt) {
        await apiClient.put(`/court/${editingCourt._id}`, payload);
        message.success('Cập nhật sân đấu thành công.');
      } else {
        await apiClient.post('/court', payload);
        message.success('Thêm sân đấu thành công.');
      }
      setIsModalOpen(false);
      await loadCourtsAndSports();
    } catch (error: any) {
      message.error(error.response?.data?.message || 'Không thể lưu sân đấu.');
    }
  };

  const handleDelete = async (courtId: string) => {
    try {
      await apiClient.delete(`/court/${courtId}`);
      message.success('Xóa sân đấu thành công.');
      await loadCourtsAndSports();
    } catch (error: any) {
      message.error(error.response?.data?.message || 'Không thể xóa sân đấu.');
    }
  };

  const columns = [
    {
      title: 'Mã sân',
      dataIndex: 'code',
      key: 'code',
      render: (code: string) => <span className="font-semibold text-brand-orange text-xs">{code || 'Tự động'}</span>,
    },
    {
      title: 'Tên sân',
      dataIndex: 'name',
      key: 'name',
      render: (name: string) => <span className="font-semibold dark:text-white">{name}</span>,
    },
    {
      title: 'Môn thể thao',
      key: 'sport',
      render: (_: any, record: CourtItem) => {
        if (record.sport?.name) return <Tag color="blue">{record.sport.name}</Tag>;
        const sport = sports.find(item => item._id === record.sportId || item.id === record.sportId);
        return <Tag color={sport ? 'blue' : 'default'}>{sport?.name || 'Chưa gán'}</Tag>;
      },
    },
    {
      title: 'Đơn giá / giờ',
      dataIndex: 'pricePerHour',
      key: 'price',
      render: (price: number) => <span className="font-bold dark:text-white">{formatVND(price)}</span>,
    },
    {
      title: 'Khung giờ vận hành',
      key: 'operation',
      render: (_: any, record: CourtItem) => {
        if (record.openingMinutes == null || record.closingMinutes == null) {
          return <span className="text-xs italic text-ink-muted dark:text-ink-darkMuted">Chưa cấu hình</span>;
        }

        return (
          <span className="text-xs font-semibold text-indigo-500">
            {Math.floor(record.openingMinutes / 60)}h:00 - {Math.floor(record.closingMinutes / 60)}h:00 ({record.slotDurationMinutes}p/ca)
          </span>
        );
      },
    },
    {
      title: 'Trạng thái',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => (
        <Tag color={status === 'ACTIVE' ? 'success' : 'error'} className="border-none font-semibold px-2 py-0.5 rounded">
          {status === 'ACTIVE' ? 'Hoạt động' : 'Bảo trì'}
        </Tag>
      ),
    },
    {
      title: 'Thao tác',
      key: 'actions',
      render: (_: any, record: CourtItem) => (
        <Space size="small">
          <Button type="text" icon={<EditOutlined className="text-blue-500" />} onClick={() => openEditModal(record)} />
          <Popconfirm
            title="Xóa sân đấu này?"
            okText="Xóa"
            cancelText="Đóng"
            okButtonProps={{ danger: true }}
            onConfirm={() => handleDelete(record._id)}
          >
            <Button type="text" danger icon={<DeleteOutlined />} />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  if (user && user.role === 'STAFF' && !facilityId) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[400px] text-center p-6 bg-white dark:bg-surface-dark1 rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 shadow-sm">
        <div className="text-brand-orange text-5xl mb-4">!</div>
        <Title level={4} className="m-0 dark:text-white" style={{ fontWeight: 600 }}>
          Chưa được gán cơ sở hoạt động
        </Title>
        <Text className="text-ink-muted dark:text-ink-darkMuted mt-2 max-w-md block">
          Tài khoản nhân viên của bạn chưa được liên kết với cơ sở thể thao nào. Vui lòng liên hệ quản trị viên để gán cơ sở trước khi quản lý sân.
        </Text>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div>
          <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
            Danh sách sân đấu tại cơ sở
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Quản lý sân, môn thể thao, đơn giá và tình trạng vận hành hiện tại.
          </Text>
        </div>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={openAddModal}
          className="bg-brand-orange hover:bg-brand-orange/90 border-none rounded-md font-semibold"
        >
          Thêm sân đấu
        </Button>
      </div>

      <Table
        dataSource={courts}
        columns={columns}
        rowKey="_id"
        loading={loading}
        pagination={{ pageSize: 8 }}
        className="border border-semantic-border/10 dark:border-semantic-borderDark/10 rounded-xl overflow-hidden shadow-sm bg-white dark:bg-surface-dark1"
      />

      <Modal
        title={<span className="font-bold text-lg dark:text-white">{editingCourt ? 'Chỉnh sửa sân đấu' : 'Thêm sân đấu'}</span>}
        open={isModalOpen}
        onCancel={() => setIsModalOpen(false)}
        footer={null}
        width={520}
        destroyOnClose
      >
        <Form form={form} layout="vertical" onFinish={handleSave} className="mt-4">
          <Form.Item
            name="name"
            label={<span className="font-semibold dark:text-white">Tên sân</span>}
            rules={[{ required: true, message: 'Nhập tên sân.' }]}
          >
            <Input placeholder="Ví dụ: Sân số 1" className="rounded-md dark:bg-surface-dark2 dark:text-white" />
          </Form.Item>

          <Form.Item
            name="sportId"
            label={<span className="font-semibold dark:text-white">Môn thể thao</span>}
            rules={[{ required: true, message: 'Chọn môn thể thao.' }]}
          >
            <Select placeholder="Chọn môn" className="rounded-md">
              {sports.map(sport => (
                <Select.Option key={sport._id} value={sport._id}>{sport.name}</Select.Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item
            name="pricePerHour"
            label={<span className="font-semibold dark:text-white">Đơn giá / giờ</span>}
            rules={[{ required: true, message: 'Nhập đơn giá.' }]}
          >
            <InputNumber<number>
              min={0}
              step={10000}
              style={{ width: '100%' }}
              formatter={value => `${value}`.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}
              parser={value => Number((value || '').replace(/\$\s?|(,*)/g, ''))}
              className="rounded-md dark:bg-surface-dark2 dark:text-white"
            />
          </Form.Item>

          <Form.Item
            name="status"
            label={<span className="font-semibold dark:text-white">Trạng thái</span>}
            rules={[{ required: true, message: 'Chọn trạng thái.' }]}
          >
            <Select className="rounded-md">
              <Select.Option value="ACTIVE">Hoạt động</Select.Option>
              <Select.Option value="MAINTENANCE">Bảo trì</Select.Option>
            </Select>
          </Form.Item>

          <div className="flex gap-3 justify-end border-t border-semantic-border/10 dark:border-semantic-borderDark/10 pt-4 mt-6">
            <Button onClick={() => setIsModalOpen(false)} className="rounded-md">
              Đóng
            </Button>
            <Button type="primary" htmlType="submit" className="bg-brand-orange hover:bg-brand-orange/90 border-none font-semibold rounded-md">
              Lưu sân đấu
            </Button>
          </div>
        </Form>
      </Modal>
    </div>
  );
};

export default StaffCourtsPage;
