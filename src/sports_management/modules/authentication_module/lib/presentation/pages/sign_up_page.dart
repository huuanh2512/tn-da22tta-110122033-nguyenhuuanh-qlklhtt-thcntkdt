// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:app_module/app_module.dart';
import 'package:notification_module/notification_module.dart';
import 'package:authentication_module/presentation/blocs/auth/auth_bloc.dart';
import 'package:authentication_module/presentation/blocs/auth/auth_state.dart';
import 'package:authentication_module/application/firebase_email_auth_flow.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseEmailAuthFlow.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        if (!mounted) return;
        context.go(
          '/verify-email',
          extra: <String, String>{'email': _emailController.text.trim()},
        );
      } catch (error) {
        if (!mounted) return;
        AppPopup.show(
          context,
          message: error.toString(),
          tone: AppPopupTone.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          AppPopup.show(
            context,
            message:
                state.message ??
                context.tr(
                  vi: 'Đăng ký thành công! Hãy xác thực email của bạn.',
                  en: 'Registration successful! Please verify your email.',
                ),
            tone: AppPopupTone.success,
          );
          // Điều hướng sang trang xác thực email truyền kèm email và password
          context.go(
            '/verify-email',
            extra: <String, String>{
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            },
          );
        }
        if (state is AuthFailureState) {
          if (state.code == 'EMAIL_NOT_VERIFIED' ||
              state.code == 'EMAIL_DELIVERY_FAILED') {
            context.go(
              '/verify-email',
              extra: <String, String>{
                'email': _emailController.text.trim(),
                'password': _passwordController.text,
                if (state.code == 'EMAIL_DELIVERY_FAILED')
                  'deliveryFailed': 'true',
              },
            );
            return;
          }
          AppPopup.show(
            context,
            message: state.message,
            tone: AppPopupTone.danger,
          );
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Background decorations
            Positioned.fill(
              child: CustomPaint(painter: AuthBackgroundPainter(theme: theme)),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;

                      return Form(
                        key: _formKey,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.cardColor.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.1),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Back button & Branding header
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 20,
                                    ),
                                    onPressed: isLoading
                                        ? null
                                        : () {
                                            if (context.canPop()) {
                                              context.pop();
                                            } else {
                                              context.go('/sign-in');
                                            }
                                          },
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF5600), // finOrange
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.sports_soccer_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'SPORT ENERGY',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w900,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 12,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  const SizedBox(width: 40), // spacer balance
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                context.tr(vi: 'Đăng ký', en: 'Sign Up'),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr(
                                  vi: 'Tạo tài khoản mới để bắt đầu hành trình của bạn.',
                                  en: 'Create a new account to start your journey.',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Full Name Field
                              _EnergyTextField(
                                controller: _fullNameController,
                                labelText: context.tr(
                                  vi: 'Họ và tên',
                                  en: 'Full name',
                                ),
                                hintText: 'Nguyễn Văn A',
                                prefixIcon: Icons.person_outline,
                                enabled: !isLoading,
                                keyboardType: TextInputType.name,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return context.tr(
                                      vi: 'Vui lòng nhập họ tên',
                                      en: 'Please enter full name',
                                    );
                                  }
                                  if (val.trim().length < 2) {
                                    return context.tr(
                                      vi: 'Họ tên quá ngắn',
                                      en: 'Full name is too short',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Phone Field
                              _EnergyTextField(
                                controller: _phoneController,
                                labelText: context.tr(
                                  vi: 'Số điện thoại',
                                  en: 'Phone number',
                                ),
                                hintText: '0912345678',
                                prefixIcon: Icons.phone_outlined,
                                enabled: !isLoading,
                                keyboardType: TextInputType.phone,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return context.tr(
                                      vi: 'Vui lòng nhập số điện thoại',
                                      en: 'Please enter phone number',
                                    );
                                  }
                                  final phoneRegex = RegExp(
                                    r'^(0[35789])[0-9]{8}$',
                                  );
                                  if (!phoneRegex.hasMatch(val.trim())) {
                                    return context.tr(
                                      vi: 'Số điện thoại 10 số không hợp lệ',
                                      en: 'Invalid 10-digit phone number',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Email Field
                              _EnergyTextField(
                                controller: _emailController,
                                labelText: context.tr(vi: 'Email', en: 'Email'),
                                hintText: 'you@example.com',
                                prefixIcon: Icons.email_outlined,
                                enabled: !isLoading,
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return context.tr(
                                      vi: 'Vui lòng nhập Email',
                                      en: 'Please enter Email',
                                    );
                                  }
                                  final emailRegex = RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  );
                                  if (!emailRegex.hasMatch(val.trim())) {
                                    return context.tr(
                                      vi: 'Định dạng Email không hợp lệ',
                                      en: 'Invalid email format',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password Field
                              _EnergyTextField(
                                controller: _passwordController,
                                labelText: context.tr(
                                  vi: 'Mật khẩu',
                                  en: 'Password',
                                ),
                                hintText: '••••••••',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                enabled: !isLoading,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.5),
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return context.tr(
                                      vi: 'Vui lòng nhập Mật khẩu',
                                      en: 'Please enter Password',
                                    );
                                  }
                                  if (val.length < 6) {
                                    return context.tr(
                                      vi: 'Mật khẩu phải chứa ít nhất 6 ký tự',
                                      en: 'Password must be at least 6 characters',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password Field
                              _EnergyTextField(
                                controller: _confirmPasswordController,
                                labelText: context.tr(
                                  vi: 'Xác nhận mật khẩu',
                                  en: 'Confirm Password',
                                ),
                                hintText: '••••••••',
                                prefixIcon: Icons.lock_reset_outlined,
                                obscureText: _obscureConfirmPassword,
                                enabled: !isLoading,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.5),
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return context.tr(
                                      vi: 'Vui lòng nhập xác nhận Mật khẩu',
                                      en: 'Please enter Password confirmation',
                                    );
                                  }
                                  if (val != _passwordController.text) {
                                    return context.tr(
                                      vi: 'Mật khẩu xác nhận không trùng khớp',
                                      en: 'Confirm password does not match',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),

                              // Sign Up Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: isLoading ? null : _onSignUp,
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          context.tr(
                                            vi: 'Đăng ký tài khoản',
                                            en: 'Register Account',
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Info Badge
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    context.tr(
                                      vi: 'Đã có tài khoản?',
                                      en: 'Already have an account?',
                                    ),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : () {
                                            if (context.canPop()) {
                                              context.pop();
                                            } else {
                                              context.go('/sign-in');
                                            }
                                          },
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFFF5600),
                                    ),
                                    child: Text(
                                      context.tr(
                                        vi: 'Đăng nhập',
                                        en: 'Sign In',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _EnergyTextField({
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(
          prefixIcon,
          color: theme.colorScheme.primary.withOpacity(0.6),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.cardColor.withOpacity(0.7),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}

class AuthBackgroundPainter extends CustomPainter {
  final ThemeData theme;

  AuthBackgroundPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.colorScheme.primary.withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final accentPaint = Paint()
      ..color = const Color(0xFFFF5600)
          .withOpacity(0.025) // finOrange opacity
      ..style = PaintingStyle.fill;

    // Diagonal decorative shapes
    final path = Path();
    path.moveTo(size.width * 0.7, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.25);
    path.close();
    canvas.drawPath(path, accentPaint);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.75);
    path2.lineTo(0, size.height);
    path2.lineTo(size.width * 0.3, size.height);
    path2.close();
    canvas.drawPath(path2, accentPaint);

    // Track lines
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.15),
      140,
      paint,
    );
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 90, paint);
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.85),
      180,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.85),
      130,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
