import React, { useState, useEffect } from 'react';
import { Table, Button, Modal, Form, Input, InputNumber, Select, Space, message, Typography, Tag, Popconfirm } from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined } from '@ant-design/icons';
import { MockCourt, MockFacility, MockSport } from '../../../../core/network/mock_db';
import { formatVND } from '../../../../core/utils/formatters';
import { apiClient } from '../../../../core/network/api_client';

const { Title, Text } = Typography;

type CourtItem = MockCourt & {
  id?: string;
  facility?: { id?: string; _id?: string; name?: string };
  sport?: { id?: string; _id?: string; name?: string };
};

const getRefId = (value: any): string => {
  if (!value) return '';
  if (typeof value === 'string') return value;
  return value.id || value._id || '';
};

const getSportName = (sportId: string, record?: CourtItem, sports: MockSport[] = []) => {
  if (record?.sport?.name) return record.sport.name;
  const sport = sports.find((item: any) => item._id === sportId || item.id === sportId);
  return sport?.name || 'Chưa gán';
};

const normalizeCourt = (court: any): CourtItem => ({
  ...court,
  _id: court._id || court.id || '',
  facilityId: court.facilityId || court.facility_id || getRefId(court.facility),
  sportId: court.sportId || court.sport_id || getRefId(court.sport),
  pricePerHour: Number(court.pricePerHour ?? court.price_per_hour ?? 0),
});

const AdminCourtsPage: React.FC = () => {
  const [courts, setCourts] = useState<CourtItem[]>([]);
  const [facilities, setFacilities] = useState<MockFacility[]>([]);
  const [sports, setSports] = useState<MockSport[]>([]);
  const [loading, setLoading] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingCourt, setEditingCourt] = useState<MockCourt | null>(null);
  const [form] = Form.useForm();

  const loadData = async () => {
    setLoading(true);
    try {
      const resCourts = await apiClient.get('/court');
      setCourts((resCourts.data.items || []).map(normalizeCourt));

      const resFac = await apiClient.get('/facility');
      setFacilities(resFac.data.items || []);

      const resSport = await apiClient.get('/sport');
      setSports(resSport.data.items || []);
    } catch (e: any) {
      message.error('Không thể tải dữ liệu');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleOpenAdd = () => {
    setEditingCourt(null);
    form.resetFields();
    form.setFieldsValue({ status: 'ACTIVE' });
    setIsModalOpen(true);
  };

  const handleOpenEdit = (court: CourtItem) => {
    setEditingCourt(court);
    form.resetFields();
    form.setFieldsValue({
      name: court.name,
      code: court.code,
      facilityId: court.facilityId || getRefId(court.facility),
      sportId: court.sportId || getRefId(court.sport),
      pricePerHour: court.pricePerHour,
      status: court.status
    });
    setIsModalOpen(true);
  };

  const handleDelete = async (id: string) => {
    try {
      await apiClient.delete(`/court/${id}`);
      message.success('Xóa sân thành công!');
      loadData();
    } catch (e: any) {
      message.error('Xóa sân thất bại.');
    }
  };

  const handleSave = async (values: any) => {
    try {
      const payload = {
        name: values.name,
        code: values.code,
        facilityId: values.facilityId,
        sportId: values.sportId,
        pricePerHour: values.pricePerHour,
        status: values.status
      };

      if (editingCourt) {
        await apiClient.put(`/court/${editingCourt._id}`, payload);
        message.success('Cập nhật sân thành công!');
      } else {
        await apiClient.post('/court', payload);
        message.success('Thêm sân mới thành công!');
      }
      setIsModalOpen(false);
      loadData();
    } catch (e: any) {
      message.error('Lỗi khi lưu thông tin sân đấu');
    }
  };

  const columns = [
    {
      title: 'Mã sân',
      dataIndex: 'code',
      key: 'code',
      render: (code: string) => <span className="font-semibold text-brand-orange text-xs">{code}</span>,
    },
    {
      title: 'Tên Sân',
      dataIndex: 'name',
      key: 'name',
      render: (name: string) => <span className="font-semibold dark:text-white">{name}</span>,
    },
    {
      title: 'Thuộc Cơ sở',
      dataIndex: 'facilityId',
      key: 'facility',
      render: (fid: string) => {
        const fac = facilities.find(f => f._id === fid);
        return <span className="dark:text-white">{fac ? fac.name : fid}</span>;
      }
    },
    {
      title: 'Môn thể thao',
      dataIndex: 'sportId',
      key: 'sport',
      render: (sid: string, record: CourtItem) => {
        const name = getSportName(sid, record, sports);
        return <Tag color={name === 'Chưa gán' ? 'default' : 'blue'}>{name}</Tag>;
      }
    },
    {
      title: 'Đơn giá / Giờ',
      dataIndex: 'pricePerHour',
      key: 'price',
      render: (price: number) => <span className="font-bold dark:text-white">{formatVND(price)}</span>
    },
    {
      title: 'Trạng thái',
      dataIndex: 'status',
      key: 'status',
      render: (status: MockCourt['status']) => (
        <Tag color={status === 'ACTIVE' ? 'success' : 'error'} className="border-none font-semibold px-2 py-0.5 rounded">
          {status === 'ACTIVE' ? 'Hoạt động' : 'Bảo trì'}
        </Tag>
      )
    },
    {
      title: 'Thao tác',
      key: 'actions',
      render: (_: any, record: CourtItem) => (
        <Space size="middle">
          <Button 
            type="text" 
            icon={<EditOutlined className="text-blue-500" />} 
            onClick={() => handleOpenEdit(record)}
            className="hover:bg-blue-50 dark:hover:bg-blue-950/20"
          />
          <Popconfirm
            title="Bạn có chắc chắn muốn xóa sân này?"
            onConfirm={() => handleDelete(record._id)}
            okText="Xóa"
            cancelText="Hủy"
            okButtonProps={{ danger: true }}
          >
            <Button 
              type="text" 
              danger
              icon={<DeleteOutlined />} 
              className="hover:bg-red-50 dark:hover:bg-red-950/20"
            />
          </Popconfirm>
        </Space>
      )
    }
  ];

  return (
    <div className="space-y-6">
      {/* Title */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div>
          <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
            Quản lý Sân đấu
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Xem danh sách các sân vận hành của toàn hệ thống, cấu hình đơn giá theo giờ.
          </Text>
        </div>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={handleOpenAdd}
          size="large"
          className="bg-brand-orange hover:bg-brand-orange/90 border-none rounded-md font-semibold shrink-0 shadow-md shadow-brand-orange/20"
        >
          Thêm Sân mới
        </Button>
      </div>

      {/* Table */}
      <Table
        dataSource={courts}
        columns={columns}
        rowKey="_id"
        loading={loading}
        pagination={{ pageSize: 8 }}
        className="border border-semantic-border/10 dark:border-semantic-borderDark/10 rounded-xl overflow-hidden shadow-sm bg-white dark:bg-surface-dark1"
      />

      {/* Add/Edit Modal */}
      <Modal
        title={<span className="font-bold text-lg dark:text-white">{editingCourt ? 'Chỉnh sửa Sân đấu' : 'Thêm Sân mới'}</span>}
        open={isModalOpen}
        onCancel={() => setIsModalOpen(false)}
        footer={null}
        width={500}
        destroyOnClose
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSave}
          className="mt-4"
        >
          <Form.Item
            name="name"
            label={<span className="font-semibold dark:text-white">Tên Sân</span>}
            rules={[{ required: true, message: 'Nhập tên sân!' }]}
          >
            <Input placeholder="Ví dụ: Sân Bóng Đá Mini 1" className="rounded-md dark:bg-surface-dark2 dark:text-white" />
          </Form.Item>

          <Form.Item
            name="code"
            label={<span className="font-semibold dark:text-white">Mã sân</span>}
            rules={[{ required: true, message: 'Nhập mã sân!' }]}
          >
            <Input placeholder="Ví dụ: FB01" className="rounded-md dark:bg-surface-dark2 dark:text-white" />
          </Form.Item>

          <Form.Item
            name="facilityId"
            label={<span className="font-semibold dark:text-white">Khu phức hợp / Cơ sở</span>}
            rules={[{ required: true, message: 'Chọn cơ sở sân thuộc về!' }]}
          >
            <Select placeholder="Chọn cơ sở" className="rounded-md">
              {facilities.map(f => (
                <Select.Option key={f._id} value={f._id}>{f.name}</Select.Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item
            name="sportId"
            label={<span className="font-semibold dark:text-white">Môn thể thao</span>}
            rules={[{ required: true, message: 'Chọn môn thể thao!' }]}
          >
            <Select placeholder="Chọn môn" className="rounded-md">
              {sports.map(s => (
                <Select.Option key={s._id} value={s._id}>{s.name}</Select.Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item
            name="pricePerHour"
            label={<span className="font-semibold dark:text-white">Đơn giá giờ (VNĐ)</span>}
            rules={[{ required: true, message: 'Nhập đơn giá giờ!' }]}
          >
            <InputNumber
              style={{ width: '100%' }}
              formatter={value => `${value}`.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}
              parser={value => value ? value.replace(/\$\s?|(,*)/g, '') : ''}
              placeholder="300,000"
              className="rounded-md dark:bg-surface-dark2 dark:text-white"
            />
          </Form.Item>

          <Form.Item
            name="status"
            label={<span className="font-semibold dark:text-white">Trạng thái</span>}
            rules={[{ required: true, message: 'Chọn trạng thái!' }]}
          >
            <Select className="rounded-md">
              <Select.Option value="ACTIVE">Hoạt động</Select.Option>
              <Select.Option value="MAINTENANCE">Bảo trì / Sửa chữa</Select.Option>
            </Select>
          </Form.Item>

          <div className="flex gap-3 justify-end border-t border-semantic-border/10 dark:border-semantic-borderDark/10 pt-4 mt-6">
            <Button onClick={() => setIsModalOpen(false)} className="rounded-md">
              Hủy bỏ
            </Button>
            <Button
              type="primary"
              htmlType="submit"
              className="bg-brand-orange hover:bg-brand-orange/90 border-none font-semibold rounded-md shadow-md"
            >
              Xác nhận Lưu
            </Button>
          </div>
        </Form>
      </Modal>
    </div>
  );
};

export default AdminCourtsPage;
