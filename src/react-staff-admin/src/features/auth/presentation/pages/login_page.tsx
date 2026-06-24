import React, { useState } from 'react';
import { Card, Form, Input, Button, Alert, Typography, App, Space } from 'antd';
import { MailOutlined, LockOutlined, InfoCircleOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { loginUseCase } from '../../../../core/di/injection';
import { authStorage } from '../../../../core/utils/auth_storage';
import { apiClient } from '../../../../core/network/api_client';
import { firebaseAuth } from '../../../../core/firebase/firebase_auth';
import { firebaseErrorMessage } from '../../../../core/firebase/firebase_error_message';
import { reload, sendEmailVerification } from 'firebase/auth';

const { Title, Text } = Typography;

const LoginPage: React.FC = () => {
  const { message } = App.useApp();
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [verificationEmail, setVerificationEmail] = useState<string | null>(null);
  const [otpLoading, setOtpLoading] = useState(false);
  const [form] = Form.useForm();
  const navigate = useNavigate();
  const brandLogoSrc = `${process.env.PUBLIC_URL}/sport-energy-logo.png`;

  const handleLogin = async (values: any) => {
    console.log('[DEBUG LOGIN] Form submitted values:', values);
    setLoading(true);
    setErrorMsg(null);
    try {
      console.log('[DEBUG LOGIN] Calling loginUseCase.execute with email:', values.email);
      const result = await loginUseCase.execute(values.email, values.password);
      console.log('[DEBUG LOGIN] Login success, result:', result);
      
      // Ensure only ADMIN or STAFF can access CRM
      if (result.user.role !== 'ADMIN' && result.user.role !== 'STAFF') {
        throw new Error('Tài khoản không có quyền truy cập CRM');
      }

      // Save tokens and user session
      authStorage.setAccessToken(result.accessToken);
      authStorage.setUser({
        _id: result.user.id,
        email: result.user.email,
        role: result.user.role,
        status: result.user.status,
        profile: {
          fullName: result.user.fullName,
          phone: result.user.phone,
          avatar: result.user.avatar,
        },
        facilityId: result.user.facilityId
      });
      console.log('[DEBUG LOGIN] Saved user to storage:', authStorage.getUser());

      message.success(`Chào mừng trở lại, ${result.user.fullName || 'User'}!`);
      
      // Redirect based on role
      if (result.user.role === 'ADMIN') {
        console.log('[DEBUG LOGIN] Navigating to admin overview');
        navigate('/admin/overview');
      } else {
        console.log('[DEBUG LOGIN] Navigating to staff overview');
        navigate('/staff/overview');
      }
    } catch (err: any) {
      console.error('[DEBUG LOGIN] Exception caught during login process:', err);
      const responseData = err.response?.data;
      if (responseData?.code === 'EMAIL_NOT_VERIFIED') {
        setVerificationEmail(responseData?.data?.email || values.email);
        setErrorMsg(responseData.message || 'Email chưa được xác thực.');
        return;
      }
      setErrorMsg(firebaseErrorMessage(err, 'Không thể đăng nhập. Vui lòng thử lại.'));
    } finally {
      setLoading(false);
    }
  };

  const verifyEmail = async (_values: { otp: string }) => {
    if (!verificationEmail) return;
    setOtpLoading(true);
    try {
      const user = firebaseAuth.currentUser;
      if (!user) throw new Error('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      await reload(user);
      if (!firebaseAuth.currentUser?.emailVerified) throw new Error('Email chưa được xác thực. Hãy mở liên kết Sport Energy trong hộp thư.');
      await apiClient.post('/auth/firebase/complete-email-verification', { firebaseIdToken: await firebaseAuth.currentUser.getIdToken(true) });
      message.success('Xác thực email thành công. Hãy đăng nhập.');
      form.setFieldsValue({ email: verificationEmail });
      setVerificationEmail(null);
    } catch (err: any) {
      setErrorMsg(firebaseErrorMessage(err, 'Xác thực email thất bại.'));
    } finally {
      setOtpLoading(false);
    }
  };

  const resendVerification = async () => {
    if (!verificationEmail) return;
    setOtpLoading(true);
    try {
      const user = firebaseAuth.currentUser;
      if (!user) throw new Error('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      await sendEmailVerification(user);
      message.success('Đã gửi lại liên kết xác nhận email.');
    } catch (err: any) {
      setErrorMsg(firebaseErrorMessage(err, 'Không thể gửi lại liên kết xác thực.'));
    } finally {
      setOtpLoading(false);
    }
  };

  const prefill = (email: string, password = '123456') => {
    form.setFieldsValue({
      email,
      password
    });
  };

  return (
    <div className="min-h-screen w-full flex items-center justify-center bg-canvas dark:bg-canvas-dark p-4 relative overflow-hidden">
      {/* Background circles for premium styling */}
      <div className="absolute w-[500px] h-[500px] rounded-full bg-brand-orange/5 blur-3xl -top-40 -left-40 pointer-events-none" />
      <div className="absolute w-[400px] h-[400px] rounded-full bg-brand-orange/5 blur-3xl -bottom-20 -right-20 pointer-events-none" />

      <Card 
        className="w-full max-w-[420px] shadow-2xl border-none rounded-xxl glass-card py-4"
        style={{ borderRadius: '24px' }}
      >
        <div className="flex flex-col items-center text-center mb-8">
          <img
            src={brandLogoSrc}
            alt="Sport Energy logo"
            className="w-20 h-20 rounded-2xl object-contain shadow-lg shadow-brand-orange/20 mb-4"
          />
          <Title level={2} className="m-0 dark:text-white" style={{ fontFamily: 'Inter, sans-serif', fontWeight: 700 }}>
            Sport Energy
          </Title>
          <Text className="text-ink-muted dark:text-ink-darkMuted mt-1">
            Hệ thống quản lý dành cho Admin & Nhân viên
          </Text>
        </div>

        {errorMsg && (
          <Alert
            message={errorMsg}
            type="error"
            showIcon
            className="mb-6 rounded-md"
          />
        )}

        {verificationEmail ? (
          <Form layout="vertical" onFinish={verifyEmail} requiredMark={false}>
            <Alert type="info" showIcon className="mb-4" message={`Bước 2/2: Kiểm tra email và nhấn liên kết xác thực để kích hoạt tài khoản. Mở liên kết Sport Energy đã gửi đến ${verificationEmail}, sau đó quay lại đây.`} />
            <Button type="primary" htmlType="submit" block loading={otpLoading}>Tôi đã xác thực</Button>
            <Button type="link" block loading={otpLoading} onClick={resendVerification}>Gửi lại liên kết</Button>
            <Button type="text" block onClick={() => setVerificationEmail(null)}>Quay lại đăng nhập</Button>
          </Form>
        ) : <Form
          form={form}
          layout="vertical"
          onFinish={handleLogin}
          autoComplete="off"
          requiredMark={false}
        >
          <Form.Item
            name="email"
            label={<span className="font-medium dark:text-white">Email đăng nhập</span>}
            rules={[
              { required: true, message: 'Vui lòng nhập email!' },
              { type: 'email', message: 'Email không đúng định dạng!' }
            ]}
          >
            <Input 
              prefix={<MailOutlined className="text-ink-subtle" />} 
              placeholder="name@sportenergy.vn"
              size="large"
              className="rounded-md dark:bg-surface-dark2 dark:text-white dark:border-semantic-borderDark"
            />
          </Form.Item>

          <Form.Item
            name="password"
            label={<span className="font-medium dark:text-white">Mật khẩu</span>}
            rules={[{ required: true, message: 'Vui lòng nhập mật khẩu!' }]}
          >
            <Input.Password
              prefix={<LockOutlined className="text-ink-subtle" />}
              placeholder="••••••••"
              size="large"
              className="rounded-md dark:bg-surface-dark2 dark:text-white dark:border-semantic-borderDark"
            />
          </Form.Item>

          <Form.Item className="mt-8">
            <Button
              type="primary"
              htmlType="submit"
              size="large"
              block
              loading={loading}
              className="bg-brand-orange hover:bg-brand-orange/90 border-none font-semibold h-[46px] rounded-md shadow-md shadow-brand-orange/20"
            >
              Đăng nhập
            </Button>
          </Form.Item>
        </Form>}

        {/* Quick Testing accounts container */}
        {/* <div className="mt-6 pt-6 border-t border-semantic-border/40 dark:border-semantic-borderDark/40">
          <div className="flex items-center gap-1.5 text-xs text-brand-orange font-semibold mb-3">
            <InfoCircleOutlined />
            <span>Tài khoản dùng thử (Click để chọn):</span>
          </div>
          <Space wrap size="small">
            <Button 
              size="small" 
              className="text-xs rounded-md bg-canvas dark:bg-surface-dark2 dark:text-white"
              onClick={() => prefill('admin.system@gmail.com')}
            >
              Admin System
            </Button>
            <Button 
              size="small" 
              className="text-xs rounded-md bg-canvas dark:bg-surface-dark2 dark:text-white"
              onClick={() => prefill('staff.test02@gmail.com')}
            >
              Staff Test 02
            </Button>
          </Space>
        </div> */}
      </Card>
    </div>
  );
};

export default LoginPage;
