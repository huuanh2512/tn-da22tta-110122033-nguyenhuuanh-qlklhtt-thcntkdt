import 'package:authentication_module/application/firebase_email_auth_flow.dart';
import 'package:flutter/material.dart';
import 'package:notification_module/notification_module.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ChangePasswordSheet(),
  );

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  static const _primaryColor = Color(0xFFFF5600);
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseEmailAuthFlow.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công.')));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể đổi mật khẩu. Kiểm tra mật khẩu hiện tại rồi thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 12,
      right: 12,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(vi: 'Đổi mật khẩu', en: 'Change password'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  vi: 'Xác nhận mật khẩu hiện tại để đổi mật khẩu.',
                  en: 'Confirm your current password to change your password.',
                ),
              ),
              const SizedBox(height: 20),
              _field(
                _currentPassword,
                context.tr(vi: 'Mật khẩu hiện tại', en: 'Current password'),
              ),
              const SizedBox(height: 14),
              _field(
                _newPassword,
                context.tr(vi: 'Mật khẩu mới', en: 'New password'),
                minLength: 6,
              ),
              const SizedBox(height: 14),
              _field(
                _confirmPassword,
                context.tr(
                  vi: 'Nhập lại mật khẩu mới',
                  en: 'Confirm new password',
                ),
                matchesNew: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.tr(vi: 'Xác nhận', en: 'Confirm')),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    int minLength = 1,
    bool matchesNew = false,
  }) => TextFormField(
    controller: controller,
    obscureText: true,
    enableSuggestions: false,
    autocorrect: false,
    validator: (value) {
      if (value == null || value.length < minLength) {
        return 'Mật khẩu phải có ít nhất $minLength ký tự.';
      }
      if (matchesNew && value != _newPassword.text) {
        return 'Mật khẩu nhập lại không khớp.';
      }
      return null;
    },
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
