// ignore_for_file: unused_field, unused_element, unused_local_variable, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:app_module/app_module.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:server_module/server_module.dart';
import 'package:booking_module/booking_module.dart';
import 'package:payment_module/payment_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:facility_module/presentation/widgets/crud_popup.dart';
import 'package:intl/intl.dart';
import '../cubit/staff_booking/staff_booking_cubit.dart';
import '../cubit/staff_booking/staff_booking_state.dart';
import '../cubit/staff_payment/staff_payment_cubit.dart';
import '../cubit/staff_payment/staff_payment_state.dart';
import '../cubit/theme_cubit.dart';
import 'package:notification_module/notification_module.dart';
import 'dart:async';
import 'account/widgets/change_password_sheet.dart';
import 'account/widgets/customer_support_sheet.dart';
import '../widgets/app_bottom_nav_bar.dart';

class StaffDashboardSection extends StatefulWidget {
  const StaffDashboardSection({super.key});

  @override
  State<StaffDashboardSection> createState() => _StaffDashboardSectionState();
}

class _StaffDashboardSectionState extends State<StaffDashboardSection> {
  static const String _brandLogoAsset = 'assets/images/sport_energy_logo.png';
  static const String _allFilterValue = '__all__';

  int _currentIndex = 0;
  UserResult? _user;
  final bool _isDarkMode = false;

  late StaffBookingCubit _bookingCubit;
  late StaffPaymentCubit _paymentCubit;
  List<BookingDetailEntity> _bookings = [];
  List<FacilityEntity> _facilities = [];
  String? _selectedFacilityId;
  bool _isLoading = false;

  // Search, filter and prefetch cache
  final _bookingSearchController = TextEditingController();
  String _bookingSearchQuery = '';
  String? _selectedStatusFilter;
  DateTime? _bookingDateFrom;
  DateTime? _bookingDateTo;
  String? _selectedCourtFilterId;
  String? _selectedSportFilterName;
  final _bookingScrollController = ScrollController();
  Map<String, UserEntity> _usersCache = {};
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _bookingSearchController.addListener(() {
      setState(() {
        _bookingSearchQuery = _bookingSearchController.text;
      });
    });
    _bookingCubit = StaffBookingCubit(
      GetIt.I(),
      GetIt.I(),
      GetIt.I(),
      GetIt.I(),
    );
    _paymentCubit = StaffPaymentCubit(
      GetIt.I(),
      GetIt.I(),
      GetIt.I(),
      GetIt.I(),
      GetIt.I(),
    );
    _bookingCubit.loadBookings();
    _subscribeEvents();
  }

  void _subscribeEvents() {
    try {
      _eventSubscription = GetIt.I<AppNotificationEventBus>().stream.listen((
        event,
      ) {
        if (mounted) {
          _bookingCubit.loadBookings(facilityId: _selectedFacilityId);
          _paymentCubit.loadPayments(facilityId: _selectedFacilityId);
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to EventBus in StaffDashboardSection: $e');
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _bookingSearchController.dispose();
    _bookingScrollController.dispose();
    _bookingCubit.close();
    _paymentCubit.close();
    super.dispose();
  }

  void _showNewBookingDialog(BuildContext context) {
    final formKey = GlobalKey<_NewBookingDialogState>();
    final facilityCustomers = <String, UserEntity>{};
    for (final booking in _bookings) {
      final userId = booking.userId;
      final bookingUser = booking.user;
      if (userId != null && bookingUser != null) {
        facilityCustomers[userId] = _usersCache[userId] ?? bookingUser;
      }
    }
    CrudPopup.showForm<void>(
      context,
      title: context.tr(
        vi: 'Đặt lịch & Thu tiền tại quầy',
        en: 'Over-the-Counter Booking',
      ),
      subtitle: context.tr(
        vi: 'Chọn sân, khung giờ và hình thức thanh toán',
        en: 'Choose a court, time slot and payment method',
      ),
      submitLabel: context.tr(vi: 'Tạo booking', en: 'Create Booking'),
      icon: Icons.point_of_sale_rounded,
      barrierDismissible: false,
      builder: (sheetContext, setSheetState) => _NewBookingDialog(
        key: formKey,
        selectedFacilityId: _selectedFacilityId,
        usersCache: facilityCustomers,
        onStateChanged: () => setSheetState(() {}),
        onBookingCreated: () {
          _bookingCubit.loadBookings(facilityId: _selectedFacilityId);
        },
      ),
      canSubmit: () => formKey.currentState?.canSubmit ?? false,
      isSubmitting: () => formKey.currentState?.isSubmitting ?? false,
      onSubmit: () => formKey.currentState?.submit(),
    );
  }

  void _showRescheduleDialog(
    BuildContext context,
    BookingDetailEntity booking,
  ) {
    showDialog(
      context: context,
      builder: (context) => _RescheduleDialog(
        booking: booking,
        onRescheduled: () {
          _bookingCubit.loadBookings(facilityId: _selectedFacilityId);
        },
      ),
    );
  }

  Future<void> _loadUser() async {
    final result = await GetIt.I<GetLocalUserUseCase>()();
    if (!mounted) return;
    setState(() {
      _user = result.fold((_) => null, (user) => user);
    });
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
              'SPORT ENERGY • STAFF',
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
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              context.tr(vi: 'Nhân viên', en: 'Staff'),
              style: TextStyle(
                color: Colors.orange.shade900,
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
        },
        items: [
          AppNavItem(
            icon: Icons.analytics_outlined,
            activeIcon: Icons.analytics,
            label: context.tr(vi: 'Tổng quan', en: 'Overview'),
          ),
          AppNavItem(
            icon: Icons.construction_outlined,
            activeIcon: Icons.construction,
            label: context.tr(vi: 'Vận hành', en: 'Operations'),
          ),
          AppNavItem(
            icon: Icons.book_online_outlined,
            activeIcon: Icons.book_online,
            label: context.tr(vi: 'Đặt lịch', en: 'Schedule'),
          ),
          AppNavItem(
            icon: Icons.point_of_sale_outlined,
            activeIcon: Icons.point_of_sale,
            label: context.tr(vi: 'Thu ngân', en: 'Cashier'),
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
    return BlocConsumer<StaffBookingCubit, StaffBookingState>(
      bloc: _bookingCubit,
      listener: (context, state) {
        if (state is StaffBookingLoaded) {
          final facilityUsers = <String, UserEntity>{};
          for (final booking in state.bookings) {
            final userId = booking.userId;
            final user = booking.user;
            if (userId != null && user != null) {
              facilityUsers[userId] = user;
            }
          }
          setState(() {
            _bookings = state.bookings;
            _facilities = state.facilities;
            _selectedFacilityId = state.selectedFacilityId;
            _usersCache = facilityUsers;
            final courtFilterStillExists =
                _selectedCourtFilterId == null ||
                state.bookings.any(
                  (booking) =>
                      (booking.courtId ?? booking.court?.id) ==
                      _selectedCourtFilterId,
                );
            if (!courtFilterStillExists) {
              _selectedCourtFilterId = null;
            }
            final sportFilterStillExists =
                _selectedSportFilterName == null ||
                state.bookings.any(
                  (booking) =>
                      _normalizeFilterText(booking.sportName) ==
                      _normalizeFilterText(_selectedSportFilterName),
                );
            if (!sportFilterStillExists) {
              _selectedSportFilterName = null;
            }
            _isLoading = false;
          });
          _paymentCubit.loadPayments(facilityId: state.selectedFacilityId);
        } else if (state is StaffBookingLoading) {
          setState(() {
            _isLoading = true;
          });
        } else if (state is StaffBookingActionSuccess) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is StaffBookingError) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        if (_isLoading && _bookings.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF5600)),
          );
        }

        return Stack(
          children: [
            _buildTabContent(),
            if (_isLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  color: Color(0xFFFF5600),
                  backgroundColor: Colors.transparent,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTabContent() {
    switch (_currentIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildOperationTab();
      case 2:
        return _buildBookingTab();
      case 3:
        return _buildPaymentTab();
      case 4:
        return _buildAccountTab();
      default:
        return const SizedBox.shrink();
    }
  }

  String _minutesToHHmm(int? minutes) {
    if (minutes == null) return '--:--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  DateTime? _bookingDateValue(BookingDetailEntity booking) {
    final parsed = DateTime.tryParse(booking.bookingDate ?? '');
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isFixedBooking(BookingDetailEntity booking) {
    return booking.isFixedSchedule == true || booking.fixedScheduleId != null;
  }

  bool _isFixedMatchingBooking(BookingDetailEntity booking) {
    return _isFixedBooking(booking) && booking.matchingSessionId != null;
  }

  bool _isActionablePendingBooking(BookingDetailEntity booking) {
    return booking.status == 'PENDING' && !_isFixedBooking(booking);
  }

  bool _isInStaffBookingWindow(BookingDetailEntity booking) {
    final date = _bookingDateValue(booking);
    if (date == null) return true;
    if (_bookingDateFrom != null || _bookingDateTo != null) {
      final from = _bookingDateFrom;
      final to = _bookingDateTo ?? _bookingDateFrom;
      if (from != null && date.isBefore(_dateOnly(from))) return false;
      if (to != null && date.isAfter(_dateOnly(to))) return false;
      return true;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastVisibleDate = today.add(const Duration(days: 7));
    return !date.isBefore(today) && !date.isAfter(lastVisibleDate);
  }

  String _formatBookingFilterDate(DateTime date) {
    return DateDisplayFormatter.date(_dateOnly(date));
  }

  String _bookingDateFilterLabel() {
    if (_bookingDateFrom == null && _bookingDateTo == null) {
      return context.tr(vi: '7 ngày tới', en: 'Next 7 days');
    }
    final from = _bookingDateFrom;
    final to = _bookingDateTo ?? _bookingDateFrom;
    if (from != null &&
        to != null &&
        _dateOnly(from).isAtSameMomentAs(_dateOnly(to))) {
      return _formatBookingFilterDate(from);
    }
    if (from != null && to != null) {
      return '${_formatBookingFilterDate(from)} - ${_formatBookingFilterDate(to)}';
    }
    return context.tr(vi: 'Tùy chọn', en: 'Custom');
  }

  Future<void> _pickSingleBookingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _bookingDateFrom ?? _dateOnly(now),
      firstDate: _dateOnly(now).subtract(const Duration(days: 365)),
      lastDate: _dateOnly(now).add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final selected = _dateOnly(picked);
    setState(() {
      _bookingDateFrom = selected;
      _bookingDateTo = selected;
    });
  }

  Future<void> _pickBookingDateRange() async {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _bookingDateFrom != null
          ? DateTimeRange(
              start: _bookingDateFrom!,
              end: _bookingDateTo ?? _bookingDateFrom!,
            )
          : DateTimeRange(
              start: today,
              end: today.add(const Duration(days: 7)),
            ),
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _bookingDateFrom = _dateOnly(picked.start);
      _bookingDateTo = _dateOnly(picked.end);
    });
  }

  void _clearBookingDateFilter() {
    setState(() {
      _bookingDateFrom = null;
      _bookingDateTo = null;
    });
  }

  String _normalizeFilterText(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  String? _bookingCourtId(BookingDetailEntity booking) {
    final id = booking.courtId ?? booking.court?.id;
    if (id == null || id.trim().isEmpty) return null;
    return id;
  }

  String _bookingCourtName(BookingDetailEntity booking) {
    final name = booking.courtName ?? booking.court?.name;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return context.tr(vi: 'Sân chưa rõ', en: 'Unknown court');
  }

  List<MapEntry<String, String>> _courtFilterOptions() {
    final courtsById = <String, String>{};
    for (final booking in _bookings) {
      final id = _bookingCourtId(booking);
      if (id == null) continue;
      courtsById.putIfAbsent(id, () => _bookingCourtName(booking));
    }
    final options = courtsById.entries.toList();
    options.sort((a, b) => a.value.compareTo(b.value));
    return options;
  }

  String? _bookingSportName(BookingDetailEntity booking) {
    final name = booking.sportName;
    if (name == null || name.trim().isEmpty) return null;
    return name.trim();
  }

  List<String> _sportFilterOptions() {
    final sportsByKey = <String, String>{};
    for (final booking in _bookings) {
      final name = _bookingSportName(booking);
      if (name == null) continue;
      sportsByKey.putIfAbsent(_normalizeFilterText(name), () => name);
    }
    final options = sportsByKey.values.toList();
    options.sort();
    return options;
  }

  void _clearBookingAttributeFilters() {
    setState(() {
      _selectedCourtFilterId = null;
      _selectedSportFilterName = null;
    });
  }

  int _compareBookingSchedule(BookingDetailEntity a, BookingDetailEntity b) {
    final aDate = _bookingDateValue(a);
    final bDate = _bookingDateValue(b);
    if (aDate != null && bDate != null) {
      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) return dateCompare;
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }

    final timeCompare = (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0);
    if (timeCompare != 0) return timeCompare;
    return (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  // --- TAB 0: TỔNG QUAN ---
  Widget _buildOverviewTab() {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final todayBookings = _bookings
        .where((b) => b.bookingDate == todayString)
        .toList();
    todayBookings.sort(
      (a, b) => (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0),
    );

    double revenueToday = 0;
    for (final booking in todayBookings) {
      if (booking.status == 'CONFIRMED' || booking.status == 'COMPLETED') {
        revenueToday += booking.totalPrice ?? 0;
      }
    }
    String revenueText = context.tr(vi: '0 đ', en: '0 VND');
    if (revenueToday >= 1000) {
      revenueText = context.tr(
        vi: '${(revenueToday / 1000).toStringAsFixed(0)}k đ',
        en: '${(revenueToday / 1000).toStringAsFixed(0)}k VND',
      );
    } else if (revenueToday > 0) {
      revenueText = context.tr(
        vi: '${revenueToday.toInt()} đ',
        en: '${revenueToday.toInt()} VND',
      );
    }

    final bookedCount = todayBookings
        .where((b) => b.status != 'CANCELLED')
        .length;
    final slotText = context.tr(
      vi: '$bookedCount lượt',
      en: '$bookedCount slots',
    );

    return RefreshIndicator(
      onRefresh: () =>
          _bookingCubit.loadBookings(facilityId: _selectedFacilityId),
      color: const Color(0xFFFF5600),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner
            Text(
              '${context.tr(vi: 'Chào ngày làm việc mới', en: 'Good morning')}, ${_user?.name ?? context.tr(vi: 'Nhân viên', en: 'Staff')}! ☀️',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                vi: 'Kiểm tra hoạt động vận hành của sân đấu hôm nay.',
                en: "Check today's court operations.",
              ),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Operating Stats Grid
            Row(
              children: [
                _buildStatCard(
                  context.tr(vi: 'Doanh thu hôm nay', en: 'Revenue Today'),
                  revenueText,
                  Icons.payments_outlined,
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  context.tr(vi: 'Lượt đặt hôm nay', en: 'Bookings Today'),
                  slotText,
                  Icons.check_circle_outline,
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              context.tr(vi: 'TÌNH TRẠNG SÂN ĐẤU', en: 'COURT STATUS'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            CustomerBookingCatalogSection(
              role: 'staff',
              facilityId:
                  _selectedFacilityId ??
                  (_facilities.isNotEmpty ? _facilities.first.id : null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
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

  // --- TAB 1: VẬN HÀNH SÂN (ACTION CARDS) ---
  Widget _buildOperationTab() {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: [
        _buildActionCard(
          context.tr(vi: 'Khung giờ sân', en: 'Court Slots'),
          context.tr(
            vi: 'Cấu hình lịch giờ trống & bảng giá',
            en: 'Configure open hours & pricing',
          ),
          Icons.schedule,
          Colors.orange,
          () => context.push('/staff/court-slot-config'),
        ),
        _buildActionCard(
          context.tr(vi: 'Quản lý Sân', en: 'Manage Courts'),
          context.tr(
            vi: 'Xem sơ đồ & thông tin chi tiết sân',
            en: 'View layout & court details',
          ),
          Icons.stadium,
          Colors.teal,
          () {
            if (_selectedFacilityId != null) {
              final matched = _facilities
                  .where((f) => f.id == _selectedFacilityId)
                  .toList();
              final activeFacName = matched.isNotEmpty
                  ? matched.first.name
                  : context.tr(vi: 'Cơ sở', en: 'Facility');
              context.push(
                '/facility/$_selectedFacilityId/courts',
                extra: activeFacName,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.tr(
                      vi: 'Vui lòng chọn cơ sở trước khi quản lý sân.',
                      en: 'Please select a facility before managing courts.',
                    ),
                  ),
                ),
              );
            }
          },
        ),
        _buildActionCard(
          context.tr(vi: 'Môn thể thao', en: 'Sports'),
          context.tr(
            vi: 'Danh mục các môn thể thao đang chạy',
            en: 'List of active sports',
          ),
          Icons.sports,
          Colors.blue,
          () => context.push('/sport'),
        ),
        _buildActionCard(
          context.tr(vi: 'Báo cáo sân', en: 'Court Reports'),
          context.tr(
            vi: 'Thống kê hiệu suất khai thác sân',
            en: 'Court utilization & analytics',
          ),
          Icons.analytics,
          Colors.purple,
          () => context.push(
            '/staff/report',
            extra: {'facilityId': _selectedFacilityId},
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String desc,
    IconData icon,
    Color color, [
    VoidCallback? onTap,
  ]) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 2: ĐẶT LỊCH (DUYỆT ĐẶT LỊCH) ---
  Widget _buildBookingTab() {
    final filteredBookings = _bookings.where((b) {
      if (!_isInStaffBookingWindow(b)) {
        return false;
      }

      if (_selectedCourtFilterId != null &&
          _bookingCourtId(b) != _selectedCourtFilterId) {
        return false;
      }

      if (_selectedSportFilterName != null &&
          _normalizeFilterText(_bookingSportName(b)) !=
              _normalizeFilterText(_selectedSportFilterName)) {
        return false;
      }

      // 1. Filter by status
      if (_selectedStatusFilter != null) {
        if (_selectedStatusFilter == 'PENDING') {
          if (!_isActionablePendingBooking(b)) return false;
        } else if (b.status != _selectedStatusFilter) {
          return false;
        }
      }

      // 2. Filter rescheduled bookings
      if (b.status == 'RESCHEDULED') {
        return false;
      }

      // 3. Filter by search query
      if (_bookingSearchQuery.isNotEmpty) {
        final query = _bookingSearchQuery.toLowerCase();
        final idMatch = b.id.toLowerCase().contains(query);

        final cachedUser = _usersCache[b.userId];
        final clientName =
            (b.user?.name ?? cachedUser?.name ?? b.guestName ?? 'Khách lẻ')
                .toLowerCase();
        final courtName = (b.courtName ?? b.court?.name ?? '').toLowerCase();
        final sportName = (b.sportName ?? '').toLowerCase();

        return idMatch ||
            clientName.contains(query) ||
            courtName.contains(query) ||
            sportName.contains(query);
      }

      return true;
    }).toList();

    // Sort by schedule so staff see the nearest sessions first.
    filteredBookings.sort(_compareBookingSchedule);

    final bookingList = RefreshIndicator(
      onRefresh: () =>
          _bookingCubit.loadBookings(facilityId: _selectedFacilityId),
      color: const Color(0xFFFF5600),
      child: ListView(
        controller: _bookingScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        children: [
          // Roster Filter Card
          _buildRosterFilterCard(),
          const SizedBox(height: 20),

          Text(
            '${context.tr(vi: 'LỊCH ĐẶT SÂN', en: 'BOOKINGS')} (${filteredBookings.length})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          if (filteredBookings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(
                        vi: 'Không tìm thấy lịch đặt nào khớp.',
                        en: 'No matching bookings found.',
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredBookings.map(
              (booking) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildStaffBookingCard(booking),
              ),
            ),
        ],
      ),
    );

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              labelColor: const Color(0xFFFF5600),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFFF5600),
              tabs: [
                Tab(
                  text: context.tr(vi: 'Lịch đặt sân', en: 'Court bookings'),
                ),
                Tab(
                  text: context.tr(vi: 'Lịch cố định', en: 'Fixed schedules'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                bookingList,
                const FixedScheduleListWidget(prioritizePendingApproval: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _bookingSearchController,
                    decoration: InputDecoration(
                      hintText: context.tr(
                        vi: 'Tìm theo mã, tên khách, sân...',
                        en: 'Search by ID, guest name, court...',
                      ),
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: Colors.grey,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showNewBookingDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5600),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  context.tr(vi: 'Đặt lịch', en: 'Book Court'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip(context.tr(vi: 'Tất cả', en: 'All'), null),
                _buildStatusChip(
                  context.tr(vi: 'Chờ duyệt', en: 'Pending'),
                  'PENDING',
                ),
                _buildStatusChip(
                  context.tr(vi: 'Đã check-in', en: 'Checked-in'),
                  'CONFIRMED',
                ),
                _buildStatusChip(
                  context.tr(vi: 'Hoàn thành', en: 'Completed'),
                  'COMPLETED',
                ),
                _buildStatusChip(
                  context.tr(vi: 'Đã hủy', en: 'Cancelled'),
                  'CANCELLED',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildBookingDateFilterRow(),
          const SizedBox(height: 12),
          _buildBookingAttributeFilterRow(),
        ],
      ),
    );
  }

  Widget _buildBookingDateFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Color(0xFFFF5600),
                ),
                const SizedBox(width: 6),
                Text(
                  _bookingDateFilterLabel(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _pickSingleBookingDate,
            icon: const Icon(Icons.today_outlined, size: 16),
            label: Text(context.tr(vi: 'Chọn ngày', en: 'Date')),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _pickBookingDateRange,
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(context.tr(vi: 'Khoảng ngày', en: 'Date range')),
          ),
          if (_bookingDateFrom != null || _bookingDateTo != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: context.tr(vi: 'Xóa lọc ngày', en: 'Clear date'),
              onPressed: _clearBookingDateFilter,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingAttributeFilterRow() {
    final courtOptions = _courtFilterOptions();
    final sportOptions = _sportFilterOptions();
    final selectedCourtLabel = courtOptions
        .where((option) => option.key == _selectedCourtFilterId)
        .map((option) => option.value)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    final selectedSportLabel = sportOptions
        .where(
          (option) =>
              _normalizeFilterText(option) ==
              _normalizeFilterText(_selectedSportFilterName),
        )
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterPopupButton(
            width: 170,
            icon: Icons.stadium_outlined,
            label:
                selectedCourtLabel ??
                context.tr(vi: 'Tất cả sân', en: 'All courts'),
            isActive: _selectedCourtFilterId != null,
            onTap: () => _showCourtFilterPopup(courtOptions),
          ),
          const SizedBox(width: 8),
          _buildFilterPopupButton(
            width: 190,
            icon: Icons.sports_soccer_outlined,
            label:
                selectedSportLabel ??
                context.tr(vi: 'Tất cả môn', en: 'All sports'),
            isActive: _selectedSportFilterName != null,
            onTap: () => _showSportFilterPopup(sportOptions),
          ),
          if (_selectedCourtFilterId != null ||
              _selectedSportFilterName != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: context.tr(
                vi: 'Xóa lọc sân/môn',
                en: 'Clear court/sport filters',
              ),
              onPressed: _clearBookingAttributeFilters,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterPopupButton({
    required double width,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      height: 44,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? const Color(0xFFFF5600)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? const Color(0xFFFF5600) : Colors.black87,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? const Color(0xFFFF5600)
                          : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCourtFilterPopup(
    List<MapEntry<String, String>> courtOptions,
  ) async {
    final selected = await AppPopup.showSelection<String>(
      context,
      title: context.tr(vi: 'Chọn sân', en: 'Select court'),
      subtitle: context.tr(
        vi: 'Lọc lịch đặt sân theo sân cụ thể.',
        en: 'Filter bookings by a specific court.',
      ),
      icon: Icons.stadium_outlined,
      confirmLabel: context.tr(vi: 'Áp dụng', en: 'Apply'),
      searchHint: context.tr(vi: 'Tìm sân...', en: 'Search courts...'),
      selectedValue: _selectedCourtFilterId ?? _allFilterValue,
      options: [
        AppPopupOption<String>(
          value: _allFilterValue,
          label: context.tr(vi: 'Tất cả sân', en: 'All courts'),
          icon: Icons.select_all_rounded,
        ),
        ...courtOptions.map(
          (option) => AppPopupOption<String>(
            value: option.key,
            label: option.value,
            icon: Icons.stadium_outlined,
          ),
        ),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedCourtFilterId = selected == _allFilterValue ? null : selected;
    });
  }

  Future<void> _showSportFilterPopup(List<String> sportOptions) async {
    final selected = await AppPopup.showSelection<String>(
      context,
      title: context.tr(vi: 'Chọn môn thể thao', en: 'Select sport'),
      subtitle: context.tr(
        vi: 'Lọc lịch đặt sân theo môn thể thao.',
        en: 'Filter bookings by sport.',
      ),
      icon: Icons.sports_soccer_outlined,
      confirmLabel: context.tr(vi: 'Áp dụng', en: 'Apply'),
      searchHint: context.tr(vi: 'Tìm môn...', en: 'Search sports...'),
      selectedValue: _selectedSportFilterName ?? _allFilterValue,
      options: [
        AppPopupOption<String>(
          value: _allFilterValue,
          label: context.tr(vi: 'Tất cả môn', en: 'All sports'),
          icon: Icons.select_all_rounded,
        ),
        ...sportOptions.map(
          (sportName) => AppPopupOption<String>(
            value: sportName,
            label: sportName,
            icon: Icons.sports_soccer_outlined,
          ),
        ),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedSportFilterName = selected == _allFilterValue ? null : selected;
    });
  }

  Widget _buildStatusChip(String label, String? value) {
    final isSelected = _selectedStatusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedStatusFilter = value;
            });
          }
        },
        selectedColor: const Color(0xFFFF5600),
        labelStyle: TextStyle(
          color: isSelected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStaffBookingCard(BookingDetailEntity booking) {
    final theme = Theme.of(context);
    final isPending = booking.status == 'PENDING';
    final isActionablePending = _isActionablePendingBooking(booking);
    final isConfirmed = booking.status == 'CONFIRMED';
    final isFixed = _isFixedBooking(booking);
    final isMatching = booking.matchingSessionId != null;
    final isFixedMatching = _isFixedMatchingBooking(booking);
    final code = booking.id.length > 4
        ? booking.id.substring(booking.id.length - 4).toUpperCase()
        : booking.id.toUpperCase();

    Color statusColor = Colors.orange;
    String statusText = context.tr(vi: 'Chờ duyệt', en: 'Pending');

    if (isPending && isFixedMatching) {
      statusColor = Colors.purple;
      statusText = context.tr(vi: 'Chờ ghép', en: 'Matching');
    } else if (isPending && isFixed) {
      statusColor = Colors.blue;
      statusText = context.tr(vi: 'Lịch cố định', en: 'Fixed schedule');
    } else if (booking.status == 'CONFIRMED') {
      statusColor = Colors.green;
      statusText = context.tr(vi: 'Đã check-in', en: 'Checked-in');
    } else if (booking.status == 'COMPLETED') {
      statusColor = Colors.blue;
      statusText = context.tr(vi: 'Hoàn thành', en: 'Completed');
    } else if (booking.status == 'CANCELLED') {
      statusColor = Colors.red;
      statusText = context.tr(vi: 'Đã hủy', en: 'Cancelled');
    }

    final startStr = _minutesToHHmm(booking.startMinutes);
    final endStr = _minutesToHHmm(booking.endMinutes);
    final dateStr = DateDisplayFormatter.fromApiDate(booking.bookingDate);
    final sportName = booking.sportName;

    final cachedUser = _usersCache[booking.userId];
    final userName =
        booking.user?.name ??
        cachedUser?.name ??
        booking.guestName ??
        context.tr(vi: 'Khách lẻ', en: 'Walk-in Guest');
    final userAvatar = booking.user?.avatar ?? cachedUser?.avatar;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPending
              ? statusColor.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: isActionablePending ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${context.tr(vi: 'Mã Booking', en: 'Booking ID')} #$code',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (isFixedMatching) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.groups,
                                size: 11,
                                color: Colors.purple.shade700,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                context.tr(vi: 'Ghép CĐ', en: 'Fixed Match'),
                                style: TextStyle(
                                  color: Colors.purple.shade700,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (isFixed) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_repeat,
                                size: 11,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                context.tr(vi: 'Lịch CĐ', en: 'Fixed'),
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (isMatching) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF5600,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.groups,
                                size: 11,
                                color: const Color(0xFFFF5600),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                context.tr(vi: 'Ghép trận', en: 'Match'),
                                style: const TextStyle(
                                  color: Color(0xFFFF5600),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor == Colors.green
                          ? Colors.green.shade800
                          : statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(
                    0xFFFF5600,
                  ).withValues(alpha: 0.1),
                  backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                      ? NetworkImage(userAvatar)
                      : null,
                  child: userAvatar == null || userAvatar.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 18,
                          color: Color(0xFFFF5600),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking.courtName ??
                            booking.court?.name ??
                            context.tr(vi: 'Sân đấu', en: 'Court'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      if (sportName != null && sportName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          sportName,
                          style: TextStyle(
                            color: const Color(0xFFFF5600),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  '$dateStr • $startStr - $endStr',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            if (isPending && isFixed) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.event_repeat,
                    size: 14,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr(
                      vi: 'Lịch cố định — hệ thống tự quản lý',
                      en: 'Fixed schedule — auto-managed',
                    ),
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ] else if (isPending || isConfirmed) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (isPending) ...[
                    OutlinedButton(
                      onPressed: () => _bookingCubit.updateBookingStatus(
                        booking.id,
                        'CANCELLED',
                        _selectedFacilityId!,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(context.tr(vi: 'Từ chối', en: 'Reject')),
                    ),
                    ElevatedButton(
                      onPressed: () => _bookingCubit.updateBookingStatus(
                        booking.id,
                        'CONFIRMED',
                        _selectedFacilityId!,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        context.tr(vi: 'Duyệt đặt sân', en: 'Approve'),
                      ),
                    ),
                  ] else if (isConfirmed) ...[
                    OutlinedButton(
                      onPressed: () => _showRescheduleDialog(context, booking),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF5600)),
                        foregroundColor: const Color(0xFFFF5600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(context.tr(vi: 'Đổi lịch', en: 'Reschedule')),
                    ),
                    ElevatedButton(
                      onPressed: () => _bookingCubit.updateBookingStatus(
                        booking.id,
                        'COMPLETED',
                        _selectedFacilityId!,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        context.tr(vi: 'Kết thúc ca', en: 'Check-out'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- TAB 3: THU NGÂN (XÁC NHẬN THANH TOÁN) ---
  Widget _buildPaymentTab() {
    return BlocConsumer<StaffPaymentCubit, StaffPaymentState>(
      bloc: _paymentCubit,
      listener: (context, state) {
        if (state is StaffPaymentActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is StaffPaymentError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        if (state is StaffPaymentLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF5600)),
          );
        }

        List<PaymentDetailEntity> payments = [];
        List<BookingDetailEntity> bookings = [];
        if (state is StaffPaymentLoaded) {
          payments = state.payments;
          bookings = state.bookings;
        }

        final pendingPayments = payments
            .where(
              (p) =>
                  p.status == 'PENDING' &&
                  bookings.any(
                    (booking) =>
                        booking.id == p.bookingId &&
                        booking.status != 'CANCELLED',
                  ),
            )
            .toList();
        final processedPayments = payments
            .where((p) => p.status == 'SUCCESS')
            .toList();

        return RefreshIndicator(
          onRefresh: () =>
              _paymentCubit.loadPayments(facilityId: _selectedFacilityId),
          color: const Color(0xFFFF5600),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            children: [
              // Pending Payments
              Text(
                context.tr(
                  vi: 'HÓA ĐƠN CHỜ THU TIỀN TẠI QUẦY',
                  en: 'PENDING OVER-THE-COUNTER INVOICES',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              if (pendingPayments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      context.tr(
                        vi: 'Không có hóa đơn nào chờ thu tiền.',
                        en: 'No pending invoices.',
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                ...pendingPayments.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildStaffInvoiceCard(p, bookings),
                  ),
                ),

              const SizedBox(height: 24),

              // Processed Payments
              Text(
                context.tr(vi: 'HÓA ĐƠN ĐÃ XỬ LÝ', en: 'PROCESSED INVOICES'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              if (processedPayments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      context.tr(
                        vi: 'Chưa có hóa đơn nào được xử lý.',
                        en: 'No processed invoices yet.',
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                ...processedPayments.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildStaffInvoiceCard(p, bookings),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaffInvoiceCard(
    PaymentDetailEntity payment,
    List<BookingDetailEntity> bookings,
  ) {
    final isPending = payment.status == 'PENDING';
    final code = payment.id.length > 4
        ? payment.id.substring(payment.id.length - 4).toUpperCase()
        : payment.id.toUpperCase();

    // Cross-reference with bookings list
    final matchedBookings = bookings
        .where((b) => b.id == payment.bookingId)
        .toList();
    final booking = matchedBookings.isNotEmpty ? matchedBookings.first : null;

    final clientName =
        booking?.user?.name ??
        booking?.guestName ??
        context.tr(vi: 'Khách lẻ', en: 'Walk-in Guest');
    final courtName =
        booking?.courtName ??
        booking?.court?.name ??
        payment.courtName ??
        context.tr(vi: 'Sân đấu', en: 'Court');
    final sportName = booking?.sportName ?? payment.sportName;
    final bookingDate = DateDisplayFormatter.fromApiDate(
      booking?.bookingDate ?? payment.bookingDate,
    );
    final startStr = _minutesToHHmm(
      booking?.startMinutes ?? payment.startMinutes,
    );
    final endStr = _minutesToHHmm(booking?.endMinutes ?? payment.endMinutes);

    final formattedAmount = (payment.amount ?? 0.0)
        .toInt()
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    final priceStr = context.tr(
      vi: '$formattedAmount đ',
      en: '$formattedAmount VND',
    );

    Color statusColor = Colors.orange;
    String statusText = context.tr(vi: 'Chờ thanh toán', en: 'Pending');
    if (payment.status == 'SUCCESS') {
      statusColor = Colors.green;
      statusText = context.tr(vi: 'Thành công', en: 'Success');
    } else if (payment.status == 'FAILED') {
      statusColor = Colors.red;
      statusText = context.tr(vi: 'Thất bại', en: 'Failed');
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPending
              ? const Color(0xFFFF5600).withValues(alpha: 0.3)
              : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${context.tr(vi: 'Hóa đơn', en: 'Invoice')} #$code',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor == Colors.green
                          ? Colors.green.shade800
                          : statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${context.tr(vi: 'Khách', en: 'Guest')}: $clientName',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              courtName,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            if (sportName != null && sportName.isNotEmpty)
              Text(
                sportName,
                style: const TextStyle(
                  color: Color(0xFFFF5600),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (bookingDate.isNotEmpty)
              Text(
                '$bookingDate • $startStr - $endStr',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            const Divider(height: 24),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  priceStr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (isPending)
                  ElevatedButton.icon(
                    onPressed: () => _paymentCubit.confirmPaymentSuccess(
                      payment.id,
                      _selectedFacilityId!,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5600),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: Text(
                      context.tr(vi: 'Thu tiền tại quầy', en: 'Receive Cash'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
                    backgroundColor: Colors.orange.shade50,
                    backgroundImage:
                        _user?.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
                        ? NetworkImage(_user!.avatarUrl!)
                        : null,
                    child: _user?.avatarUrl == null || _user!.avatarUrl!.isEmpty
                        ? Text(
                            _user?.name != null && _user!.name!.isNotEmpty
                                ? _user!.name!.substring(0, 1).toUpperCase()
                                : 'S',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
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
                              context.tr(
                                vi: 'Nhân viên vận hành',
                                en: 'Operations Staff',
                              ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user?.email ?? 'staff@sportenergy.com',
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.tr(
                              vi: 'Vai trò: Nhân viên',
                              en: 'Role: Staff',
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
            onTap: () async {
              await context.push(
                '/staff/personal-information',
                extra: {'facilityId': _selectedFacilityId},
              );
              if (!mounted) return;
              await _loadUser();
              _bookingCubit.loadBookings(facilityId: _selectedFacilityId);
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
            context.tr(vi: 'Hỗ trợ kỹ thuật', en: 'Technical Support'),
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

  Widget _buildMenuItem(IconData icon, String title, {VoidCallback? onTap}) {
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
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ),
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

class _NewBookingDialog extends StatefulWidget {
  final String? selectedFacilityId;
  final Map<String, UserEntity> usersCache;
  final VoidCallback onStateChanged;
  final VoidCallback onBookingCreated;

  const _NewBookingDialog({
    super.key,
    required this.selectedFacilityId,
    required this.usersCache,
    required this.onStateChanged,
    required this.onBookingCreated,
  });

  @override
  State<_NewBookingDialog> createState() => _NewBookingDialogState();
}

class _NewBookingDialogState extends State<_NewBookingDialog> {
  String? _facilityId;
  String? _sportId;
  String? _courtId;
  DateTime _date = DateTime.now();
  int? _selectedSlotIndex;
  bool _isCash = true;

  String _customerType = 'walk_in'; // 'walk_in' or 'registered'
  String? _selectedUserId;
  String _userSearchQuery = '';
  final _guestNameController = TextEditingController();
  final _guestPhoneController = TextEditingController();

  List<SportEntity> _sports = [];
  List<CourtEntity> _courts = [];
  SlotConfigEntity? _slotConfig;
  Set<int> _bookedSlotIndices = {};

  bool _isLoadingSports = false;
  bool _isLoadingCourts = false;
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;

  bool get canSubmit {
    final hasCustomer = _customerType == 'registered'
        ? _selectedUserId != null
        : _guestNameController.text.trim().isNotEmpty &&
              _guestPhoneController.text.trim().isNotEmpty;
    return _courtId != null &&
        _selectedSlotIndex != null &&
        hasCustomer &&
        !_isSubmitting;
  }

  bool get isSubmitting => _isSubmitting;

  Future<void> submit() => _submit();

  void _updateForm(VoidCallback update) {
    setState(update);
    widget.onStateChanged();
  }

  @override
  void initState() {
    super.initState();
    _facilityId = widget.selectedFacilityId;
    _loadSports();
    _loadCourts();
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSports() async {
    if (!mounted) return;
    setState(() => _isLoadingSports = true);
    try {
      final useCase = GetIt.I<GetSportsUseCase>();
      final res = await useCase();
      if (!mounted) return;
      if (res.success && res.data != null) {
        setState(() {
          _sports = res.data!;
        });
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoadingSports = false);
  }

  Future<void> _loadCourts() async {
    if (_facilityId == null) return;
    if (!mounted) return;
    setState(() => _isLoadingCourts = true);
    try {
      final useCase = GetIt.I<GetCourtsUseCase>();
      final res = await useCase();
      if (!mounted) return;
      if (res.success && res.data != null) {
        setState(() {
          _courts = res.data!
              .where((c) => c.facilityId == _facilityId && c.status == 'ACTIVE')
              .toList();
        });
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoadingCourts = false);
  }

  Future<void> _loadSlots() async {
    if (_courtId == null) return;
    if (!mounted) return;
    setState(() {
      _isLoadingSlots = true;
      _selectedSlotIndex = null;
      _slotConfig = null;
      _bookedSlotIndices.clear();
    });
    try {
      final formattedDate =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      final useCase = GetIt.I<GetSlotConfigUseCase>();
      final res = await useCase(_courtId!, bookingDate: formattedDate);
      if (!mounted) return;
      if (res.success && res.data != null) {
        final config = res.data!;

        // Load booked slots
        final bookingUseCase = GetIt.I<GetBookingHistoryUseCase>();
        final bookingsRes = await bookingUseCase();
        if (!mounted) return;
        final booked = <int>{};
        if (bookingsRes.success && bookingsRes.data != null) {
          final courtBookings = bookingsRes.data!.where(
            (b) =>
                b.courtId == _courtId &&
                b.bookingDate == formattedDate &&
                b.status != 'CANCELLED',
          );
          for (final b in courtBookings) {
            final bStart = b.startMinutes;
            final bEnd = b.endMinutes;
            if (bStart != null && bEnd != null) {
              for (int i = 0; i < config.slots.length; i++) {
                final slot = config.slots[i];
                if (slot.startMinutes < bEnd && slot.endMinutes > bStart) {
                  booked.add(i);
                }
              }
            }
          }
        }
        setState(() {
          _slotConfig = config;
          _bookedSlotIndices = booked;
        });
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoadingSlots = false);
  }

  double get _totalPrice {
    if (_selectedSlotIndex == null || _slotConfig == null || _courtId == null) {
      return 0;
    }
    final matches = _courts.where((c) => c.id == _courtId);
    if (matches.isEmpty) return 0;
    final court = matches.first;
    final int? priceVal = court is BookingCourtModel
        ? court.pricePerHour
        : null;
    if (priceVal == null) return 0;
    final duration = _slotConfig?.slotDurationMinutes ?? 60;
    return priceVal * duration / 60.0;
  }

  Future<void> _submit() async {
    if (_courtId == null || _selectedSlotIndex == null || _slotConfig == null) {
      return;
    }
    final language = context.read<LanguageCubit>().state;
    if (_customerType == 'registered' && _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language == 'vi'
                ? 'Vui lòng chọn khách hàng đã đăng ký'
                : 'Please select a registered customer',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_customerType == 'walk_in' &&
        (_guestNameController.text.trim().isEmpty ||
            _guestPhoneController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            language == 'vi'
                ? 'Vui lòng nhập tên và số điện thoại khách vãng lai'
                : 'Please enter the walk-in customer name and phone number',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _updateForm(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final slot = _slotConfig!.slots[_selectedSlotIndex!];
      final formattedDate =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

      // Step 1: Create booking
      final bookingUseCase = GetIt.I<CreateBookingUseCase>();
      final bookingRes = await bookingUseCase(
        courtId: _courtId!,
        bookingDate: formattedDate,
        startMinutes: slot.startMinutes,
        endMinutes: slot.endMinutes,
        totalPrice: _totalPrice,
        userId: _customerType == 'registered' ? _selectedUserId : null,
        guestName: _customerType == 'walk_in'
            ? _guestNameController.text.trim()
            : null,
        guestPhone: _customerType == 'walk_in'
            ? _guestPhoneController.text.trim()
            : null,
      );

      if (bookingRes.success && bookingRes.data != null) {
        final bookingId = bookingRes.data!.id;

        // Step 2: Approve the booking so the invoice can be issued.
        final approvalRes = await GetIt.I<UpdateBookingStatusUseCase>().call(
          bookingId,
          'CONFIRMED',
        );
        if (!approvalRes.success) {
          throw Exception(
            approvalRes.message ?? 'Không thể duyệt booking tại quầy.',
          );
        }

        // Step 3: Get the generated invoice (or create one for a walk-in).
        final paymentUseCase = GetIt.I<CreatePaymentUseCase>();
        final paymentRes = await paymentUseCase(
          bookingId: bookingId,
          amount: _totalPrice,
          method: _isCash ? 'CASH' : 'BANK_TRANSFER',
          transactionId:
              'pay_at_counter_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (!paymentRes.success || paymentRes.data == null) {
          throw Exception(
            paymentRes.message ?? 'Không thể tạo hóa đơn tại quầy.',
          );
        }

        // Step 4: Confirm the counter payment.
        final paymentId = paymentRes.data!.id;
        final paymentStatusRes = await GetIt.I<UpdatePaymentStatusUseCase>()
            .call(paymentId, 'SUCCESS');
        if (!paymentStatusRes.success) {
          throw Exception(
            paymentStatusRes.message ?? 'Không thể xác nhận thanh toán.',
          );
        }

        try {
          GetIt.I<AppNotificationEventBus>().emit(
            const AppNotificationEvent(
              type: AppNotificationEventType.bookingCreated,
            ),
          );
          GetIt.I<AppNotificationEventBus>().emit(
            const AppNotificationEvent(
              type: AppNotificationEventType.bookingConfirmed,
            ),
          );
          GetIt.I<AppNotificationEventBus>().emit(
            AppNotificationEvent(
              type: _isCash
                  ? AppNotificationEventType.paymentOfflineConfirmed
                  : AppNotificationEventType.paymentOnlineSuccess,
            ),
          );
        } catch (e) {
          debugPrint('Error emitting counter booking events: $e');
        }

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                language == 'vi'
                    ? 'Tạo đặt lịch & hóa đơn tại quầy thành công!'
                    : 'Counter booking and invoice created successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          widget.onBookingCreated();
          navigator.pop();
        }
      } else {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                bookingRes.message ??
                    (language == 'vi'
                        ? 'Tạo đặt lịch thất bại'
                        : 'Failed to create booking'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(language == 'vi' ? 'Lỗi: $e' : 'Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) _updateForm(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _sportId,
          hint: Text(context.tr(vi: 'Chọn môn thể thao', en: 'Select sport')),
          decoration: InputDecoration(
            labelText: context.tr(vi: 'Môn thể thao', en: 'Sport'),
          ),
          items: _sports
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    s.name ?? context.tr(vi: 'Môn thể thao', en: 'Sport'),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            _updateForm(() {
              _sportId = val;
              _courtId = null;
              _slotConfig = null;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _courtId,
          hint: Text(context.tr(vi: 'Chọn sân', en: 'Select court')),
          decoration: InputDecoration(
            labelText: context.tr(vi: 'Sân đấu', en: 'Court'),
          ),
          items: _courts
              .where((c) => _sportId == null || c.sportId == _sportId)
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name ?? context.tr(vi: 'Sân', en: 'Court')),
                ),
              )
              .toList(),
          onChanged: (val) {
            _updateForm(() {
              _courtId = val;
              _slotConfig = null;
            });
            _loadSlots();
          },
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (picked != null) {
              setState(() {
                _date = picked;
                _slotConfig = null;
              });
              _loadSlots();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateDisplayFormatter.date(_date)),
                const Icon(Icons.calendar_month, color: Color(0xFFFF5600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // --- Customer Selection UI ---
        Text(
          context.tr(vi: 'Loại khách hàng:', en: 'Customer Type:'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(context.tr(vi: 'Khách vãng lai', en: 'Walk-in')),
              selected: _customerType == 'walk_in',
              selectedColor: const Color(0xFFFF5600),
              labelStyle: TextStyle(
                color: _customerType == 'walk_in'
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
              onSelected: (val) {
                if (val) {
                  _updateForm(() {
                    _customerType = 'walk_in';
                    _selectedUserId = null;
                  });
                }
              },
            ),
            ChoiceChip(
              label: Text(context.tr(vi: 'Khách đã đăng ký', en: 'Registered')),
              selected: _customerType == 'registered',
              selectedColor: const Color(0xFFFF5600),
              labelStyle: TextStyle(
                color: _customerType == 'registered'
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
              onSelected: (val) {
                if (val) {
                  _updateForm(() {
                    _customerType = 'registered';
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_customerType == 'walk_in') ...[
          TextField(
            controller: _guestNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.tr(vi: 'Tên khách hàng', en: 'Customer name'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            onChanged: (_) => widget.onStateChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _guestPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr(vi: 'Số điện thoại', en: 'Phone number'),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            onChanged: (_) => widget.onStateChanged(),
          ),
          const SizedBox(height: 12),
        ],
        if (_customerType == 'registered') ...[
          TextField(
            decoration: InputDecoration(
              labelText: context.tr(
                vi: 'Tìm khách hàng',
                en: 'Search customer',
              ),
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: context.tr(
                vi: 'Nhập tên hoặc email...',
                en: 'Enter name or email...',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _userSearchQuery = val;
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedUserId,
            hint: Text(
              context.tr(vi: 'Chọn khách hàng', en: 'Select customer'),
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
            items: widget.usersCache.values
                .where((u) {
                  final q = _userSearchQuery.toLowerCase();
                  return q.isEmpty ||
                      (u.name ?? '').toLowerCase().contains(q) ||
                      (u.email ?? '').toLowerCase().contains(q);
                })
                .map(
                  (u) => DropdownMenuItem<String>(
                    value: u.id,
                    child: Text(
                      '${u.name ?? context.tr(vi: 'Không tên', en: 'No name')} (${u.email ?? ''})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              _updateForm(() {
                _selectedUserId = val;
              });
            },
          ),
          if (widget.usersCache.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr(
                  vi: 'Chưa có khách hàng đăng ký nào từng đặt sân tại khu liên hợp này.',
                  en: 'No registered customer has booked at this facility yet.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],

        if (_isLoadingSlots)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF5600)),
          )
        else if (_slotConfig != null) ...[
          Text(
            context.tr(vi: 'Khung giờ:', en: 'Time Slots:'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_slotConfig!.slots.length, (index) {
              final slot = _slotConfig!.slots[index];
              final isBooked = _bookedSlotIndices.contains(index);
              final isSelected = _selectedSlotIndex == index;

              final isDark = Theme.of(context).brightness == Brightness.dark;
              final Color color;
              final Color textColor;
              final Color borderColor;

              if (isBooked) {
                color = isDark
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.red.shade50;
                textColor = isDark ? Colors.red.shade300 : Colors.red.shade700;
                borderColor = Colors.red.withValues(alpha: 0.5);
              } else if (isSelected) {
                color = const Color(0xFFFF5600);
                textColor = Colors.white;
                borderColor = const Color(0xFFFF5600);
              } else {
                // Available
                color = isDark
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.green.shade50;
                textColor = isDark
                    ? Colors.green.shade300
                    : Colors.green.shade700;
                borderColor = Colors.green.withValues(alpha: 0.5);
              }

              return GestureDetector(
                onTap: isBooked
                    ? null
                    : () {
                        _updateForm(() => _selectedSlotIndex = index);
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    '${slot.startLabel}-${slot.endLabel}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<bool>(
          isExpanded: true,
          value: _isCash,
          decoration: InputDecoration(
            labelText: context.tr(
              vi: 'Phương thức thanh toán',
              en: 'Payment Method',
            ),
          ),
          items: [
            DropdownMenuItem(
              value: true,
              child: Text(
                context.tr(vi: 'Tiền mặt tại quầy', en: 'Cash at counter'),
              ),
            ),
            DropdownMenuItem(
              value: false,
              child: Text(
                context.tr(vi: 'Chuyển khoản online', en: 'Online transfer'),
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _isCash = val);
            }
          },
        ),
        if (_courtId != null && _selectedSlotIndex != null) ...[
          const SizedBox(height: 16),
          Text(
            '${context.tr(vi: 'Tổng tiền', en: 'Total Price')}: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(_totalPrice)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF5600),
              fontSize: 16,
            ),
          ),
        ],
      ],
    );
  }
}

class _RescheduleDialog extends StatefulWidget {
  final BookingDetailEntity booking;
  final VoidCallback onRescheduled;

  const _RescheduleDialog({required this.booking, required this.onRescheduled});

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  DateTime _date = DateTime.now();
  int? _selectedSlotIndex;
  SlotConfigEntity? _slotConfig;
  Set<int> _bookedSlotIndices = {};
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    final courtId = widget.booking.courtId;
    if (courtId == null) return;
    if (!mounted) return;
    setState(() {
      _isLoadingSlots = true;
      _selectedSlotIndex = null;
      _slotConfig = null;
      _bookedSlotIndices.clear();
    });
    try {
      final formattedDate =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      final useCase = GetIt.I<GetSlotConfigUseCase>();
      final res = await useCase(courtId, bookingDate: formattedDate);
      if (!mounted) return;
      if (res.success && res.data != null) {
        final config = res.data!;

        // Load booked slots
        final bookingUseCase = GetIt.I<GetBookingHistoryUseCase>();
        final bookingsRes = await bookingUseCase();
        if (!mounted) return;
        final booked = <int>{};
        if (bookingsRes.success && bookingsRes.data != null) {
          final courtBookings = bookingsRes.data!.where(
            (b) =>
                b.courtId == courtId &&
                b.bookingDate == formattedDate &&
                b.status != 'CANCELLED',
          );
          for (final b in courtBookings) {
            final bStart = b.startMinutes;
            final bEnd = b.endMinutes;
            if (bStart != null && bEnd != null) {
              for (int i = 0; i < config.slots.length; i++) {
                final slot = config.slots[i];
                if (slot.startMinutes < bEnd && slot.endMinutes > bStart) {
                  booked.add(i);
                }
              }
            }
          }
        }
        setState(() {
          _slotConfig = config;
          _bookedSlotIndices = booked;
        });
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoadingSlots = false);
  }

  Future<void> _submit() async {
    final courtId = widget.booking.courtId;
    if (courtId == null || _selectedSlotIndex == null || _slotConfig == null) {
      return;
    }
    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final language = context.read<LanguageCubit>().state;
    try {
      final slot = _slotConfig!.slots[_selectedSlotIndex!];
      final formattedDate =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

      final updateUseCase = GetIt.I<UpdateBookingUseCase>();
      final updateRes = await updateUseCase(
        widget.booking.id,
        courtId: courtId,
        bookingDate: formattedDate,
        startMinutes: slot.startMinutes,
        endMinutes: slot.endMinutes,
      );

      if (!mounted) return;
      if (updateRes.success && updateRes.data != null) {
        try {
          GetIt.I<AppNotificationEventBus>().emit(
            const AppNotificationEvent(
              type: AppNotificationEventType.bookingRescheduled,
            ),
          );
        } catch (e) {
          debugPrint('Error emitting reschedule events: $e');
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              language == 'vi'
                  ? 'Đổi lịch đặt sân thành công!'
                  : 'Booking rescheduled successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRescheduled();
        navigator.pop();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              updateRes.message ??
                  (language == 'vi'
                      ? 'Đổi lịch đặt sân thất bại.'
                      : 'Unable to reschedule booking.'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(language == 'vi' ? 'Lỗi: $e' : 'Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(context.tr(vi: 'Đổi lịch đặt sân', en: 'Reschedule Booking')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.tr(vi: 'Sân', en: 'Court')}: ${widget.booking.courtName ?? context.tr(vi: 'Sân đấu', en: 'Court')}',
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(vi: 'Chọn ngày mới:', en: 'Select new date:'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) {
                  setState(() => _date = picked);
                  _loadSlots();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateDisplayFormatter.date(_date)),
                    const Icon(Icons.calendar_month, color: Color(0xFFFF5600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(
                vi: 'Chọn khung giờ mới:',
                en: 'Select new time slot:',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            if (_isLoadingSlots)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF5600)),
              )
            else if (_slotConfig == null || _slotConfig!.slots.isEmpty)
              Text(
                context.tr(
                  vi: 'Không tìm thấy khung giờ hoạt động.',
                  en: 'No active time slots found.',
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_slotConfig!.slots.length, (index) {
                  final slot = _slotConfig!.slots[index];
                  final isBooked = _bookedSlotIndices.contains(index);
                  final isSelected = _selectedSlotIndex == index;

                  Color color = Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest;
                  Color textColor = Theme.of(context).colorScheme.onSurface;
                  if (isBooked) {
                    color = Colors.red.shade50;
                    textColor = Colors.red.shade300;
                  } else if (isSelected) {
                    color = const Color(0xFFFF5600);
                    textColor = Colors.white;
                  }

                  return GestureDetector(
                    onTap: isBooked
                        ? null
                        : () {
                            setState(() => _selectedSlotIndex = index);
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF5600)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        '${slot.startLabel}-${slot.endLabel}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr(vi: 'Hủy', en: 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _selectedSlotIndex == null || _isSubmitting
              ? null
              : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5600),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  context.tr(vi: 'Đổi lịch', en: 'Reschedule'),
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
