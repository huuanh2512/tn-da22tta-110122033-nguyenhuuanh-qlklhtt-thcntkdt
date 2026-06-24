// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:server_module/server_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:authentication_module/authentication_module.dart';
import '../../domain/entities/booking_court_model.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../../domain/usecases/get_slot_config_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/create_fixed_schedule_usecase.dart';
import '../widgets/ios_date_navigator.dart';
import 'package:review_module/review_module.dart';
import 'package:notification_module/notification_module.dart';

class CourtBookingPage extends StatefulWidget {
  final String courtId;
  final CourtEntity? court;
  final int? initialStartMinutes;

  const CourtBookingPage({
    super.key,
    required this.courtId,
    this.court,
    this.initialStartMinutes,
  });

  @override
  State<CourtBookingPage> createState() => _CourtBookingPageState();
}

class _CourtBookingPageState extends State<CourtBookingPage> {
  static const _primaryColor = Color(0xFFFF5600);
  static const _customerBookingLeadTime = Duration(minutes: 10);

  // ── State ──────────────────────────────────────────────────────────────
  late DateTime _selectedDate;
  FacilityEntity? _facility;
  String _userRole = 'customer';

  SlotConfigEntity? _slotConfig;
  bool _isLoadingSlots = false;
  String? _slotError;

  int? _selectedSlotIndex;

  bool _isBooking = false;

  // Parameters for Fixed Schedule (Giờ chết)
  bool _isFixedSchedule = false;
  String _frequency = 'WEEKLY'; // 'DAILY' or 'WEEKLY'
  final Set<int> _daysOfWeek = {}; // 0=Sunday, 1=Monday, etc.
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isInfiniteEndDate = false;
  TimeOfDay? _customStartTime;
  TimeOfDay? _customEndTime;
  String _fixedMatchingTeamMode = 'TEAM_FILL';
  int _fixedMatchingTeamSize = 5;
  String _fixedMatchingHostTeam = 'A';
  int _fixedMatchingHostRepresentedCount = 1;
  String _fixedMatchingPaymentPolicy = 'SPLIT_EQUALLY';

  // ── Helpers ─────────────────────────────────────────────────────────────
  int? get _pricePerHour {
    final c = widget.court;
    if (c is BookingCourtModel) return c.pricePerHour;
    return null;
  }

  double get _totalPrice {
    if (_selectedSlotIndex == null || _slotConfig == null) {
      if (_isFixedSchedule &&
          _customStartTime != null &&
          _customEndTime != null) {
        final price = _pricePerHour;
        if (price == null) return 0;
        final startMin = _customStartTime!.hour * 60 + _customStartTime!.minute;
        final endMin = _customEndTime!.hour * 60 + _customEndTime!.minute;
        final durationMinutes = endMin - startMin;
        if (durationMinutes <= 0) return 0;
        return price * durationMinutes / 60.0;
      }
      return 0;
    }
    final price = _pricePerHour;
    if (price == null) return 0;
    // Mỗi slot = slotDurationMinutes phút; pricePerHour tính theo giờ
    final durationMinutes = _slotConfig?.slotDurationMinutes ?? 60;
    return price * durationMinutes / 60.0;
  }

  String _formatBookingDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isCustomerSlotTooClose(SlotEntity slot, DateTime now) {
    if (_userRole != 'customer') return false;
    final startAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      slot.startMinutes ~/ 60,
      slot.startMinutes % 60,
    );
    return startAt.difference(now) <= _customerBookingLeadTime;
  }

  String _formatPrice(BuildContext context, double price) {
    final intPrice = price.toInt();
    final s = intPrice.toString();
    final result = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write('.');
      result.write(s[i]);
    }
    return context.tr(
      vi: '${result.toString()} đ',
      en: '${result.toString()} VND',
    );
  }

  // ── Life-cycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 30));
    _loadUserRole();
    _loadSlotConfig();
    _loadFacilityInfo();
  }

  Future<void> _loadUserRole() async {
    try {
      final result = await GetIt.I<GetLocalUserUseCase>()();
      result.fold((_) {}, (user) {
        if (mounted) {
          setState(() {
            _userRole = user.role?.toLowerCase() ?? 'customer';
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading user role: $e');
    }
  }

  Future<void> _loadFacilityInfo() async {
    final facilityId = widget.court?.facilityId;
    if (facilityId == null) return;
    try {
      final useCase = GetIt.I<GetFacilitiesUseCase>();
      final response = await useCase();
      if (response.success && response.data != null) {
        final matches = response.data!.where((f) => f.id == facilityId);
        if (matches.isNotEmpty) {
          setState(() {
            _facility = matches.first;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading facility info: $e');
    }
  }

  Future<void> _loadSlotConfig() async {
    setState(() {
      _isLoadingSlots = true;
      _slotError = null;
      _selectedSlotIndex = null;
    });
    try {
      final useCase = GetIt.I<GetSlotConfigUseCase>();
      final response = await useCase(
        widget.courtId,
        bookingDate: _formatBookingDate(_selectedDate),
      );
      if (response.success && response.data != null) {
        final config = response.data!;

        int? selectedIdx;
        if (widget.initialStartMinutes != null && config.slots.isNotEmpty) {
          final now = DateTime.now();
          final todayStr = _formatBookingDate(now);
          final selectedStr = _formatBookingDate(_selectedDate);
          for (int i = 0; i < config.slots.length; i++) {
            final slot = config.slots[i];
            if (slot.startMinutes == widget.initialStartMinutes) {
              bool isPast = false;
              if (todayStr == selectedStr) {
                final currentMinutes = now.hour * 60 + now.minute;
                if (slot.startMinutes < currentMinutes) {
                  isPast = true;
                }
              }
              final isTooClose = _isCustomerSlotTooClose(slot, now);
              final isAvailable = slot.isAvailable && !isPast && !isTooClose;
              if (isAvailable) {
                selectedIdx = i;
              }
              break;
            }
          }
        }

        setState(() {
          _slotConfig = config;
          if (selectedIdx != null) {
            _selectedSlotIndex = selectedIdx;
          }
        });
      } else {
        setState(
          () => _slotError =
              response.message ??
              context.tr(
                vi: 'Không thể tải khung giờ',
                en: 'Unable to load slots',
              ),
        );
      }
    } catch (e) {
      setState(
        () => _slotError = context.tr(
          vi: 'Lỗi tải khung giờ: $e',
          en: 'Error loading slots: $e',
        ),
      );
    } finally {
      setState(() => _isLoadingSlots = false);
    }
  }

  void _toggleSlot(int index) {
    setState(() {
      if (_selectedSlotIndex == index) {
        _selectedSlotIndex = null;
        _customStartTime = null;
        _customEndTime = null;
      } else {
        _selectedSlotIndex = index;
        if (_slotConfig != null && index < _slotConfig!.slots.length) {
          final slot = _slotConfig!.slots[index];
          _customStartTime = TimeOfDay(
            hour: slot.startMinutes ~/ 60,
            minute: slot.startMinutes % 60,
          );
          _customEndTime = TimeOfDay(
            hour: slot.endMinutes ~/ 60,
            minute: slot.endMinutes % 60,
          );
        }
      }
    });
  }

  Future<void> _confirmBooking() async {
    if (_selectedSlotIndex == null &&
        !(_isFixedSchedule &&
            _customStartTime != null &&
            _customEndTime != null)) {
      return;
    }

    final config = _slotConfig;
    if (config == null && !_isFixedSchedule) {
      return;
    }

    int startMinutes;
    int endMinutes;

    if (_isFixedSchedule) {
      if (_customStartTime != null && _customEndTime != null) {
        startMinutes = _customStartTime!.hour * 60 + _customStartTime!.minute;
        endMinutes = _customEndTime!.hour * 60 + _customEndTime!.minute;
      } else {
        final slot = config!.slots[_selectedSlotIndex!];
        startMinutes = slot.startMinutes;
        endMinutes = slot.endMinutes;
      }
      if (_frequency == 'WEEKLY' && _daysOfWeek.isEmpty) {
        _showError(
          context.tr(
            vi: 'Vui lòng chọn ít nhất một thứ trong tuần.',
            en: 'Please select at least one day of the week.',
          ),
        );
        return;
      }
      if (endMinutes <= startMinutes) {
        _showError(
          context.tr(
            vi: 'Giờ kết thúc phải sau giờ bắt đầu.',
            en: 'End time must be after start time.',
          ),
        );
        return;
      }
    } else {
      final slot = config!.slots[_selectedSlotIndex!];
      startMinutes = slot.startMinutes;
      endMinutes = slot.endMinutes;
    }

    setState(() => _isBooking = true);
    try {
      if (_isFixedSchedule) {
        final useCase = GetIt.I<CreateFixedScheduleUseCase>();
        final response = await useCase({
          "type": "COURT_BOOKING",
          "sportId": widget.court?.sportId ?? "",
          "facilityId": widget.court?.facilityId ?? "",
          "courtId": widget.courtId,
          "startMinutes": startMinutes,
          "endMinutes": endMinutes,
          "frequency": _frequency,
          if (_frequency == 'WEEKLY')
            "daysOfWeek": _daysOfWeek.toList()..sort(),
          "startDate": _formatBookingDate(_startDate ?? _selectedDate),
          "endDate": _isInfiniteEndDate
              ? null
              : _formatBookingDate(
                  _endDate ?? _selectedDate.add(const Duration(days: 30)),
                ),
        });

        if (!mounted) return;

        if (response.success) {
          try {
            GetIt.I<AppNotificationEventBus>().emit(
              const AppNotificationEvent(
                type: AppNotificationEventType.bookingCreated,
              ),
            );
          } catch (e) {
            debugPrint('Error emitting event: $e');
          }

          if (response.data != null && response.data!.user != null) {
            try {
              await GetIt.I<CreateNotificationUseCase>().call(
                userId: response.data!.user!.id,
                title: context.tr(
                  vi: 'Đăng ký lịch cố định thành công',
                  en: 'Fixed schedule registered',
                ),
                body: context.tr(
                  vi: 'Gói đăng ký lịch cố định của bạn đã được gửi thành công.',
                  en: 'Your fixed schedule booking package has been submitted successfully.',
                ),
                type: 'BOOKING',
              );
              GetIt.I<NotificationCubit>().loadNotifications();
            } catch (e) {
              debugPrint('Error creating notification: $e');
            }
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr(
                        vi: 'Đăng ký lịch cố định thành công! Vui lòng chờ nhân viên duyệt.',
                        en: 'Fixed schedule registered successfully! Please wait for staff approval.',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF55E277),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          context.go('/home?tab=history');
        } else {
          _showError(
            response.message ??
                context.tr(
                  vi: 'Đăng ký lịch cố định thất bại.',
                  en: 'Fixed schedule registration failed.',
                ),
          );
        }
      } else {
        final useCase = GetIt.I<CreateBookingUseCase>();
        final response = await useCase(
          courtId: widget.courtId,
          bookingDate: _formatBookingDate(_selectedDate),
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          totalPrice: _totalPrice,
        );

        if (!mounted) return;

        if (response.success) {
          try {
            GetIt.I<AppNotificationEventBus>().emit(
              const AppNotificationEvent(
                type: AppNotificationEventType.bookingCreated,
              ),
            );
          } catch (e) {
            debugPrint('Error emitting event: $e');
          }

          if (response.data != null && response.data!.userId != null) {
            try {
              await GetIt.I<CreateNotificationUseCase>().call(
                userId: response.data!.userId!,
                title: context.tr(
                  vi: 'Đặt sân thành công',
                  en: 'Booking successful',
                ),
                body: context.tr(
                  vi: 'Lịch đặt sân của bạn vào ngày ${_formatBookingDate(_selectedDate)} đã được gửi và đang chờ duyệt.',
                  en: 'Your booking on ${_formatBookingDate(_selectedDate)} has been submitted and is pending approval.',
                ),
                type: 'BOOKING',
              );
              GetIt.I<NotificationCubit>().loadNotifications();
            } catch (e) {
              debugPrint('Error creating notification: $e');
            }
          }
          if (!mounted) return;
          final isStaff = _userRole == 'staff';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isStaff
                          ? context.tr(
                              vi: 'Tạo đơn đặt sân thành công!',
                              en: 'Booking created successfully!',
                            )
                          : context.tr(
                              vi: 'Đặt sân thành công! Vui lòng chờ nhân viên duyệt.',
                              en: 'Booking successful! Please wait for staff approval.',
                            ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF55E277),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          if (isStaff) {
            context.go('/home');
          } else {
            context.go('/home?tab=payment');
          }
        } else {
          _showError(
            response.message ??
                context.tr(
                  vi: 'Đặt sân thất bại. Vui lòng thử lại.',
                  en: 'Booking failed. Please try again.',
                ),
          );
        }
      }
    } catch (e) {
      _showError(context.tr(vi: 'Lỗi kết nối: $e', en: 'Connection error: $e'));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final court = widget.court;
    final courtName = court?.name ?? context.tr(vi: 'Sân đấu', en: 'Court');

    final price = _pricePerHour;
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── AppBar gradient ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _primaryColor,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF5600), Color(0xFFcc3300)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          courtName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (price != null)
                              Text(
                                '${_formatPrice(context, price.toDouble())}${context.tr(vi: '/giờ', en: '/hour')}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date picker ──────────────────────────────────────────
                _buildSectionLabel(
                  context.tr(vi: 'CHỌN NGÀY', en: 'SELECT DATE'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: IosDateNavigator(
                    selectedDate: _selectedDate,
                    minDate: DateTime(today.year, today.month, today.day),
                    maxDate: DateTime(today.year, 12, 31),
                    onDateChanged: (date) {
                      setState(() {
                        _selectedDate = date;
                      });
                      _loadSlotConfig();
                    },
                    enabled: !_isLoadingSlots && !_isBooking,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Slot grid ────────────────────────────────────────────
                _buildSectionLabel(
                  context.tr(
                    vi: 'KHUNG GIỜ (CHỌN 1 KHUNG GIỜ)',
                    en: 'TIME SLOTS (SELECT 1 SLOT)',
                  ),
                ),
                _buildSlotArea(),

                // ── Fixed schedule config ──────────────────────────────────
                _buildSectionLabel(
                  context.tr(vi: 'LOẠI LỊCH ĐẶT', en: 'BOOKING TYPE'),
                ),
                _buildBookingTypeSelector(),
                if (_isFixedSchedule) _buildFixedScheduleConfigForm(),

                // ── Reviews list ──────────────────────────────────────────
                _buildSectionLabel(
                  context.tr(vi: 'ĐÁNH GIÁ SÂN', en: 'COURT REVIEWS'),
                ),
                ReviewsListWidget(courtId: widget.courtId),

                // Spacing for bottom bar
                const SizedBox(height: 140),
              ],
            ),
          ),
        ],
      ),

      // ── Bottom confirm bar ─────────────────────────────────────────────
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildSectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Colors.grey.shade500,
      ),
    ),
  );

  // ── Slot area ─────────────────────────────────────────────────────────────
  Widget _buildSlotArea() {
    if (_isLoadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (_slotError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.red.shade300),
              const SizedBox(height: 8),
              Text(
                _slotError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadSlotConfig,
                child: Text(
                  context.tr(vi: 'Thử lại', en: 'Retry'),
                  style: const TextStyle(color: _primaryColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final config = _slotConfig;
    if (config == null || config.slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  vi: 'Sân này chưa có khung giờ',
                  en: 'No time slots available for this court',
                ),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
        ),
        itemCount: config.slots.length,
        itemBuilder: (_, i) => _buildSlotChip(i, config.slots[i]),
      ),
    );
  }

  Widget _buildSlotChip(int index, SlotEntity slot) {
    final theme = Theme.of(context);
    final isSelected = _selectedSlotIndex == index;

    final now = DateTime.now();
    final todayStr = _formatBookingDate(now);
    final selectedStr = _formatBookingDate(_selectedDate);
    bool isPast = false;
    if (todayStr == selectedStr) {
      final currentMinutes = now.hour * 60 + now.minute;
      if (slot.startMinutes < currentMinutes) {
        isPast = true;
      }
    }
    final isTooClose = _isCustomerSlotTooClose(slot, now);
    final isAvailable = slot.isAvailable && !isPast && !isTooClose;
    final isFixedScheduleReserved = slot.status == 'FIXED_SCHEDULE_RESERVED';
    final isBooked = slot.status == 'BOOKED';

    Color bgColor;
    Color textColor;
    Color borderColor;
    Color statusColor;
    String statusLabel;

    if (isPast) {
      bgColor = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      );
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
      borderColor = theme.colorScheme.outline.withValues(alpha: 0.15);
      statusColor = Colors.grey.shade400;
      statusLabel = context.tr(vi: 'Đã qua', en: 'Past');
    } else if (isFixedScheduleReserved) {
      bgColor = const Color(0xFFEFF4F8);
      textColor = const Color(0xFF37474F);
      borderColor = const Color(0xFF78909C);
      statusColor = const Color(0xFF455A64);
      statusLabel = context.tr(vi: 'Lịch cố định', en: 'Fixed schedule');
    } else if (isBooked) {
      bgColor = const Color(0xFFFFF1F0);
      textColor = const Color(0xFFC62828);
      borderColor = const Color(0xFFE57373);
      statusColor = const Color(0xFFC62828);
      statusLabel = context.tr(vi: 'Đã đặt', en: 'Booked');
    } else if (isTooClose) {
      bgColor = const Color(0xFFFFF8E1);
      textColor = const Color(0xFFF57F17);
      borderColor = const Color(0xFFFFCA28);
      statusColor = const Color(0xFFF57F17);
      statusLabel = context.tr(vi: 'Sắp bắt đầu', en: 'Starting soon');
    } else if (!isAvailable) {
      bgColor = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      );
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);
      borderColor = theme.colorScheme.outline.withValues(alpha: 0.2);
      statusColor = Colors.grey.shade500;
      statusLabel = context.tr(vi: 'Không hoạt động', en: 'Inactive');
    } else if (isSelected) {
      bgColor = _primaryColor.withOpacity(0.08);
      textColor = _primaryColor;
      borderColor = _primaryColor;
      statusColor = _primaryColor;
      statusLabel = context.tr(vi: 'Đã chọn', en: 'Selected');
    } else {
      bgColor = Theme.of(context).cardColor;
      textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
      borderColor = Theme.of(context).dividerColor.withOpacity(0.2);
      statusColor = const Color(0xFF2E7D32);
      statusLabel = context.tr(vi: 'Còn trống', en: 'Available');
    }

    return GestureDetector(
      onTap: isAvailable ? () => _toggleSlot(index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${slot.startLabel}–${slot.endLabel}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final hasSelection =
        _selectedSlotIndex != null ||
        (_isFixedSchedule &&
            _customStartTime != null &&
            _customEndTime != null);
    final total = _totalPrice;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSelection) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.sports_soccer_rounded,
                        color: _primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.court?.name ??
                              context.tr(vi: 'Sân đấu', en: 'Court'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_facility != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: _primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_facility!.name} - ${_facility!.address ?? ''}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: _primaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_formatBookingDate(_selectedDate)} | ${_buildSelectedSlotsLabel()}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isFixedSchedule
                          ? context.tr(
                              vi: 'Đơn giá/buổi',
                              en: 'Unit price/session',
                            )
                          : context.tr(vi: 'Tổng tiền', en: 'Total price'),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      hasSelection
                          ? _formatPrice(context, total)
                          : context.tr(vi: '0 đ', en: '0 VND'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: hasSelection && !_isBooking
                      ? _confirmBooking
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: hasSelection ? 4 : 0,
                  ),
                  child: _isBooking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isFixedSchedule
                              ? context.tr(
                                  vi: 'Đăng ký lịch cố định',
                                  en: 'Register Fixed Schedule',
                                )
                              : context.tr(
                                  vi: 'Xác nhận đặt',
                                  en: 'Confirm Booking',
                                ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildSelectedSlotsLabel() {
    if (_isFixedSchedule &&
        _customStartTime != null &&
        _customEndTime != null) {
      final startStr =
          '${_customStartTime!.hour.toString().padLeft(2, '0')}:${_customStartTime!.minute.toString().padLeft(2, '0')}';
      final endStr =
          '${_customEndTime!.hour.toString().padLeft(2, '0')}:${_customEndTime!.minute.toString().padLeft(2, '0')}';
      return '$startStr – $endStr';
    }
    final config = _slotConfig;
    if (config == null || _selectedSlotIndex == null) return '';
    final slot = config.slots[_selectedSlotIndex!];
    return '${slot.startLabel} – ${slot.endLabel}';
  }

  Widget _buildBookingTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: Container(
                width: double.infinity,
                alignment: Alignment.center,
                child: Text(
                  context.tr(vi: 'Đặt một lần', en: 'One-time'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              selected: !_isFixedSchedule,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _isFixedSchedule = false;
                  });
                }
              },
              selectedColor: _primaryColor.withOpacity(0.12),
              checkmarkColor: _primaryColor,
              labelStyle: TextStyle(
                color: !_isFixedSchedule ? _primaryColor : Colors.grey,
              ),
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: !_isFixedSchedule
                      ? _primaryColor
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ChoiceChip(
              label: Container(
                width: double.infinity,
                alignment: Alignment.center,
                child: Text(
                  context.tr(
                    vi: 'Đặt cố định (Giờ chết)',
                    en: 'Fixed Schedule',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              selected: _isFixedSchedule,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _isFixedSchedule = true;
                    _startDate ??= _selectedDate;
                  });
                }
              },
              selectedColor: _primaryColor.withOpacity(0.12),
              checkmarkColor: _primaryColor,
              labelStyle: TextStyle(
                color: _isFixedSchedule ? _primaryColor : Colors.grey,
              ),
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _isFixedSchedule
                      ? _primaryColor
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrongChoiceChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    double? minWidth,
  }) {
    return ChoiceChip(
      label: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth ?? 0),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      selectedColor: _primaryColor,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.grey.shade900,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? _primaryColor : Colors.grey.shade400,
          width: selected ? 1.6 : 1,
        ),
      ),
      elevation: selected ? 2 : 0,
      pressElevation: 0,
    );
  }

  Widget _buildFixedScheduleConfigForm() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primaryColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryColor.withOpacity(0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.event_repeat_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr(
                        vi: 'Màn này chỉ tạo lịch đặt sân cố định. Lịch ghép cố định đã được chuyển sang màn Tạo phòng ghép.',
                        en: 'This screen only creates fixed court bookings. Fixed matching schedules are now created from Create match lobby.',
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              context.tr(vi: 'TẦN SUẤT LẶP', en: 'FREQUENCY'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: Text(context.tr(vi: 'Hàng tuần', en: 'Weekly')),
                  selected: _frequency == 'WEEKLY',
                  onSelected: (val) {
                    if (val) {
                      setState(() => _frequency = 'WEEKLY');
                    }
                  },
                  selectedColor: _primaryColor.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: _frequency == 'WEEKLY'
                        ? _primaryColor
                        : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(context.tr(vi: 'Hàng ngày', en: 'Daily')),
                  selected: _frequency == 'DAILY',
                  onSelected: (val) {
                    if (val) {
                      setState(() => _frequency = 'DAILY');
                    }
                  },
                  selectedColor: _primaryColor.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: _frequency == 'DAILY' ? _primaryColor : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_frequency == 'WEEKLY') ...[
              Text(
                context.tr(
                  vi: 'THỨ TRONG TUẦN LẶP LẠI',
                  en: 'REPEAT DAYS OF WEEK',
                ),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              _buildWeekdayPicker(),
              const SizedBox(height: 16),
            ],

            Text(
              context.tr(vi: 'THỜI GIAN HIỆU LỰC', en: 'VALIDITY PERIOD'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickStartDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(vi: 'Ngày bắt đầu', en: 'Start Date'),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _startDate != null
                                ? DateDisplayFormatter.date(_startDate!)
                                : '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (!_isInfiniteEndDate)
                  Expanded(
                    child: InkWell(
                      onTap: _pickEndDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(vi: 'Ngày kết thúc', en: 'End Date'),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _endDate != null
                                  ? DateDisplayFormatter.date(_endDate!)
                                  : '',
                              style: const TextStyle(
                                fontSize: 13,
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
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _isInfiniteEndDate,
                  activeColor: _primaryColor,
                  onChanged: (val) {
                    setState(() {
                      _isInfiniteEndDate = val ?? false;
                    });
                  },
                ),
                Text(
                  context.tr(
                    vi: 'Hiệu lực vô hạn (Không ngày kết thúc)',
                    en: 'Infinite validity (No end date)',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              context.tr(vi: 'KHUNG GIỜ CHƠI CỐ ĐỊNH', en: 'PLAY TIME SLOT'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isStart: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(vi: 'Giờ bắt đầu', en: 'Start Time'),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _customStartTime != null
                                ? '${_customStartTime!.hour.toString().padLeft(2, '0')}:${_customStartTime!.minute.toString().padLeft(2, '0')}'
                                : '--:--',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isStart: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(vi: 'Giờ kết thúc', en: 'End Time'),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _customEndTime != null
                                ? '${_customEndTime!.hour.toString().padLeft(2, '0')}:${_customEndTime!.minute.toString().padLeft(2, '0')}'
                                : '--:--',
                            style: const TextStyle(
                              fontSize: 13,
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
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFixedMatchingConfigForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(vi: 'CẤU HÌNH GHÉP ĐỘI', en: 'MATCHING CONFIG'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStrongChoiceChip(
                label: context.tr(vi: 'Tuyển đủ đội', en: 'Team fill'),
                selected: _fixedMatchingTeamMode == 'TEAM_FILL',
                onSelected: (val) {
                  if (val) {
                    setState(() => _fixedMatchingTeamMode = 'TEAM_FILL');
                  }
                },
              ),
              _buildStrongChoiceChip(
                label: context.tr(vi: 'Đội đấu đội', en: 'Team vs team'),
                selected: _fixedMatchingTeamMode == 'TEAM_VS_TEAM',
                onSelected: (val) {
                  if (val) {
                    setState(() => _fixedMatchingTeamMode = 'TEAM_VS_TEAM');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberStepper(
                  label: context.tr(vi: 'Số người/đội', en: 'Team size'),
                  value: _fixedMatchingTeamSize,
                  min: 1,
                  max: 30,
                  onChanged: (value) =>
                      setState(() => _fixedMatchingTeamSize = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildNumberStepper(
                  label: context.tr(vi: 'Bạn đại diện', en: 'Representing'),
                  value: _fixedMatchingHostRepresentedCount,
                  min: 1,
                  max: _fixedMatchingTeamSize,
                  onChanged: (value) => setState(
                    () => _fixedMatchingHostRepresentedCount = value,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(vi: 'Đội của chủ lịch', en: 'Host team'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['A', 'B'].map((team) {
              return _buildStrongChoiceChip(
                label: 'Team $team',
                selected: _fixedMatchingHostTeam == team,
                minWidth: 88,
                onSelected: (val) {
                  if (val) {
                    setState(() => _fixedMatchingHostTeam = team);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(vi: 'Thanh toán', en: 'Payment'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _fixedMatchingPaymentPolicy,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: 'HOST_PAY_ALL',
                child: Text(
                  context.tr(vi: 'Host trả hết', en: 'Host pays all'),
                ),
              ),
              DropdownMenuItem(
                value: 'SPLIT_EQUALLY',
                child: Text(
                  context.tr(
                    vi: 'Chia đều theo tài khoản app',
                    en: 'Split equally',
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'TEAM_REPRESENTATIVES_SPLIT',
                child: Text(
                  context.tr(
                    vi: 'Đại diện hai đội chia đôi',
                    en: 'Team reps split',
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _fixedMatchingPaymentPolicy = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNumberStepper({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              InkWell(
                onTap: value > min ? () => onChanged(value - 1) : null,
                child: Icon(
                  Icons.remove_circle_outline,
                  size: 22,
                  color: value > min ? _primaryColor : Colors.grey.shade300,
                ),
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: value < max ? () => onChanged(value + 1) : null,
                child: Icon(
                  Icons.add_circle_outline,
                  size: 22,
                  color: value < max ? _primaryColor : Colors.grey.shade300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayPicker() {
    final days = [
      {'val': 1, 'label': context.tr(vi: 'T2', en: 'M')},
      {'val': 2, 'label': context.tr(vi: 'T3', en: 'T')},
      {'val': 3, 'label': context.tr(vi: 'T4', en: 'W')},
      {'val': 4, 'label': context.tr(vi: 'T5', en: 'T')},
      {'val': 5, 'label': context.tr(vi: 'T6', en: 'F')},
      {'val': 6, 'label': context.tr(vi: 'T7', en: 'S')},
      {'val': 0, 'label': context.tr(vi: 'CN', en: 'S')},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((day) {
        final val = day['val'] as int;
        final label = day['label'] as String;
        final isSelected = _daysOfWeek.contains(val);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _daysOfWeek.remove(val);
              } else {
                _daysOfWeek.add(val);
              }
            });
          },
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? _primaryColor : Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? _primaryColor : Colors.grey.shade300,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  void _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _selectedDate.add(const Duration(days: 30)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _pickTime({required bool isStart}) async {
    final initialTime = isStart
        ? (_customStartTime ?? const TimeOfDay(hour: 18, minute: 0))
        : (_customEndTime ?? const TimeOfDay(hour: 20, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStartTime = picked;
        } else {
          _customEndTime = picked;
        }
      });
    }
  }
}
