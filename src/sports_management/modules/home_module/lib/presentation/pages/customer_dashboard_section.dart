// ignore_for_file: unused_field, unused_element, unused_local_variable
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:booking_module/booking_module.dart';
import 'package:payment_module/payment_module.dart';
import 'package:server_module/server_module.dart';
import '../cubit/theme_cubit.dart';
import 'package:notification_module/notification_module.dart';
import 'account/widgets/profile_edit_sheet.dart';
import 'account/widgets/customer_support_sheet.dart';
import 'account/widgets/change_password_sheet.dart';
import '../widgets/app_bottom_nav_bar.dart';

class CustomerDashboardSection extends StatefulWidget {
  final String? initialTab;

  const CustomerDashboardSection({super.key, this.initialTab});

  @override
  State<CustomerDashboardSection> createState() =>
      _CustomerDashboardSectionState();
}

class _CustomerDashboardSectionState extends State<CustomerDashboardSection> {
  static const String _brandLogoAsset = 'assets/images/sport_energy_logo.png';

  int _currentIndex = 0;
  UserResult? _user;
  final bool _isDarkMode = false;

  List<FacilityEntity> _facilities = [];
  List<SportEntity> _sports = [];
  List<CourtEntity> _allCourts = [];
  bool _isLoadingFacilities = false;
  bool _isLoadingSports = false;
  String? _selectedSportId;

  @override
  void initState() {
    super.initState();
    _currentIndex = _tabIndexFromName(widget.initialTab);
    _loadUser();
    _loadSports();
    _loadFacilities();
    _loadAllCourts();
  }

  int _tabIndexFromName(String? tabName) {
    switch (tabName) {
      case 'payment':
        return 1;
      case 'history':
        return 2;
      case 'account':
        return 3;
      case 'booking':
      default:
        return 0;
    }
  }

  Future<void> _loadUser() async {
    final result = await GetIt.I<GetLocalUserUseCase>()();
    if (!mounted) return;
    setState(() {
      _user = result.fold((_) => null, (user) => user);
    });
  }

  Future<void> _loadSports() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSports = true;
    });
    try {
      final useCase = GetIt.I<GetSportsUseCase>();
      final response = await useCase();
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _sports = response.data!;
        });
      }
    } catch (e) {
      debugPrint('Error loading sports: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSports = false;
        });
      }
    }
  }

  Future<void> _loadFacilities() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFacilities = true;
    });
    try {
      final useCase = GetIt.I<GetFacilitiesUseCase>();
      final response = await useCase();
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _facilities = response.data!;
        });
      }
    } catch (e) {
      debugPrint('Error loading facilities: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFacilities = false;
        });
      }
    }
  }

  Future<void> _loadAllCourts() async {
    try {
      final useCase = GetIt.I<GetCourtsUseCase>();
      final response = await useCase();
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _allCourts = response.data!;
        });
      }
    } catch (e) {
      debugPrint('Error loading all courts: $e');
    }
  }

  List<FacilityEntity> get _filteredFacilities {
    if (_selectedSportId == null) {
      return _facilities;
    }
    final facilityIdsWithSport = _allCourts
        .where((court) => court.sportId == _selectedSportId)
        .map((court) => court.facilityId)
        .toSet();
    return _facilities
        .where((fac) => facilityIdsWithSport.contains(fac.id))
        .toList();
  }

  IconData _getSportIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('bóng đá') ||
        lowerName.contains('football') ||
        lowerName.contains('soccer')) {
      return Icons.sports_soccer;
    } else if (lowerName.contains('cầu lông') ||
        lowerName.contains('badminton')) {
      return Icons.sports_tennis;
    } else if (lowerName.contains('tennis')) {
      return Icons.sports_baseball;
    } else if (lowerName.contains('bóng rổ') ||
        lowerName.contains('basketball')) {
      return Icons.sports_basketball;
    } else if (lowerName.contains('bóng chuyền') ||
        lowerName.contains('volleyball')) {
      return Icons.sports_volleyball;
    }
    return Icons.sports;
  }

  Color _getSportColor(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('bóng đá') ||
        lowerName.contains('football') ||
        lowerName.contains('soccer')) {
      return const Color(0xFFFF5600);
    } else if (lowerName.contains('cầu lông') ||
        lowerName.contains('badminton')) {
      return Colors.teal;
    } else if (lowerName.contains('tennis')) {
      return Colors.blue;
    } else if (lowerName.contains('bóng rổ') ||
        lowerName.contains('basketball')) {
      return Colors.orange;
    }
    return Colors.purple;
  }

  String _getFacilityPriceRange(BuildContext context, String facilityId) {
    final facilityCourts = _allCourts
        .where((c) => c.facilityId == facilityId)
        .toList();
    if (facilityCourts.isEmpty) {
      return context.tr(vi: 'Chưa cập nhật giá', en: 'Price not updated');
    }

    final prices = facilityCourts
        .map((c) => c is BookingCourtModel ? c.pricePerHour : null)
        .whereType<int>()
        .toList();

    if (prices.isEmpty) {
      return context.tr(vi: 'Chưa cập nhật giá', en: 'Price not updated');
    }

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final formattedPrice = minPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return context.tr(
      vi: '$formattedPrice đ/giờ',
      en: '$formattedPrice VND/hour',
    );
  }

  double _getFacilityRating(String facilityId) {
    return 4.5 + (facilityId.hashCode.abs() % 5) * 0.1;
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(vi: 'Đăng xuất', en: 'Logout')),
        content: Text(
          context.tr(
            vi: 'Bạn có chắc chắn muốn đăng xuất khỏi Sport Energy?',
            en: 'Are you sure you want to log out of Sport Energy?',
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
      appBar: (_currentIndex == 1 || _currentIndex == 2)
          ? null
          : AppBar(
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
                    'SPORT ENERGY',
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
                BlocBuilder<NotificationCubit, NotificationState>(
                  builder: (context, state) {
                    final unreadCount = state.unreadCount;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none_outlined),
                          onPressed: () {
                            NotificationHistoryPanel.show(context);
                          },
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5600),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: _buildBody(),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          AppNavItem(
            icon: Icons.sports_soccer_outlined,
            activeIcon: Icons.sports_soccer,
            label: context.tr(vi: 'Đặt sân', en: 'Book Court'),
          ),
          AppNavItem(
            icon: Icons.payment_outlined,
            activeIcon: Icons.payment,
            label: context.tr(vi: 'Thanh toán', en: 'Payment'),
          ),
          AppNavItem(
            icon: Icons.history_outlined,
            activeIcon: Icons.history,
            label: context.tr(vi: 'Lịch sử', en: 'History'),
          ),
          AppNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: context.tr(vi: 'Tài khoản', en: 'Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildBookingTab();
      case 1:
        return _buildPaymentTab();
      case 2:
        return _buildHistoryTab();
      case 3:
        return _buildAccountTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- TAB 1: ĐẶT SÂN ---
  Widget _buildBookingTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5600), Color(0xFFcc3300)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr(vi: 'Chào', en: 'Hello')}, ${_user?.name ?? context.tr(vi: 'Người chơi', en: 'Player')} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    vi: 'Sẵn sàng cho các trận đấu kịch tính hôm nay?',
                    en: 'Ready for exciting matches today?',
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Ghép trận banner
          GestureDetector(
            onTap: () => context.push('/matching'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.teal, Color(0xFF00BFA5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people,
                      color: Colors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            vi: 'Giao Lưu & Ghép Trận ⚡',
                            en: 'Matchmaking & Social ⚡',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(
                            vi: 'Tìm đối thủ, ghép nhóm chơi cùng và chia sẻ tiền sân!',
                            en: 'Find opponents, join groups, and share court costs!',
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const CustomerBookingCatalogSection(role: 'customer'),
        ],
      ),
    );
  }

  Widget _buildSportCategoryCard(
    String? id,
    String title,
    IconData icon,
    Color color,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final activeColor = isSelected ? color : Colors.grey.shade400;
    final cardBgColor = isSelected
        ? color.withValues(alpha: 0.12)
        : theme.cardColor;

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8.0),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: cardBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? color
                : theme.dividerColor.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedSportId = id;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 8.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: activeColor, size: 24),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? color
                        : theme.textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFacilityCard(FacilityEntity facility) {
    final theme = Theme.of(context);
    final rating = _getFacilityRating(facility.id);
    final priceStr = _getFacilityPriceRange(context, facility.id);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _showCourtsBottomSheet(facility),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      facility.name ??
                          context.tr(
                            vi: 'Cơ sở thể thao',
                            en: 'Sports Facility',
                          ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      facility.address ??
                          context.tr(
                            vi: 'Chưa cập nhật địa chỉ',
                            en: 'Address not updated',
                          ),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            vi: 'Giá thuê chỉ từ',
                            en: 'Hourly rate from',
                          ),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          priceStr,
                          style: const TextStyle(
                            color: Color(0xFFFF5600),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showCourtsBottomSheet(facility),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.tr(vi: 'Xem sân đấu', en: 'View Courts'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourtsBottomSheet(FacilityEntity facility) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _FacilityCourtsBottomSheet(
          facility: facility,
          selectedSportId: _selectedSportId,
          sports: _sports,
        );
      },
    );
  }

  // --- TAB 2: THANH TOÁN ---
  Widget _buildPaymentTab() {
    return const PaymentTabWidget();
  }

  // --- TAB 3: LỊCH SỬ ---
  Widget _buildHistoryTab() {
    return const BookingHistoryPage();
  }

  // --- TAB 4: TÀI KHOẢN ---
  Widget _buildAccountTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // User Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(
                      0xFFFF5600,
                    ).withValues(alpha: 0.1),
                    backgroundImage:
                        _user?.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
                        ? NetworkImage(_user!.avatarUrl!)
                        : null,
                    child: _user?.avatarUrl == null || _user!.avatarUrl!.isEmpty
                        ? Text(
                            _user?.name != null && _user!.name!.isNotEmpty
                                ? _user!.name!.substring(0, 1).toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF5600),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user?.name ??
                              context.tr(vi: 'Khách hàng', en: 'Customer'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user?.email ?? 'you@example.com',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.05,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.tr(
                              vi: 'Vai trò: Khách hàng',
                              en: 'Role: Customer',
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Menu List
          _buildMenuItem(
            Icons.person_outline,
            context.tr(vi: 'Thông tin cá nhân', en: 'Personal Info'),
            onTap: () {
              ProfileEditSheet.show(
                context,
                userId: _user?.userId ?? '',
                onProfileUpdated: _loadUser,
              );
            },
          ),
          _buildMenuItem(
            Icons.settings_outlined,
            context.tr(vi: 'Cài đặt hệ thống', en: 'System Settings'),
            onTap: () {
              context.push('/settings');
            },
          ),
          _buildMenuItem(
            Icons.lock_outline_rounded,
            context.tr(vi: 'Đổi mật khẩu', en: 'Change password'),
            onTap: () {
              ChangePasswordSheet.show(context);
            },
          ),
          _buildMenuItem(
            Icons.help_outline,
            context.tr(vi: 'Hỗ trợ khách hàng', en: 'Customer Support'),
            onTap: () {
              CustomerSupportSheet.show(context);
            },
          ),
          const Divider(height: 32),

          // Logout Button
          Card(
            elevation: 0,
            color: theme.brightness == Brightness.dark
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.brightness == Brightness.dark
                    ? Colors.red.withValues(alpha: 0.25)
                    : Colors.red.shade100,
              ),
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
                      context.tr(vi: 'Đăng xuất tài khoản', en: 'Log out'),
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
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    String? trailingText,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        icon,
        color: theme.colorScheme.primary.withValues(alpha: 0.7),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      trailing: trailingText != null
          ? Text(
              trailingText,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            )
          : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchMenuItem(IconData icon, String title) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        icon,
        color: theme.colorScheme.primary.withValues(alpha: 0.7),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      trailing: Switch(
        value: context.watch<ThemeCubit>().state == ThemeMode.dark,
        activeTrackColor: const Color(0xFFFF5600),
        onChanged: (val) {
          context.read<ThemeCubit>().toggleTheme();
        },
      ),
    );
  }
}

class _FacilityCourtsBottomSheet extends StatefulWidget {
  final FacilityEntity facility;
  final String? selectedSportId;
  final List<SportEntity> sports;

  const _FacilityCourtsBottomSheet({
    required this.facility,
    required this.selectedSportId,
    required this.sports,
  });

  @override
  State<_FacilityCourtsBottomSheet> createState() =>
      _FacilityCourtsBottomSheetState();
}

class _FacilityCourtsBottomSheetState
    extends State<_FacilityCourtsBottomSheet> {
  String? _currentSportId;
  List<CourtEntity> _courts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentSportId = widget.selectedSportId;
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final useCase = GetIt.I<GetCourtsUseCase>();
      final response = await useCase(
        facilityId: widget.facility.id,
        sportId: _currentSportId,
      );
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _courts = response.data!;
        });
      }
    } catch (e) {
      debugPrint('Error loading courts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: mediaQuery.viewInsets.bottom + 16,
      ),
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.75),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.facility.name ??
                          context.tr(
                            vi: 'Chi tiết cơ sở',
                            en: 'Facility Details',
                          ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.facility.address ?? '',
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
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            context.tr(vi: 'MÔN THỂ THAO', en: 'SPORTS'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSportChip(null, context.tr(vi: 'Tất cả', en: 'All')),
                ...widget.sports.map(
                  (sport) => _buildSportChip(sport.id, sport.name ?? ''),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(vi: 'DANH SÁCH SÂN ĐẤU', en: 'COURTS LIST'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5600)),
                  )
                : _courts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_soccer_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr(
                            vi: 'Không có sân nào phù hợp với bộ lọc này',
                            en: 'No courts matching this filter',
                          ),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _courts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final court = _courts[index];
                      return _buildCourtRow(court);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportChip(String? id, String label) {
    final isSelected = _currentSportId == id;
    final color = const Color(0xFFFF5600);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: color.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: isSelected ? color : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        checkmarkColor: color,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _currentSportId = id;
            });
            _loadCourts();
          }
        },
      ),
    );
  }

  Widget _buildCourtRow(CourtEntity court) {
    final theme = Theme.of(context);
    final statusColor = court.status == 'ACTIVE' ? Colors.green : Colors.red;
    final statusText = court.status == 'ACTIVE'
        ? context.tr(vi: 'Sẵn sàng', en: 'Available')
        : context.tr(vi: 'Bảo trì', en: 'Maintenance');

    int? price;
    String? code;
    if (court is BookingCourtModel) {
      price = court.pricePerHour;
      code = court.code;
    }

    final priceStr = price != null
        ? context.tr(
            vi: '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ/giờ',
            en: '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND/hour',
          )
        : context.tr(vi: 'Chưa cập nhật giá', en: 'Price not updated');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                court.status == 'ACTIVE'
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    court.name ?? context.tr(vi: 'Sân đấu', en: 'Court'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (code != null && code.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${context.tr(vi: 'Mã sân', en: 'Court code')}: $code',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    priceStr,
                    style: TextStyle(
                      color: const Color(0xFFFF5600),
                      fontSize: 13,
                      fontWeight: price != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (court.status == 'ACTIVE')
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/court/${court.id}/booking', extra: court);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  context.tr(vi: 'Đặt ngay', en: 'Book Now'),
                  style: const TextStyle(fontSize: 12),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
