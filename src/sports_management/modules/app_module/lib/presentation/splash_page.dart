import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:app_module/router/route_paths.dart';
import 'package:authentication_module/authentication_module.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const String _brandLogoAsset = 'assets/images/sport_energy_logo.png';

  late AnimationController _entranceController;
  late AnimationController _rotationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _statusText = 'ĐANG KHỞI TẠO HỆ THỐNG...';
  String _subStatusText = 'Đang tải cấu hình ứng dụng...';

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _entranceController.forward();
    _rotationController.repeat();
    _checkSessionAndNavigate();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  /// Kiểm tra session đã lưu và điều hướng tương ứng.
  Future<void> _checkSessionAndNavigate() async {
    // Các trạng thái kiểm tra hệ thống động
    final states = [
      ('ĐANG KHỞI TẠO HỆ THỐNG...', 'Đang tải cấu hình ứng dụng...'),
      ('ĐANG KẾT NỐI MÁY CHỦ...', 'Đang thiết lập kết nối an toàn...'),
      ('ĐANG XÁC THỰC TÀI KHOẢN...', 'Kiểm tra phiên đăng nhập...'),
      ('ĐANG ĐỒNG BỘ DỮ LIỆU...', 'Đồng bộ dữ liệu và cấu hình...'),
    ];

    // Chạy vòng lặp cập nhật text tạo hiệu ứng loading động
    for (var i = 0; i < states.length; i++) {
      if (!mounted) return;
      setState(() {
        _statusText = states[i].$1;
        _subStatusText = states[i].$2;
      });
      await Future.delayed(const Duration(milliseconds: 650));
    }

    if (!mounted) return;

    try {
      // Gọi SessionManager kiểm tra token thực tế (và tự động refresh bằng refreshToken nếu cần)
      final hasValidSession = await SessionManager.instance.checkSessionNow();

      if (!mounted) return;

      if (hasValidSession) {
        // Session hợp lệ → khôi phục trạng thái Authenticated trong AuthBloc và vào trang chính
        context.read<AuthBloc>().add(const AuthSessionValidated());
        context.goNamed(RoutePaths.homeName);
      } else {
        // Không có session hoặc session hết hạn → reset state của AuthBloc về Unauthenticated và đá ra đăng nhập
        context.read<AuthBloc>().add(const AuthSessionExpired());
        context.goNamed(RoutePaths.signInName);
      }
    } catch (error, stackTrace) {
      debugPrint('SplashPage session check error: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        context.read<AuthBloc>().add(const AuthSessionExpired());
        context.goNamed(RoutePaths.signInName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.surface,
                  Color.lerp(
                    theme.colorScheme.surface,
                    theme.colorScheme.primary,
                    isDark ? 0.15 : 0.07,
                  )!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // 2. Custom Painter for Sports Pitch & Speed Lines
          Positioned.fill(
            child: CustomPaint(painter: SportBackgroundPainter(theme)),
          ),
          // 3. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // 3D Spherical Rotating Soccer Ball with Levitation
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _entranceController,
                          _rotationController,
                        ]),
                        builder: (context, child) {
                          final levitation =
                              math.sin(
                                _rotationController.value * 2 * math.pi,
                              ) *
                              8; // Lơ lửng lên xuống 8 pixel

                          return Transform.translate(
                            offset: Offset(0, levitation),
                            child: Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(34),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha:
                                            (isDark ? 0.25 : 0.12) -
                                            (levitation / 150),
                                      ), // Bóng đổ tối màu chân thực
                                      blurRadius: 20 - (levitation / 2),
                                      spreadRadius: 3 - (levitation / 4),
                                      offset: Offset(
                                        0,
                                        30 - levitation,
                                      ), // Đẩy bóng xuống phía dưới chân quả cầu
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  _brandLogoAsset,
                                  semanticLabel: 'Sport Energy logo',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      // Text info
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              'SPORT ENERGY',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 3.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.3 : 0.1,
                                    ),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Năng lượng bứt phá • Kết nối đa vai trò',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Kiểm tra trạng thái hệ thống
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              _statusText,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _subStatusText,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Circular indicator
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
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

class SportBackgroundPainter extends CustomPainter {
  final ThemeData theme;

  SportBackgroundPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = theme.brightness == Brightness.dark;
    final paint = Paint()
      ..color = theme.colorScheme.onSurface.withValues(
        alpha: isDark ? 0.03 : 0.06,
      )
      ..style = PaintingStyle.fill;

    // Diagonal stripes
    final path1 = Path();
    path1.moveTo(0, size.height * 0.2);
    path1.lineTo(size.width, size.height * 0.4);
    path1.lineTo(size.width, size.height * 0.45);
    path1.lineTo(0, size.height * 0.25);
    path1.close();
    canvas.drawPath(path1, paint);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.6);
    path2.lineTo(size.width, size.height * 0.8);
    path2.lineTo(size.width, size.height * 0.85);
    path2.lineTo(0, size.height * 0.65);
    path2.close();
    canvas.drawPath(path2, paint);

    // Dynamic field line
    final fieldPaint = Paint()
      ..color = theme.colorScheme.onSurface.withValues(
        alpha: isDark ? 0.04 : 0.08,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw field elements (center circle and center line)
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.35,
      fieldPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      fieldPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SportBackgroundPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class ThreeDSoccerBallPainter extends CustomPainter {
  final double animationValue;
  final ThemeData theme;

  ThreeDSoccerBallPainter(this.animationValue, this.theme);

  // Cache the soccer ball patches after first generation
  static final List<SoccerPatch> _patches = _generateSoccerPatches();

  static List<SoccerPatch> _generateSoccerPatches() {
    final List<SoccerPatch> patches = [];
    final double phi = (1 + math.sqrt(5)) / 2;

    // 12 vertices of standard Icosahedron
    final List<Point3D> vertices = [
      Point3D(-1, phi, 0),
      Point3D(1, phi, 0),
      Point3D(-1, -phi, 0),
      Point3D(1, -phi, 0),
      Point3D(0, -1, phi),
      Point3D(0, 1, phi),
      Point3D(0, -1, -phi),
      Point3D(0, 1, -phi),
      Point3D(-phi, 0, -1),
      Point3D(phi, 0, -1),
      Point3D(-phi, 0, 1),
      Point3D(phi, 0, 1),
    ].map((p) => p.normalized()).toList();

    final int n = vertices.length;
    final List<List<bool>> isNeighbor = List.generate(
      n,
      (_) => List.filled(n, false),
    );

    // Determine neighbor connections based on icosahedron edge distance
    double minDistance = double.infinity;
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final dist = (vertices[i] - vertices[j]).length;
        if (dist < minDistance) {
          minDistance = dist;
        }
      }
    }

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (i == j) continue;
        final dist = (vertices[i] - vertices[j]).length;
        if (dist < minDistance * 1.1) {
          isNeighbor[i][j] = true;
        }
      }
    }

    // 1. Generate 12 Pentagon patches at the truncated vertices
    for (int i = 0; i < n; i++) {
      final center = vertices[i];
      final List<Point3D> neighborPts = [];
      for (int j = 0; j < n; j++) {
        if (isNeighbor[i][j]) {
          neighborPts.add(vertices[j]);
        }
      }

      // Truncate each of the 5 edges incident to vertex i by 1/3
      final List<Point3D> pentagonVertices = [];
      for (final neighbor in neighborPts) {
        final p = (center * 2.0 + neighbor) / 3.0;
        pentagonVertices.add(p.normalized());
      }

      final sortedVertices = sortPointsAroundCenter(center, pentagonVertices);

      patches.add(
        SoccerPatch(
          center: center,
          isPentagon: true,
          outlinePoints: sortedVertices,
        ),
      );
    }

    // 2. Generate 20 Hexagon patches at the centers of the icosahedron faces
    final List<List<int>> faces = [];
    for (int a = 0; a < n; a++) {
      for (int b = a + 1; b < n; b++) {
        if (!isNeighbor[a][b]) continue;
        for (int c = b + 1; c < n; c++) {
          if (isNeighbor[a][c] && isNeighbor[b][c]) {
            faces.add([a, b, c]);
          }
        }
      }
    }

    for (final face in faces) {
      final int a = face[0];
      final int b = face[1];
      final int c = face[2];

      final vA = vertices[a];
      final vB = vertices[b];
      final vC = vertices[c];

      final faceCenter = ((vA + vB + vC) / 3.0).normalized();

      // The 6 vertices of the hexagon are the 1/3 truncation points on the 3 edges
      final List<Point3D> hexagonVertices = [
        ((vA * 2.0 + vB) / 3.0).normalized(),
        ((vB * 2.0 + vA) / 3.0).normalized(),
        ((vB * 2.0 + vC) / 3.0).normalized(),
        ((vC * 2.0 + vB) / 3.0).normalized(),
        ((vC * 2.0 + vA) / 3.0).normalized(),
        ((vA * 2.0 + vC) / 3.0).normalized(),
      ];

      final sortedVertices = sortPointsAroundCenter(
        faceCenter,
        hexagonVertices,
      );

      patches.add(
        SoccerPatch(
          center: faceCenter,
          isPentagon: false,
          outlinePoints: sortedVertices,
        ),
      );
    }

    return patches;
  }

  static List<Point3D> sortPointsAroundCenter(
    Point3D center,
    List<Point3D> points,
  ) {
    final normal = center.normalized();
    Point3D u;
    if (normal.x.abs() < 0.9) {
      u = Point3D(-normal.y, normal.x, 0).normalized();
    } else {
      u = Point3D(0, -normal.z, normal.y).normalized();
    }
    final v = normal.cross(u).normalized();

    final sorted = List<Point3D>.from(points);
    sorted.sort((a, b) {
      final da = a - center;
      final db = b - center;
      final angleA = math.atan2(da.dot(v), da.dot(u));
      final angleB = math.atan2(db.dot(v), db.dot(u));
      return angleA.compareTo(angleB);
    });
    return sorted;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;

    final isDark = theme.brightness == Brightness.dark;

    final Color sphereStartColor;
    final Color sphereMidColor;
    final Color sphereEndColor;

    final Color pentagonStartColor;
    final Color pentagonEndColor;

    final Color hexagonStartColor;
    final Color hexagonEndColor;

    final Color seamStrokeColor;

    if (isDark) {
      // Dark theme ball colors (subtly tinted with primary color)
      sphereStartColor = Color.lerp(
        const Color(0xFF444444),
        theme.colorScheme.primary,
        0.12,
      )!;
      sphereMidColor = Color.lerp(
        const Color(0xFF1E1E1E),
        theme.colorScheme.primary,
        0.06,
      )!;
      sphereEndColor = const Color(0xFF000000);

      pentagonStartColor = Color.lerp(
        const Color(0xFF2D2D2D),
        theme.colorScheme.primary,
        0.2,
      )!;
      pentagonEndColor = Color.lerp(
        const Color(0xFF080808),
        theme.colorScheme.primary,
        0.08,
      )!;

      hexagonStartColor = Colors.white;
      hexagonEndColor = Color.lerp(
        const Color(0xFFCCCCCC),
        theme.colorScheme.primary,
        0.05,
      )!;

      seamStrokeColor = Color.lerp(
        const Color(0xFF151515),
        theme.colorScheme.primary,
        0.15,
      )!;
    } else {
      // Light theme ball colors (subtly tinted with primary/surface colors)
      sphereStartColor = Color.lerp(
        const Color(0xFF3A3A3A),
        theme.colorScheme.primary,
        0.08,
      )!;
      sphereMidColor = Color.lerp(
        const Color(0xFF1F1F1F),
        theme.colorScheme.primary,
        0.04,
      )!;
      sphereEndColor = const Color(0xFF050505);

      pentagonStartColor = Color.lerp(
        const Color(0xFF333333),
        theme.colorScheme.primary,
        0.25,
      )!;
      pentagonEndColor = Color.lerp(
        const Color(0xFF0C0C0C),
        theme.colorScheme.primary,
        0.12,
      )!;

      hexagonStartColor = Colors.white;
      hexagonEndColor = Color.lerp(
        const Color(0xFFDCDCDC),
        theme.colorScheme.primary,
        0.06,
      )!;

      seamStrokeColor = Color.lerp(
        const Color(0xFF1A1A1A),
        theme.colorScheme.primary,
        0.2,
      )!;
    }

    // 1. Draw background sphere representing the seams
    final Paint spherePaint = Paint()
      ..shader = RadialGradient(
        colors: [sphereStartColor, sphereMidColor, sphereEndColor],
        center: const Alignment(-0.3, -0.3),
        radius: 1.0,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, spherePaint);

    // 2. Setup 3D rotation angles
    // Y angle: spin from right to left (East to West)
    final double angleY = -animationValue * 2 * math.pi;
    // X angle: slight downward tilt
    const double angleX = 0.35;

    final double cosY = math.cos(angleY);
    final double sinY = math.sin(angleY);
    final double cosX = math.cos(angleX);
    final double sinX = math.sin(angleX);

    final Paint patchPaint = Paint()..style = PaintingStyle.fill;
    final Paint patchStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = seamStrokeColor
      ..strokeWidth = 1.8;

    // Filter and sort visible patches by depth (z coordinate after rotation)
    final List<MapEntry<SoccerPatch, double>> visiblePatches = [];
    for (final patch in _patches) {
      final cp = patch.center;
      // Rotate patch center to get rotated Z
      final double cz1 = cp.x * sinY + cp.z * cosY;
      final double cz2 = cp.y * sinX + cz1 * cosX;

      if (cz2 >= -0.2) {
        visiblePatches.add(MapEntry(patch, cz2));
      }
    }

    // Sort back-to-front (depth-buffer sort)
    visiblePatches.sort((a, b) => a.value.compareTo(b.value));

    for (final entry in visiblePatches) {
      final patch = entry.key;
      final cz2 = entry.value;

      final cp = patch.center;
      double cx1 = cp.x * cosY - cp.z * sinY;
      double cz1 = cp.x * sinY + cp.z * cosY;
      double cy1 = cp.y;
      double cx2 = cx1;
      double cy2 = cy1 * cosX - cz1 * sinX;

      final path = Path();
      for (int k = 0; k < patch.outlinePoints.length; k++) {
        final pt = patch.outlinePoints[k];
        double x1 = pt.x * cosY - pt.z * sinY;
        double z1 = pt.x * sinY + pt.z * cosY;
        double y1 = pt.y;

        double x2 = x1;
        double y2 = y1 * cosX - z1 * sinX;

        final double drawX = center.dx + x2 * radius;
        final double drawY = center.dy + y2 * radius;

        if (k == 0) {
          path.moveTo(drawX, drawY);
        } else {
          path.lineTo(drawX, drawY);
        }
      }
      path.close();

      // Dynamic light calculation based on rotated center dot-product with light direction
      final Point3D rotatedCenter = Point3D(cx2, cy2, cz2);
      final Point3D lightDir = Point3D(-0.4, -0.4, 0.82).normalized();
      final double dot = rotatedCenter.dot(lightDir);
      final double intensity = (dot + 1.0) / 2.0; // scale [0.0, 1.0]

      if (patch.isPentagon) {
        // Pentagons are shiny black
        patchPaint.shader =
            RadialGradient(
              colors: [
                Color.lerp(pentagonEndColor, pentagonStartColor, intensity)!,
                Color.lerp(
                  const Color(0xFF020202),
                  pentagonEndColor,
                  intensity,
                )!,
              ],
              center: const Alignment(-0.25, -0.25),
              radius: 0.85,
            ).createShader(
              Rect.fromCircle(
                center: Offset(
                  center.dx + cx2 * radius,
                  center.dy + cy2 * radius,
                ),
                radius: radius * 0.28,
              ),
            );
      } else {
        // Hexagons are shiny white
        patchPaint.shader =
            RadialGradient(
              colors: [
                Color.lerp(hexagonEndColor, hexagonStartColor, intensity)!,
                Color.lerp(
                  Color.lerp(
                    const Color(0xFF666666),
                    theme.colorScheme.primary,
                    0.1,
                  )!,
                  hexagonEndColor,
                  intensity,
                )!,
              ],
              center: const Alignment(-0.25, -0.25),
              radius: 0.85,
            ).createShader(
              Rect.fromCircle(
                center: Offset(
                  center.dx + cx2 * radius,
                  center.dy + cy2 * radius,
                ),
                radius: radius * 0.28,
              ),
            );
      }

      canvas.drawPath(path, patchPaint);
      canvas.drawPath(path, patchStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ThreeDSoccerBallPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.theme != theme;
  }
}

class SoccerPatch {
  final Point3D center;
  final bool isPentagon;
  final List<Point3D> outlinePoints;

  SoccerPatch({
    required this.center,
    required this.isPentagon,
    required this.outlinePoints,
  });
}

class Point3D {
  final double x;
  final double y;
  final double z;

  Point3D(this.x, this.y, this.z);

  Point3D operator +(Point3D other) =>
      Point3D(x + other.x, y + other.y, z + other.z);
  Point3D operator -(Point3D other) =>
      Point3D(x - other.x, y - other.y, z - other.z);
  Point3D operator *(double scale) => Point3D(x * scale, y * scale, z * scale);
  Point3D operator /(double scale) => Point3D(x / scale, y / scale, z / scale);

  double dot(Point3D other) => x * other.x + y * other.y + z * other.z;

  Point3D cross(Point3D other) {
    return Point3D(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  double get length => math.sqrt(x * x + y * y + z * z);

  Point3D normalized() {
    final len = length;
    if (len == 0) return Point3D(0, 0, 0);
    return this / len;
  }
}
