import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:authentication_module/authentication_module.dart';

class CompleteProfileSection extends StatefulWidget {
  final String userId;
  final VoidCallback onProfileUpdated;

  const CompleteProfileSection({
    super.key,
    required this.userId,
    required this.onProfileUpdated,
  });

  @override
  State<CompleteProfileSection> createState() => _CompleteProfileSectionState();
}

class _CompleteProfileSectionState extends State<CompleteProfileSection>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final request = UpdateProfileRequest(
      userId: widget.userId,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    try {
      final useCase = GetIt.I<UpdateProfileUseCase>();
      final result = await useCase.call(request);

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (!mounted) return;

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${failure.message}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
        (userResult) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật thông tin thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onProfileUpdated();
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xảy ra lỗi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5600),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await GetIt.I<ClearLocalSessionUseCase>()();
      if (mounted) {
        context.go('/sign-in');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Sporty court lines background
          Positioned.fill(
            child: CustomPaint(
              painter: CompleteProfileBackgroundPainter(),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: child,
                      ),
                    );
                  },
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sport Energy Logo Icon with branding
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5600), // finOrange
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.sports_soccer,
                                size: 24,
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
                                fontSize: 16,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'Thiết lập Hồ sơ',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cung cấp thông tin của bạn để chúng tôi phục vụ bạn tốt hơn tại hệ thống sân chơi thể thao.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 36),
                        // Full Name input field
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Họ và tên',
                            hintText: 'Nguyễn Văn A',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: theme.colorScheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập Họ và tên';
                            }
                            if (value.trim().length < 2) {
                              return 'Họ tên quá ngắn';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Phone input field
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Số điện thoại',
                            hintText: '09xxxxxxxx',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              color: theme.colorScheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập Số điện thoại';
                            }
                            final cleanVal = value.trim();
                            final phoneRegex = RegExp(r'^(0[3|5|7|8|9])+([0-9]{8})$');
                            if (!phoneRegex.hasMatch(cleanVal)) {
                              return 'Số điện thoại 10 số không hợp lệ (ví dụ: 0912345678)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 40),
                        // Submit button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5600),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Hoàn tất và Tiếp tục',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        // Log out / exit back button
                        TextButton.icon(
                          onPressed: _isLoading ? null : _handleLogout,
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          label: const Text(
                            'Đăng nhập tài khoản khác',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CompleteProfileBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final accentPaint = Paint()
      ..color = const Color(0xFFFF5600).withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    // Sporty corner shapes
    final path = Path();
    path.moveTo(size.width * 0.6, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.3);
    path.close();
    canvas.drawPath(path, accentPaint);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    path2.lineTo(0, size.height);
    path2.lineTo(size.width * 0.4, size.height);
    path2.close();
    canvas.drawPath(path2, accentPaint);

    // Dynamic field arcs
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.15),
      150,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.85),
      200,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
