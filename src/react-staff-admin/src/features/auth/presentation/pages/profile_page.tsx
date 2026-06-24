import React, { useEffect, useState } from 'react';
import { App, Avatar, Button, Card, Descriptions, Form, Input, Modal, Space, Tag, Typography, Upload } from 'antd';
import {
  DeleteOutlined,
  EnvironmentOutlined,
  LockOutlined,
  MailOutlined,
  PhoneOutlined,
  SafetyCertificateOutlined,
  UploadOutlined,
  UserOutlined,
} from '@ant-design/icons';
import { authStorage, UserSession } from '../../../../core/utils/auth_storage';
import { apiClient } from '../../../../core/network/api_client';
import { firebaseAuth } from '../../../../core/firebase/firebase_auth';
import { firebaseErrorMessage } from '../../../../core/firebase/firebase_error_message';
import { EmailAuthProvider, reauthenticateWithCredential, sendPasswordResetEmail, updatePassword } from 'firebase/auth';

const { Title, Text } = Typography;

interface FacilityState {
  id: string;
  name: string;
  city?: string;
  fullAddress?: string;
}

const isObjectIdLike = (value?: string) => !!value && value.length <= 24 && /^[0-9a-fA-F]+$/.test(value);

const ProfilePage: React.FC = () => {
  const { message } = App.useApp();
  const [user, setUser] = useState<UserSession | null>(authStorage.getUser());
  const [editingProfile, setEditingProfile] = useState(false);
  const [passwordOpen, setPasswordOpen] = useState(false);
  const [facilityOpen, setFacilityOpen] = useState(false);
  const [facility, setFacility] = useState<FacilityState | null>(null);
  const [sendingOtp, setSendingOtp] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);
  const [savingFacility, setSavingFacility] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [savingAvatar, setSavingAvatar] = useState(false);
  const [profileForm] = Form.useForm();
  const [passwordForm] = Form.useForm();
  const [facilityForm] = Form.useForm();

  const loadFacility = async (currentUser = user) => {
    if (!currentUser || currentUser.role !== 'STAFF' || !currentUser.facilityId) return;

    if (!isObjectIdLike(currentUser.facilityId)) {
      setFacility({ id: '', name: currentUser.facilityId, fullAddress: '' });
      return;
    }

    try {
      const res = await apiClient.get(`/facility/${currentUser.facilityId}`);
      const raw = res.data.facility || res.data.data?.facility || res.data;
      setFacility({
        id: raw.id || raw._id || currentUser.facilityId,
        name: raw.name || 'Chưa được phân bổ',
        city: raw.city || raw.address?.city || '',
        fullAddress: raw.fullAddress || raw.address?.full || '',
      });
    } catch {
      setFacility({ id: currentUser.facilityId, name: 'Chưa được phân bổ', fullAddress: '' });
    }
  };

  useEffect(() => {
    loadFacility();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?._id, user?.facilityId, user?.role]);

  if (!user) return <div>Không tìm thấy thông tin phiên đăng nhập.</div>;

  const userId = user._id || user.id || '';
  const fallbackAvatar = `https://api.dicebear.com/7.x/adventurer/svg?seed=${userId}`;
  const avatarSrc = user.profile?.avatar || fallbackAvatar;

  const persistUserProfile = (
    profile: any,
    fallback: { fullName?: string; phone?: string; avatar?: string },
  ) => {
    const updatedUser: UserSession = {
      ...user,
      profile: {
        fullName: profile?.fullName || profile?.name || fallback.fullName || user.profile?.fullName,
        phone: profile?.phone || fallback.phone || user.profile?.phone,
        avatar:
          fallback.avatar !== undefined
            ? fallback.avatar
            : profile?.avatar || profile?.avatarUrl || user.profile?.avatar,
      },
    };
    authStorage.setUser(updatedUser);
    setUser(updatedUser);
    return updatedUser;
  };

  const handleUpdateProfile = async (values: any) => {
    try {
      const response = await apiClient.put(`/user/${userId}`, {
        profile: {
          fullName: values.fullName,
          name: values.fullName,
          phone: values.phone,
          avatar: user.profile?.avatar,
        },
      });
      const profile = response.data.user?.profile || {
        fullName: values.fullName,
        name: values.fullName,
        phone: values.phone,
        avatar: user.profile?.avatar,
      };
      persistUserProfile(profile, {
        fullName: values.fullName,
        phone: values.phone,
        avatar: user.profile?.avatar,
      });
      message.success('Cập nhật thông tin cá nhân thành công.');
      setEditingProfile(false);
    } catch (e: any) {
      message.error(e.response?.data?.message || 'Không thể cập nhật thông tin cá nhân.');
    }
  };

  const extractUploadedUrl = (data: any) =>
    data?.data?.url ||
    data?.url ||
    data?.file?.url ||
    data?.data?.file?.url ||
    '';

  const beforeAvatarUpload = (file: File) => {
    if (!file.type.startsWith('image/')) {
      message.error('Vui lòng chọn file hình ảnh.');
      return Upload.LIST_IGNORE;
    }

    if (file.size / 1024 / 1024 >= 5) {
      message.error('Kích thước ảnh phải nhỏ hơn 5MB.');
      return Upload.LIST_IGNORE;
    }

    return true;
  };

  const handleAvatarUpload = async (options: any) => {
    const { file, onError, onSuccess } = options;
    const formData = new FormData();
    formData.append('file', file as File);
    setUploadingAvatar(true);
    setSavingAvatar(true);

    try {
      const uploadResponse = await apiClient.post('/upload/single', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const uploadedUrl = extractUploadedUrl(uploadResponse.data);

      if (!uploadedUrl) {
        throw new Error('Missing uploaded avatar URL');
      }

      const response = await apiClient.put(`/user/${userId}`, {
        profile: {
          fullName: user.profile?.fullName,
          name: user.profile?.fullName,
          phone: user.profile?.phone,
          avatar: uploadedUrl,
          avatarUrl: uploadedUrl,
        },
      });
      persistUserProfile(response.data.user?.profile, { avatar: uploadedUrl });
      message.success('Cập nhật ảnh đại diện thành công.');
      onSuccess?.(uploadResponse.data);
    } catch (error: any) {
      message.error(error.response?.data?.message || 'Không thể cập nhật ảnh đại diện.');
      onError?.(error);
    } finally {
      setUploadingAvatar(false);
      setSavingAvatar(false);
    }
  };

  const handleRemoveAvatar = () => {
    if (!user.profile?.avatar) return;

    Modal.confirm({
      title: 'Xóa ảnh đại diện?',
      content: 'Hồ sơ sẽ quay về ảnh mặc định của tài khoản.',
      okText: 'Xóa',
      cancelText: 'Hủy',
      okButtonProps: { danger: true },
      onOk: async () => {
        setSavingAvatar(true);
        try {
          const response = await apiClient.put(`/user/${userId}`, {
            profile: {
              fullName: user.profile?.fullName,
              name: user.profile?.fullName,
              phone: user.profile?.phone,
              avatar: '',
              avatarUrl: '',
            },
          });
          persistUserProfile(response.data.user?.profile, { avatar: '' });
          message.success('Đã xóa ảnh đại diện.');
        } catch (e: any) {
          message.error(e.response?.data?.message || 'Không thể xóa ảnh đại diện.');
        } finally {
          setSavingAvatar(false);
        }
      },
    });
  };

  const handleSendOtp = async () => {
    setSendingOtp(true);
    try {
      if (user?.email) await sendPasswordResetEmail(firebaseAuth, user.email);
      message.success('Mã OTP đã được gửi đến email tài khoản.');
    } catch (e: any) {
      message.error(firebaseErrorMessage(e, 'Không thể gửi email đặt lại mật khẩu.'));
    } finally {
      setSendingOtp(false);
    }
  };

  const handleChangePassword = async (values: any) => {
    setSavingPassword(true);
    try {
      const currentUser = firebaseAuth.currentUser;
      if (!currentUser?.email) throw new Error('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      await reauthenticateWithCredential(currentUser, EmailAuthProvider.credential(currentUser.email, values.currentPassword));
      await updatePassword(currentUser, values.newPassword);
      message.success('Đổi mật khẩu thành công.');
      setPasswordOpen(false);
      passwordForm.resetFields();
    } catch (e: any) {
      message.error(firebaseErrorMessage(e, 'Không thể đổi mật khẩu.'));
    } finally {
      setSavingPassword(false);
    }
  };

  const openFacilityModal = () => {
    facilityForm.setFieldsValue({
      name: facility?.name,
      fullAddress: facility?.fullAddress,
    });
    setFacilityOpen(true);
  };

  const handleUpdateFacility = async (values: any) => {
    if (!facility?.id) {
      message.error('Không xác định được cơ sở cần cập nhật.');
      return;
    }

    setSavingFacility(true);
    try {
      const response = await apiClient.put(`/facility/${facility.id}`, {
        name: values.name,
        fullAddress: values.fullAddress,
      });
      const raw = response.data.facility || response.data.data?.facility || {};
      const updatedFacility = {
        id: raw.id || raw._id || facility.id,
        name: raw.name || values.name,
        city: raw.city || raw.address?.city || facility.city || '',
        fullAddress: raw.fullAddress || raw.address?.full || values.fullAddress,
      };
      setFacility(updatedFacility);
      setFacilityOpen(false);
      message.success('Cập nhật cơ sở thành công.');
    } catch (e: any) {
      message.error(e.response?.data?.message || 'Không thể cập nhật cơ sở.');
    } finally {
      setSavingFacility(false);
    }
  };

  return (
    <div className="max-w-5xl mx-auto py-4">
      <div className="flex flex-col md:flex-row gap-6 items-start">
        <Card className="w-full md:w-80 text-center shadow-sm rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1">
          <div className="flex flex-col items-center py-4">
            <Avatar
              size={120}
              src={avatarSrc}
              icon={<UserOutlined />}
              className="bg-brand-orange border-4 border-brand-orange/20 shadow-md mb-4"
            />
            <Space wrap className="mb-4 justify-center">
              <Upload
                accept="image/*"
                showUploadList={false}
                customRequest={handleAvatarUpload}
                beforeUpload={beforeAvatarUpload}
              >
                <Button icon={<UploadOutlined />} loading={uploadingAvatar} className="rounded-md">
                  {user.profile?.avatar ? 'Sửa ảnh' : 'Thêm ảnh'}
                </Button>
              </Upload>
              <Button
                danger
                icon={<DeleteOutlined />}
                onClick={handleRemoveAvatar}
                disabled={!user.profile?.avatar || uploadingAvatar}
                loading={savingAvatar && !uploadingAvatar}
                className="rounded-md"
              >
                Xóa ảnh
              </Button>
            </Space>
            <Title level={3} className="m-0 dark:text-white" style={{ fontWeight: 600 }}>
              {user.profile?.fullName || 'Người dùng'}
            </Title>
            <Tag color={user.role === 'ADMIN' ? 'gold' : 'blue'} className="mt-2 text-sm px-3 py-0.5 rounded-full font-semibold border-none">
              {user.role === 'ADMIN' ? 'QUẢN TRỊ VIÊN' : 'NHÂN VIÊN CƠ SỞ'}
            </Tag>
            <Text className="text-ink-muted dark:text-ink-darkMuted mt-3 block text-sm">
              Mã số: {userId}
            </Text>
          </div>
        </Card>

        <div className="flex-1 w-full space-y-6">
          <Card className="shadow-sm rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4 mb-6">
              <Title level={4} className="m-0 dark:text-white" style={{ fontWeight: 600 }}>
                Thông tin chi tiết
              </Title>
              {!editingProfile && (
                <Space wrap>
                  <Button icon={<LockOutlined />} onClick={() => setPasswordOpen(true)} className="rounded-md">
                    Đổi mật khẩu
                  </Button>
                  <Button
                    type="primary"
                    onClick={() => {
                      profileForm.setFieldsValue({
                        fullName: user.profile?.fullName,
                        phone: user.profile?.phone,
                      });
                      setEditingProfile(true);
                    }}
                    className="bg-brand-orange hover:bg-brand-orange/90 border-none rounded-md"
                  >
                    Chỉnh sửa
                  </Button>
                </Space>
              )}
            </div>

            {editingProfile ? (
              <Form form={profileForm} layout="vertical" onFinish={handleUpdateProfile}>
                <Form.Item
                  name="fullName"
                  label={<span className="font-semibold dark:text-white">Họ và tên</span>}
                  rules={[{ required: true, message: 'Vui lòng nhập họ tên.' }]}
                >
                  <Input size="large" className="rounded-md dark:bg-surface-dark2 dark:text-white dark:border-semantic-borderDark" />
                </Form.Item>

                <Form.Item
                  name="phone"
                  label={<span className="font-semibold dark:text-white">Số điện thoại</span>}
                  rules={[{ required: true, message: 'Vui lòng nhập số điện thoại.' }]}
                >
                  <Input size="large" className="rounded-md dark:bg-surface-dark2 dark:text-white dark:border-semantic-borderDark" />
                </Form.Item>

                <Form.Item className="mb-0 flex gap-2 justify-end">
                  <Button onClick={() => setEditingProfile(false)} className="rounded-md mr-2 dark:bg-surface-dark2 dark:text-white dark:border-semantic-borderDark">
                    Hủy
                  </Button>
                  <Button type="primary" htmlType="submit" className="bg-brand-orange hover:bg-brand-orange/90 border-none rounded-md">
                    Lưu thay đổi
                  </Button>
                </Form.Item>
              </Form>
            ) : (
              <Descriptions column={1} labelStyle={{ fontWeight: 600, width: '180px' }} contentStyle={{ color: 'inherit' }} className="dark:text-white">
                <Descriptions.Item label={<span><MailOutlined className="mr-2 text-brand-orange" /> Email</span>}>
                  {user.email}
                </Descriptions.Item>
                <Descriptions.Item label={<span><PhoneOutlined className="mr-2 text-brand-orange" /> Số điện thoại</span>}>
                  {user.profile?.phone || 'Chưa cập nhật'}
                </Descriptions.Item>
                <Descriptions.Item label={<span><SafetyCertificateOutlined className="mr-2 text-brand-orange" /> Phân quyền</span>}>
                  <Tag color={user.role === 'ADMIN' ? 'gold' : 'blue'}>{user.role === 'ADMIN' ? 'ADMIN' : 'STAFF'}</Tag>
                </Descriptions.Item>
              </Descriptions>
            )}
          </Card>

          {user.role === 'STAFF' && (
            <Card className="shadow-sm rounded-xl border border-semantic-border/20 dark:border-semantic-borderDark/20 bg-white dark:bg-surface-dark1">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 border-b border-semantic-border/10 dark:border-semantic-borderDark/10 pb-4 mb-6">
                <Title level={4} className="m-0 dark:text-white" style={{ fontWeight: 600 }}>
                  Cơ sở phụ trách
                </Title>
                <Button
                  icon={<EnvironmentOutlined />}
                  onClick={openFacilityModal}
                  disabled={!facility?.id}
                  className="rounded-md"
                >
                  Sửa tên và địa chỉ
                </Button>
              </div>
              <Descriptions column={1} labelStyle={{ fontWeight: 600, width: '180px' }} className="dark:text-white">
                <Descriptions.Item label="Tên cơ sở">
                  <span className="font-semibold text-brand-orange">{facility?.name || 'Chưa được phân bổ'}</span>
                </Descriptions.Item>
                <Descriptions.Item label="Địa chỉ">
                  {facility?.fullAddress || 'Chưa cập nhật'}
                </Descriptions.Item>
              </Descriptions>
            </Card>
          )}
        </div>
      </div>

      <Modal
        title="Đổi mật khẩu"
        open={passwordOpen}
        onCancel={() => setPasswordOpen(false)}
        footer={null}
        destroyOnClose
      >
        <Text className="text-ink-muted dark:text-ink-darkMuted">
          OTP sẽ được gửi đến email tài khoản: <b>{user.email}</b>
        </Text>
        <Form form={passwordForm} layout="vertical" onFinish={handleChangePassword} className="mt-4">
          <Form.Item
            name="currentPassword"
            label="Mã OTP"
            rules={[
              { required: true, message: 'Vui lòng nhập OTP.' },
              { len: 6, message: 'OTP gồm 6 chữ số.' },
            ]}
          >
            <Input maxLength={6} placeholder="Nhập OTP" />
          </Form.Item>
          <Form.Item
            name="newPassword"
            label="Mật khẩu mới"
            rules={[
              { required: true, message: 'Vui lòng nhập mật khẩu mới.' },
              { min: 8, message: 'Mật khẩu mới phải có ít nhất 8 ký tự.' },
            ]}
          >
            <Input.Password placeholder="Nhập mật khẩu mới" />
          </Form.Item>
          <Form.Item
            name="confirmPassword"
            label="Nhập lại mật khẩu mới"
            dependencies={['newPassword']}
            rules={[
              { required: true, message: 'Vui lòng nhập lại mật khẩu mới.' },
              ({ getFieldValue }) => ({
                validator(_, value) {
                  if (!value || getFieldValue('newPassword') === value) return Promise.resolve();
                  return Promise.reject(new Error('Mật khẩu nhập lại không khớp.'));
                },
              }),
            ]}
          >
            <Input.Password placeholder="Nhập lại mật khẩu mới" />
          </Form.Item>
          <div className="flex justify-between gap-3">
            <Button onClick={handleSendOtp} loading={sendingOtp}>
              Gửi OTP
            </Button>
            <Button type="primary" htmlType="submit" loading={savingPassword} className="bg-brand-orange hover:bg-brand-orange/90 border-none">
              Xác nhận đổi mật khẩu
            </Button>
          </div>
        </Form>
      </Modal>

      <Modal
        title="Cập nhật cơ sở"
        open={facilityOpen}
        onCancel={() => setFacilityOpen(false)}
        footer={null}
        destroyOnClose
      >
        <Form form={facilityForm} layout="vertical" onFinish={handleUpdateFacility}>
          <Form.Item
            name="name"
            label="Tên cơ sở"
            rules={[{ required: true, message: 'Vui lòng nhập tên cơ sở.' }]}
          >
            <Input placeholder="Tên cơ sở" />
          </Form.Item>
          <Form.Item
            name="fullAddress"
            label="Địa chỉ"
            rules={[{ required: true, message: 'Vui lòng nhập địa chỉ.' }]}
          >
            <Input.TextArea rows={3} placeholder="Địa chỉ đầy đủ" />
          </Form.Item>
          <div className="flex justify-end gap-3">
            <Button onClick={() => setFacilityOpen(false)}>Hủy</Button>
            <Button type="primary" htmlType="submit" loading={savingFacility} className="bg-brand-orange hover:bg-brand-orange/90 border-none">
              Lưu cơ sở
            </Button>
          </div>
        </Form>
      </Modal>
    </div>
  );
};

export default ProfilePage;
