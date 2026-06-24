// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:server_module/server_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:booking_module/domain/usecases/get_courts_usecase.dart';
import 'package:booking_module/domain/usecases/get_slot_config_usecase.dart';
import 'package:booking_module/domain/usecases/get_booking_history_usecase.dart';
import 'package:booking_module/domain/entities/slot_config_entity.dart';
import 'package:booking_module/domain/entities/booking_detail_entity.dart';
import 'package:booking_module/domain/entities/booking_court_model.dart';
import 'package:booking_module/presentation/widgets/ios_date_navigator.dart';
import 'dart:async';
import 'package:notification_module/notification_module.dart';

class CustomerBookingCatalogSection extends StatefulWidget {
  final String role; // 'customer' hoặc 'staff'
  final bool isShortVersion;
  final String? facilityId;
  final String? sportId;
  final int pageSize;

  const CustomerBookingCatalogSection({
    super.key,
    required this.role,
    this.isShortVersion = true,
    this.facilityId,
    this.sportId,
    this.pageSize = 5,
  });

  @override
  State<CustomerBookingCatalogSection> createState() =>
      _CustomerBookingCatalogSectionState();
}

class _CustomerBookingCatalogSectionState
    extends State<CustomerBookingCatalogSection> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedSportCategoryId;

  List<CourtEntity> _courts = [];
  List<SportEntity> _sports = [];
  List<FacilityEntity> _facilities = [];
  List<BookingDetailEntity> _bookings = [];
  Map<String, SlotConfigEntity> _courtConfigs = {};

  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _eventSubscription;

  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _selectedSportCategoryId = widget.sportId;
    _loadData();
    _subscribeEvents();
  }

  void _subscribeEvents() {
    try {
      _eventSubscription = GetIt.I<AppNotificationEventBus>().stream.listen((
        event,
      ) {
        if (mounted) {
          _loadData();
        }
      });
    } catch (e) {
      debugPrint(
        'Error subscribing to EventBus in CustomerBookingCatalogSection: $e',
      );
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  String _formatDateQuery(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Chỉ tải dữ liệu nền. Danh sách sân được tải sau khi chọn môn.
      final results = await Future.wait([
        GetIt.I<GetSportsUseCase>().call(),
        GetIt.I<GetFacilitiesUseCase>().call(),
        GetIt.I<GetBookingHistoryUseCase>().call(),
      ]);

      final sportsResponse = results[0] as BaseResponse<List<SportEntity>>;
      final facilitiesResponse =
          results[1] as BaseResponse<List<FacilityEntity>>;
      final bookingsResponse =
          results[2] as BaseResponse<List<BookingDetailEntity>>;

      if (!sportsResponse.success || !facilitiesResponse.success) {
        if (!mounted) return;
        setState(() {
          _errorMessage = context.tr(
            vi: "Không thể tải dữ liệu từ máy chủ. Vui lòng kiểm tra lại.",
            en: "Unable to load data from server. Please check again.",
          );
          _isLoading = false;
        });
        return;
      }

      final sports = sportsResponse.data ?? [];
      final facilities = facilitiesResponse.data ?? [];
      final bookings = bookingsResponse.data ?? [];

      if (!mounted) return;
      setState(() {
        _sports = sports;
        _facilities = facilities;
        _bookings = bookings;
        _courts = [];
        _courtConfigs = {};
        _isLoading = false;
      });

      if (_selectedSportCategoryId != null) {
        await _loadSelectedSportCourts();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          vi: "Đã xảy ra lỗi khi tải dữ liệu: $e",
          en: "An error occurred while loading data: $e",
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSelectedSportCourts() async {
    final sportId = _selectedSportCategoryId;
    if (sportId == null) {
      setState(() {
        _courts = [];
        _courtConfigs = {};
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _courts = [];
      _courtConfigs = {};
    });

    try {
      final courtsResponse = await GetIt.I<GetCourtsUseCase>().call(
        facilityId: widget.facilityId,
        sportId: sportId,
      );
      if (!courtsResponse.success) {
        throw Exception(
          courtsResponse.message ?? 'Không thể tải danh sách sân',
        );
      }

      final activeCourts = (courtsResponse.data ?? [])
          .where((court) => court.status == 'ACTIVE')
          .toList();
      final formattedDate = _formatDateQuery(_selectedDate);
      final responses = await Future.wait(
        activeCourts.map(
          (court) => GetIt.I<GetSlotConfigUseCase>().call(
            court.id,
            bookingDate: formattedDate,
          ),
        ),
      );

      final configs = <String, SlotConfigEntity>{};
      for (var index = 0; index < activeCourts.length; index++) {
        final response = responses[index];
        if (response.success && response.data != null) {
          configs[activeCourts[index].id] = response.data!;
        }
      }

      if (!mounted || sportId != _selectedSportCategoryId) return;
      setState(() {
        _courts = activeCourts;
        _courtConfigs = configs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || sportId != _selectedSportCategoryId) return;
      setState(() {
        _errorMessage = context.tr(
          vi: 'Không thể tải danh sách sân: $e',
          en: 'Unable to load courts: $e',
        );
        _isLoading = false;
      });
    }
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
      _currentPage = 1;
    });
    if (_selectedSportCategoryId != null) {
      _loadSelectedSportCourts();
    }
  }

  String _formatPrice(BuildContext context, int? price) {
    if (price == null) return context.tr(vi: '0 đ', en: '0 VND');
    final s = price.toString();
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

  String _minutesToHHmm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // Phân loại trạng thái slot
  // 0: Available, 1: Booked, 2: Pending, 3: Unavailable, 4: Past,
  // 5: Reserved by an active fixed schedule.
  int _getSlotState(CourtEntity court, SlotEntity slot) {
    if (slot.status == 'FIXED_SCHEDULE_RESERVED') {
      return 5;
    }
    if (slot.status == 'BOOKED') {
      return 1;
    }

    // 1. Kiểm tra slot có bị khóa/bảo trì từ cấu hình không
    if (!slot.isAvailable) {
      return 3;
    }

    // 2. Kiểm tra slot trong quá khứ (nếu ngày được chọn là hôm nay)
    final now = DateTime.now();
    final todayStr = _formatDateQuery(now);
    final selectedStr = _formatDateQuery(_selectedDate);
    if (todayStr == selectedStr) {
      final currentMinutes = now.hour * 60 + now.minute;
      if (slot.startMinutes < currentMinutes) {
        return 4;
      }
    }

    // 3. Đối chiếu danh sách đặt lịch để tìm trạng thái Đã đặt hoặc Chờ xác nhận
    final formattedDate = _formatDateQuery(_selectedDate);
    final courtBookings = _bookings.where(
      (b) =>
          b.courtId == court.id &&
          b.bookingDate == formattedDate &&
          b.status != 'CANCELLED',
    );

    for (final booking in courtBookings) {
      final bStart = booking.startMinutes;
      final bEnd = booking.endMinutes;
      if (bStart != null && bEnd != null) {
        // Kiểm tra xem slot có giao nhau với booking không
        if (slot.startMinutes < bEnd && slot.endMinutes > bStart) {
          if (booking.status == 'PENDING') {
            return 2; // Pending
          } else if (booking.status == 'CONFIRMED' ||
              booking.status == 'COMPLETED') {
            return 1; // Booked
          }
        }
      }
    }

    return 0; // Available
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final endOfYear = DateTime(today.year, 12, 31);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. iOS Date Navigator
        IosDateNavigator(
          selectedDate: _selectedDate,
          minDate: DateTime(today.year, today.month, today.day),
          maxDate: endOfYear,
          onDateChanged: _onDateChanged,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 16),

        // 2. Chọn môn thể thao trước khi tải sân.
        if (widget.isShortVersion)
          LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = constraints.maxWidth >= 720
                  ? 4
                  : constraints.maxWidth >= 480
                  ? 3
                  : 2;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sports.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.18,
                ),
                itemBuilder: (context, index) {
                  final sport = _sports[index];
                  final isSelected = _selectedSportCategoryId == sport.id;
                  return InkWell(
                    onTap: _isLoading
                        ? null
                        : () {
                            final sportName = Uri.encodeComponent(
                              sport.name ?? '',
                            );
                            context.push(
                              widget.role == 'staff'
                                  ? '/staff/sport-facilities'
                                        '?sportId=${sport.id}'
                                        '&facilityId=${widget.facilityId ?? ''}'
                                        '&sportName=$sportName'
                                  : '/booking-catalog-full?role=customer'
                                        '&sportId=${sport.id}'
                                        '&sportName=$sportName',
                            );
                          },
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF5600)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF5600)
                              : theme.dividerColor.withValues(alpha: 0.18),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF5600,
                                  ).withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SportIcon(
                            sportName: sport.name,
                            imageUrl: sport.iconUrl,
                            selected: isSelected,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            sport.name ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        const SizedBox(height: 16),

        // 3. Grid/Skeleton loading
        if (_isLoading)
          const _CustomerBookingCatalogLoadingSkeleton()
        else if (_errorMessage != null)
          _buildErrorWidget()
        else if (_selectedSportCategoryId == null)
          _buildSelectSportPrompt()
        else
          _buildCatalogList(theme),
      ],
    );
  }

  Widget _buildSelectSportPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                vi: 'Chọn môn thể thao để xem danh sách sân',
                en: 'Select a sport to view courts',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              child: Text(context.tr(vi: 'Tải lại', en: 'Reload')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogList(ThemeData theme) {
    // 1. Filter courts by selected sport category & facility
    final filteredCourts = _courts.where((c) {
      final matchesSport =
          _selectedSportCategoryId == null ||
          c.sportId == _selectedSportCategoryId;
      final matchesFacility =
          widget.facilityId == null || c.facilityId == widget.facilityId;
      return matchesSport && matchesFacility;
    }).toList();

    if (!widget.isShortVersion &&
        widget.role == 'staff' &&
        widget.sportId != null) {
      return _buildStaffCourtList(filteredCourts, theme);
    }

    if (!widget.isShortVersion && widget.sportId != null) {
      return _buildFacilityGroups(filteredCourts, theme);
    }

    // 2. Select courts to paginate
    final List<CourtEntity> courtsToPaginate;
    if (widget.isShortVersion) {
      final Map<String, CourtEntity> firstCourtPerFacilityAndSport = {};
      for (final court in filteredCourts) {
        final key = '${court.facilityId ?? ''}_${court.sportId ?? ''}';
        if (!firstCourtPerFacilityAndSport.containsKey(key)) {
          firstCourtPerFacilityAndSport[key] = court;
        }
      }
      courtsToPaginate = firstCourtPerFacilityAndSport.values.toList();
    } else {
      courtsToPaginate = filteredCourts;
    }

    // 3. Slicing for pagination
    final totalCourts = courtsToPaginate.length;
    final totalPages = (totalCourts / widget.pageSize).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }
    final paginatedCourts = courtsToPaginate
        .skip((_currentPage - 1) * widget.pageSize)
        .take(widget.pageSize)
        .toList();

    final List<Widget> sportWidgets = [];

    // Filter sports that actually have courts in the current page
    final paginatedSports = _sports
        .where((s) => paginatedCourts.any((c) => c.sportId == s.id))
        .toList();

    for (final sport in paginatedSports) {
      final sportCourts = paginatedCourts
          .where((c) => c.sportId == sport.id)
          .toList();
      if (sportCourts.isEmpty) continue;

      final List<Widget> facilityWidgets = [];

      // Nhóm theo cơ sở của môn thể thao này
      final sportFacilityIds = sportCourts.map((c) => c.facilityId).toSet();
      for (final facId in sportFacilityIds) {
        final facility = _facilities.firstWhere(
          (f) => f.id == facId,
          orElse: () => FacilityEntity(
            id: facId ?? '',
            name: context.tr(vi: 'Cơ sở khác', en: 'Other facility'),
          ),
        );

        final facilityCourts = sportCourts
            .where((c) => c.facilityId == facId)
            .toList();

        final totalFacilityCourtsCount = filteredCourts
            .where((c) => c.facilityId == facId && c.sportId == sport.id)
            .length;

        facilityWidgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_city_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        facility.name ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ...facilityCourts.map((court) => _buildCourtCard(court, theme)),
              if (widget.isShortVersion && totalFacilityCourtsCount > 1) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      final nameEncoded = Uri.encodeComponent(
                        facility.name ?? '',
                      );
                      context.push(
                        '/booking-catalog-full?role=${widget.role}'
                        '&facilityId=${facility.id}'
                        '&sportId=${sport.id}'
                        '&facilityName=$nameEncoded',
                      );
                    },
                    icon: const Icon(
                      Icons.grid_view_rounded,
                      size: 16,
                      color: Color(0xFFFF5600),
                    ),
                    label: Text(
                      context.tr(
                        vi: 'Xem tất cả $totalFacilityCourtsCount sân & khung giờ',
                        en: 'View all $totalFacilityCourtsCount courts & slots',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFFF5600),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
              const Divider(height: 24, thickness: 0.5),
            ],
          ),
        );
      }

      sportWidgets.add(
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sport.name?.toUpperCase() ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                ...facilityWidgets,
              ],
            ),
          ),
        ),
      );
    }

    if (sportWidgets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(
                Icons.sports_soccer_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  vi: 'Không có sân nào mở cửa trong ngày đã chọn.',
                  en: 'No courts open on selected play date.',
                ),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ...sportWidgets,
        if (totalPages > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                '${context.tr(vi: 'Trang', en: 'Page')} $_currentPage / $totalPages',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildFacilityGroups(List<CourtEntity> courts, ThemeData theme) {
    if (courts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  vi: 'Chưa có khu liên hợp nào có môn thể thao này.',
                  en: 'No facilities currently offer this sport.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final courtsByFacility = <String, List<CourtEntity>>{};
    for (final court in courts) {
      courtsByFacility
          .putIfAbsent(court.facilityId ?? '', () => <CourtEntity>[])
          .add(court);
    }

    final facilityIds = courtsByFacility.keys.toList()
      ..sort((a, b) {
        final facilityA = _facilityById(a).name ?? '';
        final facilityB = _facilityById(b).name ?? '';
        return facilityA.compareTo(facilityB);
      });

    return Column(
      children: facilityIds.map((facilityId) {
        final facility = _facilityById(facilityId);
        final facilityCourts = courtsByFacility[facilityId]!
          ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.14)),
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>(
                'booking-facility-$facilityId-${widget.sportId}',
              ),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5600).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  color: Color(0xFFFF5600),
                ),
              ),
              title: Text(
                facility.name ?? context.tr(vi: 'Khu liên hợp', en: 'Facility'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '${facilityCourts.length} ${context.tr(vi: 'sân', en: 'courts')}',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              children: facilityCourts
                  .map((court) => _buildCourtCard(court, theme))
                  .toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStaffCourtList(List<CourtEntity> courts, ThemeData theme) {
    if (courts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            context.tr(
              vi: 'Cơ sở bạn quản lý chưa có sân cho môn thể thao này.',
              en: 'Your managed facility has no courts for this sport.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    final sortedCourts = [...courts]
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    return Column(
      children: sortedCourts
          .map((court) => _buildCourtCard(court, theme))
          .toList(),
    );
  }

  FacilityEntity _facilityById(String facilityId) {
    return _facilities.firstWhere(
      (facility) => facility.id == facilityId,
      orElse: () => FacilityEntity(
        id: facilityId,
        name: context.tr(vi: 'Khu liên hợp', en: 'Facility'),
      ),
    );
  }

  String? _sportNameForCourt(CourtEntity court) {
    final sportId = court.sportId;
    if (sportId == null || sportId.isEmpty) return null;
    for (final sport in _sports) {
      if (sport.id == sportId && sport.name != null && sport.name!.isNotEmpty) {
        return sport.name;
      }
    }
    return null;
  }

  Widget _buildCourtCard(CourtEntity court, ThemeData theme) {
    final config = _courtConfigs[court.id];
    final priceVal = court is BookingCourtModel ? court.pricePerHour : null;
    final sportName = _sportNameForCourt(court);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: InkWell(
        onTap: () {
          context.push('/court/${court.id}/booking', extra: court);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin Sân
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            court.name ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (priceVal != null)
                    Text(
                      '${_formatPrice(context, priceVal)}${context.tr(vi: '/giờ', en: '/h')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF5600),
                      ),
                    ),
                ],
              ),
              if (sportName != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.sports_soccer_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        sportName,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // Danh sách Slot — iOS horizontal scroll
              if (config == null || config.slots.isEmpty)
                Text(
                  context.tr(
                    vi: 'Không có cấu hình khung giờ.',
                    en: 'No slot configuration available.',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                )
              else
                _buildSlotScrollRow(court, config.slots, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Hàng cuộn ngang kiểu iOS hiển thị các khung giờ.
  Widget _buildSlotScrollRow(
    CourtEntity court,
    List<SlotEntity> slots,
    ThemeData theme,
  ) {
    final visibleSlots = _visibleSlots(slots);
    if (visibleSlots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          context.tr(
            vi: 'Hôm nay không còn khung giờ sắp tới.',
            en: 'No upcoming time slots remain today.',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 95,
      child: ListView.separated(
        key: PageStorageKey<String>(
          'court-slots-${court.id}-${_formatDateQuery(_selectedDate)}',
        ),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(), // iOS-style bounce
        itemCount: visibleSlots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final slot = visibleSlots[index];
          final state = _getSlotState(court, slot);
          return _buildSlotCard(court, slot, state, theme);
        },
      ),
    );
  }

  List<SlotEntity> _visibleSlots(List<SlotEntity> slots) {
    final now = DateTime.now();
    final isToday =
        now.year == _selectedDate.year &&
        now.month == _selectedDate.month &&
        now.day == _selectedDate.day;
    if (!isToday) return slots;

    final currentMinutes = now.hour * 60 + now.minute;
    return slots.where((slot) => slot.startMinutes >= currentMinutes).toList();
  }

  Widget _buildSlotCard(
    CourtEntity court,
    SlotEntity slot,
    int state,
    ThemeData theme,
  ) {
    final slotLabel =
        '${_minutesToHHmm(slot.startMinutes)}–${_minutesToHHmm(slot.endMinutes)}';

    // ─── Màu sắc theo trạng thái ───────────────────────────────────────────
    final bool isUnavailable = state != 0;
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final Color iconColor;
    final IconData statusIcon;
    final String statusText;

    switch (state) {
      case 1: // Booked
        bgColor = const Color(0xFFFFF1F0);
        borderColor = const Color(0xFFE57373);
        textColor = const Color(0xFFC62828);
        iconColor = const Color(0xFFC62828);
        statusIcon = Icons.remove_circle_outline_rounded;
        statusText = context.tr(vi: 'Đã đặt', en: 'Booked');
        break;
      case 2: // Pending
        bgColor = const Color(0xFFFFF8E1);
        borderColor = const Color(0xFFFFCA28);
        textColor = const Color(0xFFF57F17);
        iconColor = const Color(0xFFF57F17);
        statusIcon = Icons.hourglass_empty_rounded;
        statusText = context.tr(vi: 'Chờ duyệt', en: 'Pending');
        break;
      case 3: // Maintenance
        bgColor = const Color(0xFFFFF3E0);
        borderColor = const Color(0xFFFFA726);
        textColor = const Color(0xFFEF6C00);
        iconColor = const Color(0xFFEF6C00);
        statusIcon = Icons.build_rounded;
        statusText = context.tr(vi: 'Bảo trì', en: 'Maintenance');
        break;
      case 4: // Past
        bgColor = const Color(0xFFF5F5F5);
        borderColor = const Color(0xFFBDBDBD);
        textColor = const Color(0xFF616161);
        iconColor = const Color(0xFF616161);
        statusIcon = Icons.history_rounded;
        statusText = context.tr(vi: 'Quá giờ', en: 'Past');
        break;
      case 5: // Fixed schedule
        bgColor = const Color(0xFFEFF4F8);
        borderColor = const Color(0xFF607D8B);
        textColor = const Color(0xFF37474F);
        iconColor = const Color(0xFF455A64);
        statusIcon = Icons.event_repeat_rounded;
        statusText = context.tr(vi: 'Lịch cố định', en: 'Fixed schedule');
        break;
      case 0: // Available
      default:
        bgColor = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFF66BB6A);
        textColor = const Color(0xFF2E7D32);
        iconColor = const Color(0xFF2E7D32);
        statusIcon = Icons.check_circle_rounded;
        statusText = context.tr(vi: 'Còn trống', en: 'Available');
        break;
    }

    final cardWidget = Container(
      width: 135,
      height: 95,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon trạng thái
          Icon(statusIcon, size: 20, color: iconColor),
          const SizedBox(height: 5),
          // Giờ bắt đầu - kết thúc
          Text(
            slotLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          // Nhãn trạng thái
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: isUnavailable
          ? null
          : () {
              context.push(
                '/court/${court.id}/booking?startMinutes=${slot.startMinutes}',
                extra: court,
              );
            },
      child: cardWidget,
    );
  }
}

class _SportIcon extends StatelessWidget {
  final String? sportName;
  final String? imageUrl;
  final bool selected;

  const _SportIcon({
    required this.sportName,
    required this.imageUrl,
    required this.selected,
  });

  IconData _iconForSport() {
    final name = (sportName ?? '').toLowerCase();

    if (name.contains('bóng đá') ||
        name.contains('bong da') ||
        name.contains('football') ||
        name.contains('soccer') ||
        name.contains('futsal')) {
      return Icons.sports_soccer_rounded;
    }
    if (name.contains('bóng rổ') ||
        name.contains('bong ro') ||
        name.contains('basketball')) {
      return Icons.sports_basketball_rounded;
    }
    if (name.contains('bóng chuyền') ||
        name.contains('bong chuyen') ||
        name.contains('volleyball')) {
      return Icons.sports_volleyball_rounded;
    }
    if (name.contains('bơi') || name.contains('boi') || name.contains('swim')) {
      return Icons.pool_rounded;
    }
    if (name.contains('bóng bàn') ||
        name.contains('bong ban') ||
        name.contains('table tennis') ||
        name.contains('ping pong')) {
      return Icons.sports_tennis_rounded;
    }
    if (name.contains('cầu lông') ||
        name.contains('cau long') ||
        name.contains('badminton')) {
      return Icons.sports_tennis_rounded;
    }
    if (name.contains('tennis') || name.contains('pickleball')) {
      return Icons.sports_tennis_rounded;
    }
    if (name.contains('golf')) {
      return Icons.golf_course_rounded;
    }
    if (name.contains('chạy') ||
        name.contains('chay') ||
        name.contains('running')) {
      return Icons.directions_run_rounded;
    }
    return Icons.sports_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : const Color(0xFFFF5600);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.18)
            : color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: SportIconImage(
        imageUrl: imageUrl,
        fallbackIcon: _iconForSport(),
        fallbackColor: color,
        size: 40,
      ),
    );
  }
}

class _CustomerBookingCatalogLoadingSkeleton extends StatelessWidget {
  const _CustomerBookingCatalogLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(2, (i) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sport name loading
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),

                // Facility header loading
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 180,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Court item loading
                Container(
                  width: double.infinity,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
