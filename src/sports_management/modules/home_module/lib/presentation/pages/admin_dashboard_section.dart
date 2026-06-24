import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:server_module/server_module.dart';
import 'package:user_management_module/user_management_module.dart';
import 'admin_booking_supervision_page.dart';
import 'admin_payment_supervision_page.dart';
import 'admin_moderation_page.dart';
import 'package:payment_module/payment_module.dart';
import 'package:booking_module/booking_module.dart';
import 'package:intl/intl.dart';
import 'package:notification_module/notification_module.dart';
import '../widgets/app_bottom_nav_bar.dart';

class AdminDashboardSection extends StatefulWidget {
  const AdminDashboardSection({super.key});

  @override
  State<AdminDashboardSection> createState() => _AdminDashboardSectionState();
}

class _AdminDashboardSectionState extends State<AdminDashboardSection> {
  static const String _brandLogoAsset = 'assets/images/sport_energy_logo.png';

  UserResult? _user;
  int _currentIndex = 0;
  List<FacilityEntity> _facilities = [];
  bool _isLoadingFacilities = false;
  String? _selectedFacilityId;
  String? _selectedFacilityName;

  int _totalUsersCount = 0;
  double _totalRevenue = 0.0;
  List<BookingDetailEntity> _recentBookings = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadFacilities();
    _loadStats();
  }

  Future<void> _loadUser() async {
    final result = await GetIt.I<GetLocalUserUseCase>()();
    if (!mounted) return;
    setState(() {
      _user = result.fold((_) => null, (user) => user);
    });
  }

  Future<void> _loadFacilities() async {
    if (!mounted) return;
    setState(() => _isLoadingFacilities = true);
    try {
      final useCase = GetIt.I<GetFacilitiesUseCase>();
      final response = await useCase();
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _facilities = response.data!;
          if (_facilities.isNotEmpty && _selectedFacilityId == null) {
            _selectedFacilityId = _facilities.first.id;
            _selectedFacilityName = _facilities.first.name;
          }
        });
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoadingFacilities = false);
  }

  Future<void> _loadStats() async {
    try {
      final usersUseCase = GetIt.I<GetUsersUseCase>();
      final usersRes = await usersUseCase();
      if (usersRes.success && usersRes.data != null) {
        _totalUsersCount = usersRes.data!.length;
      }
    } catch (_) {}

    try {
      final paymentsUseCase = GetIt.I<GetPaymentsUseCase>();
      final paymentsRes = await paymentsUseCase();
      if (paymentsRes.success && paymentsRes.data != null) {
        _totalRevenue = paymentsRes.data!
            .where((p) => p.status?.toUpperCase() == 'SUCCESS')
            .fold(0.0, (sum, p) => sum + (p.amount ?? 0.0));
      }
    } catch (_) {}

    try {
      final bookingsUseCase = GetIt.I<GetBookingHistoryUseCase>();
      final bookingsRes = await bookingsUseCase();
      if (bookingsRes.success && bookingsRes.data != null) {
        final sorted = List<BookingDetailEntity>.from(bookingsRes.data!);
        sorted.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.now();
          final dateB = b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA); // descending
        });
        _recentBookings = sorted.take(3).toList();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {});
    }
  }

  String _formatRevenue(double amount) {
    if (amount >= 1000000) {
      final millions = amount / 1000000;
      return '${millions.toStringAsFixed(1)}M đ';
    }
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatTimeAgo(BuildContext context, DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).toStringAsFixed(0)} ${context.tr(vi: 'năm trước', en: 'years ago')}';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).toStringAsFixed(0)} ${context.tr(vi: 'tháng trước', en: 'months ago')}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${context.tr(vi: 'ngày trước', en: 'days ago')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${context.tr(vi: 'giờ trước', en: 'hours ago')}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${context.tr(vi: 'phút trước', en: 'minutes ago')}';
    } else {
      return context.tr(vi: 'Vừa xong', en: 'Just now');
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(vi: 'Đăng xuất', en: 'Logout')),
        content: Text(
          context.tr(
            vi: 'Bạn có chắc chắn muốn đăng xuất?',
            en: 'Are you sure you want to log out?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr(vi: 'Hủy', en: 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5600),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr(vi: 'Đăng xuất', en: 'Logout')),
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                _brandLogoAsset,
                width: 30,
                height: 30,
                semanticLabel: 'Sport Energy logo',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SPORT ENERGY • ADMIN',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                fontSize: 14,
                letterSpacing: 1.5,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              context.tr(vi: 'Quản trị viên', en: 'Administrator'),
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 2) {
            _loadFacilities();
          }
        },
        items: [
          AppNavItem(
            icon: Icons.analytics_outlined,
            activeIcon: Icons.analytics,
            label: context.tr(vi: 'Tổng quan', en: 'Overview'),
          ),
          AppNavItem(
            icon: Icons.business_outlined,
            activeIcon: Icons.business,
            label: context.tr(vi: 'Cơ sở', en: 'Facilities'),
          ),
          AppNavItem(
            icon: Icons.stadium_outlined,
            activeIcon: Icons.stadium,
            label: context.tr(vi: 'Sân đấu', en: 'Courts'),
          ),
          AppNavItem(
            icon: Icons.sports_soccer_outlined,
            activeIcon: Icons.sports_soccer,
            label: context.tr(vi: 'Môn thể thao', en: 'Sports'),
          ),
          AppNavItem(
            icon: Icons.people_alt_outlined,
            activeIcon: Icons.people_alt,
            label: context.tr(vi: 'Thành viên', en: 'Members'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return FacilityManagementPage(
          isEmbedded: true,
          onFacilityTap: (facility) {
            setState(() {
              _selectedFacilityId = facility.id;
              _selectedFacilityName = facility.name;
              _currentIndex = 2; // Chuyển sang Tab Sân đấu
            });
          },
        );
      case 2:
        return _buildCourtsTab();
      case 3:
        return const SportManagementPage(isEmbedded: true);
      case 4:
        return const UserManagementPage(isEmbedded: true);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- TAB 0: TỔNG QUAN ---
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadFacilities();
        await _loadStats();
      },
      color: const Color(0xFFFF5600),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr(vi: 'Chào', en: 'Hello')}, ${_user?.name ?? 'Admin'}! 👋',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          vi: 'Chào mừng tới trung tâm quản trị toàn hệ thống.',
                          en: 'Welcome to the system administration center.',
                        ),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Performance Statistics Row
            Text(
              context.tr(vi: 'THỐNG KÊ HỆ THỐNG', en: 'SYSTEM STATISTICS'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSystemStatCard(
                  context.tr(vi: 'Tổng người dùng', en: 'Total Users'),
                  _totalUsersCount.toString(),
                  Icons.people_outline,
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildSystemStatCard(
                  context.tr(vi: 'Doanh thu hệ thống', en: 'Total Revenue'),
                  _formatRevenue(_totalRevenue),
                  Icons.auto_graph,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Management Grid Section
            Text(
              context.tr(vi: 'DANH MỤC QUẢN LÝ', en: 'MANAGEMENT DIRECTORY'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _buildAdminActionCard(
                  context.tr(vi: 'Quản lý Users', en: 'Manage Users'),
                  context.tr(
                    vi: 'Phân quyền, cấp phép tài khoản',
                    en: 'Permissions & accounts setup',
                  ),
                  Icons.group_outlined,
                  Colors.indigo,
                  () => setState(
                    () => _currentIndex = 4,
                  ), // Chuyển trực tiếp sang Tab 4
                ),
                _buildAdminActionCard(
                  context.tr(vi: 'Quản lý Cơ sở', en: 'Manage Facilities'),
                  context.tr(
                    vi: 'Quản lý các cơ sở sân đấu',
                    en: 'Sports facilities setup',
                  ),
                  Icons.business,
                  Colors.orange,
                  () => setState(
                    () => _currentIndex = 1,
                  ), // Chuyển trực tiếp sang Tab 1
                ),
                _buildAdminActionCard(
                  context.tr(vi: 'Quản lý Sân đấu', en: 'Manage Courts'),
                  context.tr(
                    vi: 'Danh sách sân đấu của các cơ sở',
                    en: 'Courts list by facilities',
                  ),
                  Icons.stadium_outlined,
                  Colors.blue,
                  () => setState(
                    () => _currentIndex = 2,
                  ), // Chuyển trực tiếp sang Tab 2
                ),
                _buildAdminActionCard(
                  context.tr(vi: 'Môn thể thao', en: 'Sports'),
                  context.tr(
                    vi: 'Danh mục môn thể thao hệ thống',
                    en: 'System sports categories',
                  ),
                  Icons.sports_soccer_outlined,
                  Colors.red,
                  () => setState(
                    () => _currentIndex = 3,
                  ), // Chuyển trực tiếp sang Tab 3
                ),
              ],
            ),
            const SizedBox(height: 28),

            Text(
              context.tr(vi: 'CÔNG CỤ QUẢN TRỊ', en: 'ADMIN TOOLS'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 110,
                    child: _buildAdminActionCard(
                      context.tr(
                        vi: 'Đặt lịch hệ thống',
                        en: 'Booking Supervision',
                      ),
                      context.tr(
                        vi: 'Giám sát đặt sân',
                        en: 'Monitor court bookings',
                      ),
                      Icons.calendar_today_outlined,
                      Colors.teal,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminBookingSupervisionPage(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 110,
                    child: _buildAdminActionCard(
                      context.tr(
                        vi: 'Thu chi & Giao dịch',
                        en: 'Transactions & Payments',
                      ),
                      context.tr(
                        vi: 'Duyệt giao dịch',
                        en: 'Approve transactions',
                      ),
                      Icons.receipt_long_outlined,
                      Colors.purple,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminPaymentSupervisionPage(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 110,
              child: _buildAdminActionCard(
                context.tr(vi: 'Kiểm duyệt nội dung', en: 'Content Moderation'),
                context.tr(
                  vi: 'Quản lý và xóa các đánh giá của khách hàng',
                  en: 'Manage and delete customer reviews',
                ),
                Icons.rate_review_outlined,
                Colors.amber.shade800,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminModerationPage(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Log / Activity List
            Text(
              context.tr(vi: 'HOẠT ĐỘNG GẦN ĐÂY', en: 'RECENT ACTIVITY'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            if (_recentBookings.isEmpty)
              _buildLogItem(
                context.tr(vi: 'Hệ thống', en: 'System'),
                context.tr(
                  vi: 'Không có hoạt động đặt sân gần đây.',
                  en: 'No recent booking activities.',
                ),
                context.tr(vi: 'Bây giờ', en: 'Now'),
              )
            else
              ..._recentBookings.map((booking) {
                final user =
                    booking.user?.name ??
                    context.tr(vi: 'Khách hàng', en: 'Customer');
                final court =
                    booking.courtName ??
                    context.tr(vi: 'Sân thi đấu', en: 'Court');
                final status = booking.status?.toUpperCase() ?? 'PENDING';
                String action = context.tr(
                  vi: 'đã đặt sân $court.',
                  en: 'booked court $court.',
                );
                if (status == 'CANCELLED') {
                  action = context.tr(
                    vi: 'đã hủy lịch đặt sân $court.',
                    en: 'cancelled booking for court $court.',
                  );
                } else if (status == 'COMPLETED') {
                  action = context.tr(
                    vi: 'đã hoàn thành trận đấu tại sân $court.',
                    en: 'completed match on court $court.',
                  );
                } else if (status == 'CONFIRMED') {
                  action = context.tr(
                    vi: 'đã xác nhận lịch đặt sân $court.',
                    en: 'confirmed booking for court $court.',
                  );
                }

                final timeStr = booking.createdAt != null
                    ? _formatTimeAgo(context, booking.createdAt!)
                    : context.tr(vi: 'Gần đây', en: 'Recently');

                return _buildLogItem(user, action, timeStr);
              }),

            const Divider(height: 48),

            // Logout Button
            Card(
              elevation: 0,
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade100),
              ),
              child: InkWell(
                onTap: _handleLogout,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 20.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        context.tr(
                          vi: 'Đăng xuất quản trị viên',
                          en: 'Log out administrator',
                        ),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: SÂN ĐẤU ---
  Widget _buildCourtsTab() {
    if (_isLoadingFacilities) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5600)),
      );
    }

    if (_facilities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              context.tr(
                vi: 'Chưa có cơ sở nào. Vui lòng tạo cơ sở trước.',
                en: 'No facilities found. Please create a facility first.',
              ),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Đảm bảo có một cơ sở được chọn hợp lệ từ danh sách hiện có
    if (_selectedFacilityId == null ||
        !_facilities.any((f) => f.id == _selectedFacilityId)) {
      _selectedFacilityId = _facilities.first.id;
      _selectedFacilityName = _facilities.first.name;
    }

    return Column(
      children: [
        // Dropdown chọn cơ sở
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFacilityId,
                isExpanded: true,
                hint: Text(
                  context.tr(
                    vi: 'Chọn cơ sở để quản lý sân',
                    en: 'Select facility to manage courts',
                  ),
                ),
                items: _facilities.map((fac) {
                  return DropdownMenuItem<String>(
                    value: fac.id,
                    child: Text(
                      fac.name ??
                          context.tr(
                            vi: 'Cơ sở thể thao',
                            en: 'Sports Facility',
                          ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final matched = _facilities.where((f) => f.id == val);
                    if (matched.isEmpty) return;
                    final fac = matched.first;
                    setState(() {
                      _selectedFacilityId = val;
                      _selectedFacilityName = fac.name;
                    });
                  }
                },
              ),
            ),
          ),
        ),
        // Nhúng CourtManagementPage
        Expanded(
          child: CourtManagementPage(
            key: ValueKey(_selectedFacilityId),
            facilityId: _selectedFacilityId!,
            facilityName: _selectedFacilityName,
            isEmbedded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminActionCard(
    String title,
    String desc,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(String user, String action, String time) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12.5,
                      ),
                      children: [
                        TextSpan(
                          text: '$user: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: action),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
