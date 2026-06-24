import React, { useState, useEffect } from 'react';
import { Table, Button, Modal, Form, Input, Select, Switch, Space, message, Typography, Tag, Popconfirm } from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined, EnvironmentOutlined } from '@ant-design/icons';
import { MockFacility } from '../../../../core/network/mock_db';
import { UserSession } from '../../../../core/utils/auth_storage';
import { apiClient } from '../../../../core/network/api_client';

const { Title, Text } = Typography;

const AdminFacilitiesPage: React.FC = () => {
  const [facilities, setFacilities] = useState<MockFacility[]>([]);
  const [staffUsers, setStaffUsers] = useState<UserSession[]>([]);
  const [provinces, setProvinces] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingFacility, setEditingFacility] = useState<MockFacility | null>(null);
  const [form] = Form.useForm();

  const loadData = async () => {
    setLoading(true);
    try {
      const resFac = await apiClient.get('/facility');
      setFacilities(resFac.data.items || []);

      const resUsers = await apiClient.get('/user/');
      const staffs = (resUsers.data.items || []).filter((u: UserSession) => u.role === 'STAFF');
      setStaffUsers(staffs);
    } catch (e: any) {
      message.error('Không thể tải dữ liệu');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();

    // Gọi API lấy danh sách 63 Tỉnh/Thành Việt Nam
    const fetchProvinces = async () => {
      try {
        const response = await fetch('https://provinces.open-api.vn/api/p/');
        const data = await response.json();
        const provinceNames = data.map((p: any) => p.name);

        // Sắp xếp theo bảng chữ cái tiếng Việt
        const sortedNames = provinceNames.sort((a: string, b: string) => a.localeCompare(b, 'vi'));
        setProvinces(sortedNames);
      } catch (error) {
        console.error('Lỗi tải danh sách tỉnh thành:', error);
        message.warning('Không thể tải danh sách Tỉnh/Thành tự động.');
      }
    };

    fetchProvinces();
  }, []);

  const handleOpenAdd = () => {
    setEditingFacility(null);
    form.resetFields();
    form.setFieldsValue({ active: true });
    setIsModalOpen(true);
  };

  const handleOpenEdit = (fac: MockFacility) => {
    setEditingFacility(fac);
    form.resetFields();

    form.setFieldsValue({
      name: fac.name,
      city: fac.city,
      fullAddress: fac.fullAddress,
      active: fac.active,
      staffIds: fac.staffIds
    });
    setIsModalOpen(true);
  };

  const handleDelete = async (id: string) => {
    try {
      await apiClient.delete(`/facility/${id}`);
      message.success('Xóa cơ sở thành công!');
      loadData();
    } catch (e: any) {
      message.error('Xóa cơ sở thất bại.');
    }
  };

  const handleSave = async (values: any) => {
    try {
      const payload = {
        name: values.name,
        city: values.city,
        fullAddress: values.fullAddress,
        active: values.active,
        staffIds: values.staffIds || []
      };

      if (editingFacility) {
        await apiClient.put(`/facility/${editingFacility._id}`, payload);
        message.success('Cập nhật cơ sở thành công!');
      } else {
        await apiClient.post('/facility', payload);
        message.success('Thêm mới cơ sở thành công!');
      }
      setIsModalOpen(false);
      loadData();
    } catch (e: any) {
      message.error('Lỗi khi lưu thông tin cơ sở');
    }
  };

  const columns = [
    {
      title: 'Tên Cơ Sở',
      dataIndex: 'name',
      key: 'name',
      render: (name: string) => <span className="font-semibold dark:text-white">{name}</span>,
    },
    {
      title: 'Thành phố / Tỉnh',
      dataIndex: 'city',
      key: 'city',
      render: (city: string) => (
        <span className="flex items-center text-ink dark:text-white font-medium">
          <EnvironmentOutlined className="text-red-500 mr-1.5" />
          {city}
        </span>
      )
    },
    {
      title: 'Địa chỉ chi tiết',
      dataIndex: 'fullAddress',
      key: 'fullAddress',
      render: (addr: string) => <span className="text-ink-muted dark:text-ink-darkMuted text-xs">{addr}</span>
    },
    {
      title: 'Nhân viên phụ trách',
      dataIndex: 'staffIds',
      key: 'staff',
      render: (staffIds: string[]) => {
        if (!staffIds || staffIds.length === 0) {
          return <span className="text-red-500 font-medium">Chưa gán</span>;
        }
        return (
          <Space wrap size="small">
            {staffIds.map(sid => {
              const staff = staffUsers.find(u => u._id === sid || u.id === sid);
              return (
                <Tag color="cyan" key={sid} className="m-0 font-medium rounded-full px-2">
                  {staff?.profile?.fullName || sid}
                </Tag>
              );
            })}
          </Space>
        );
      }
    },
    {
      title: 'Trạng thái',
      dataIndex: 'active',
      key: 'active',
      render: (active: boolean) => (
        <Tag color={active ? 'success' : 'error'} className="border-none font-semibold px-2 py-0.5 rounded">
          {active ? 'Hoạt động' : 'Ngừng'}
        </Tag>
      )
    },
    {
      title: 'Thao tác',
      key: 'actions',
      render: (_: any, record: MockFacility) => (
        <Space size="middle">
          <Button
            type="text"
            icon={<EditOutlined className="text-blue-500" />}
            onClick={() => handleOpenEdit(record)}
            className="hover:bg-blue-50 dark:hover:bg-blue-950/20"
          />
          <Popconfirm
            title="Bạn có chắc chắn muốn xóa cơ sở này?"
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
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4">
        <div>
          <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 700 }}>
            Quản lý Cơ sở / Khu liên hợp
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted">
            Xem danh sách cơ sở thể thao Sport Energy, phân phối nhân viên quản lý cơ sở.
          </Text>
        </div>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={handleOpenAdd}
          size="large"
          className="bg-brand-orange hover:bg-brand-orange/90 border-none rounded-md font-semibold shrink-0 shadow-md shadow-brand-orange/20"
        >
          Thêm Cơ sở mới
        </Button>
      </div>

      <Table
        dataSource={facilities}
        columns={columns}
        rowKey="_id"
        loading={loading}
        pagination={{ pageSize: 8 }}
        className="border border-semantic-border/10 dark:border-semantic-borderDark/10 rounded-xl overflow-hidden shadow-sm bg-white dark:bg-surface-dark1"
      />

      <Modal
        title={<span className="font-bold text-lg dark:text-white">{editingFacility ? 'Chỉnh sửa Cơ sở' : 'Thêm Cơ sở mới'}</span>}
        open={isModalOpen}
        onCancel={() => setIsModalOpen(false)}
        footer={null}
        width={500}
        destroyOnHidden
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSave}
          className="mt-4"
        >
          <Form.Item
            name="name"
            label={<span className="font-semibold dark:text-white">Tên Cơ sở</span>}
            rules={[{ required: true, message: 'Nhập tên cơ sở!' }]}
          >
            <Input placeholder="Ví dụ: Sport Energy Quận 3" className="rounded-md dark:bg-surface-dark2 dark:text-white" />
          </Form.Item>

          <Form.Item
            name="city"
            label={<span className="font-semibold dark:text-white">Thành phố / Tỉnh</span>}
            rules={[{ required: true, message: 'Nhập tên thành phố/tỉnh!' }]}
          >
            <Select
              showSearch
              placeholder="Chọn thành phố / tỉnh"
              className="rounded-md"
              loading={provinces.length === 0}
              filterOption={(input, option) =>
                (option?.children as unknown as string).toLowerCase().includes(input.toLowerCase())
              }
            >
              {provinces.map((province) => (
                <Select.Option key={province} value={province}>
                  {province}
                </Select.Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item
            name="fullAddress"
            label={<span className="font-semibold dark:text-white">Địa chỉ chi tiết</span>}
            rules={[{ required: true, message: 'Nhập địa chỉ chi tiết!' }]}
          >
            <Input.TextArea placeholder="Số nhà, tên đường, phường/xã, quận/huyện..." className="rounded-md dark:bg-surface-dark2 dark:text-white" rows={3} />
          </Form.Item>

          <Form.Item
            name="staffIds"
            label={<span className="font-semibold dark:text-white">Nhân viên phụ trách (Owner)</span>}
          >
            <Select
              mode="multiple"
              placeholder="Chọn các nhân viên phụ trách cơ sở"
              allowClear
              className="rounded-md"
            >
              {staffUsers.map(staff => (
                <Select.Option key={staff.id || staff._id} value={staff.id || staff._id}>
                  {staff.profile?.fullName || staff.email}
                </Select.Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item
            name="active"
            label={<span className="font-semibold dark:text-white">Trạng thái hoạt động</span>}
            valuePropName="checked"
          >
            <Switch checkedChildren="Hoạt động" unCheckedChildren="Tắt" />
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

export default AdminFacilitiesPage;
