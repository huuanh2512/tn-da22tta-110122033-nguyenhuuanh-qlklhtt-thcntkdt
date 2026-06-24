import 'package:app_module/app_module.dart';
import 'package:authentication_module/application/firebase_email_auth_flow.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({
    super.key,
    required this.email,
    this.password = '',
    this.deliveryFailed = false,
  });
  final String email;
  final String password;
  final bool deliveryFailed;
  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _sending = false;
  bool _checking = false;
  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await FirebaseEmailAuthFlow.resendVerification();
      if (mounted) {
        AppPopup.show(
          context,
          message: 'Đã gửi lại liên kết xác thực Sport Energy.',
          tone: AppPopupTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        AppPopup.show(
          context,
          message: error.toString(),
          tone: AppPopupTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _checking = true);
    try {
      await FirebaseEmailAuthFlow.completeVerification();
      if (mounted) {
        context.go('/home');
      }
    } catch (_) {
      if (mounted) {
        AppPopup.show(
          context,
          message:
              'Email chưa được xác thực. Hãy mở liên kết trong hộp thư rồi thử lại.',
          tone: AppPopupTone.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 72),
              const SizedBox(height: 20),
              const Text(
                'Xác thực Email',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Bước 2/2: Kiểm tra email và nhấn liên kết xác thực để kích hoạt tài khoản.\n\nSport Energy đã gửi liên kết xác thực đến\n${widget.email}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _checking ? null : _complete,
                child: Text(_checking ? 'Đang kiểm tra...' : 'Tôi đã xác thực'),
              ),
              TextButton(
                onPressed: _sending ? null : _resend,
                child: Text(_sending ? 'Đang gửi...' : 'Gửi lại liên kết'),
              ),
              TextButton(
                onPressed: () => context.go('/sign-in'),
                child: const Text('Quay lại đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
