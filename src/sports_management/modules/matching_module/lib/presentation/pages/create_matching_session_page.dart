// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:server_module/server_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:booking_module/booking_module.dart';
import 'package:app_module/app_module.dart';
import '../bloc/matching_bloc.dart';
import '../bloc/matching_event.dart';
import '../bloc/matching_state.dart';
import 'package:notification_module/notification_module.dart';

class CreateMatchingSessionPage extends StatefulWidget {
  const CreateMatchingSessionPage({super.key});

  @override
  State<CreateMatchingSessionPage> createState() =>
      _CreateMatchingSessionPageState();
}

class _CreateMatchingSessionPageState extends State<CreateMatchingSessionPage> {
  static const _primaryColor = Color(0xFFFF5600);
  static const _pageBackground = Color(0xFFF7F7F5);

  List<FacilityEntity> _facilities = [];
  List<SportEntity> _sports = [];
  List<CourtEntity> _allCourts = [];

  String? _selectedSportId;
  String? _selectedFacilityId;
  String? _selectedCourtId;
  String? _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  int _startMinutes = 17 * 60;
  int _endMinutes = 19 * 60;
  int _totalPlayersNeeded = 4;
  String _teamMode = 'INDIVIDUAL';
  int _teamSize = 5;
  String _hostTeamCode = 'A';
  int _hostRepresentedCount = 1;
  final TextEditingController _descController = TextEditingController();
  bool _autoApprove = true;
  String _paymentPolicy = 'HOST_PAY_ALL';
  bool _isFixedMatchingSchedule = false;
  bool _isSubmittingFixedSchedule = false;
  String _fixedFrequency = 'WEEKLY';
  final Set<int> _fixedDaysOfWeek = {};
  DateTime? _fixedStartDate;
  DateTime? _fixedEndDate;
  bool _isInfiniteFixedEndDate = false;

  List<SlotEntity> _slots = [];
  bool _isLoadingSlots = false;
  int? _selectedSlotIndex;
  Set<int> _bookedSlotIndices = {};
  Map<int, String> _bookingSlotStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  void _loadMetadata() async {
    try {
      final sportsResp = await GetIt.I<GetSportsUseCase>()();
      final facilitiesResp = await GetIt.I<GetFacilitiesUseCase>()();
      final courtsResp = await GetIt.I<GetCourtsUseCase>()();

      if (mounted) {
        setState(() {
          if (sportsResp.success && sportsResp.data != null) {
            _sports = sportsResp.data!;
          }
          if (facilitiesResp.success && facilitiesResp.data != null) {
            _facilities = facilitiesResp.data!;
          }
          if (courtsResp.success && courtsResp.data != null) {
            _allCourts = courtsResp.data!;
          }
        });
      }
    } catch (e) {
      debugPrint('[CreateMatching] Error loading metadata: $e');
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  String _formatDateQuery(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  DateTime? _selectedDateAsDateTime() {
    if (_selectedDate == null) return null;
    return DateTime.tryParse(_selectedDate!);
  }

  int _apiWeekday(DateTime date) =>
      date.weekday == DateTime.sunday ? 0 : date.weekday;

  void _ensureFixedScheduleDefaults() {
    final selected = _selectedDateAsDateTime() ?? DateTime.now();
    _fixedStartDate ??= selected;
    _fixedEndDate ??= selected.add(const Duration(days: 30));
    if (_fixedDaysOfWeek.isEmpty) {
      _fixedDaysOfWeek.add(_apiWeekday(selected));
    }
    if (_teamMode == 'INDIVIDUAL') {
      _teamMode = 'TEAM_FILL';
      if (_paymentPolicy == 'TEAM_REPRESENTATIVES_SPLIT') {
        _paymentPolicy = 'HOST_PAY_ALL';
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _isSelectedDateToday() {
    if (_selectedDate == null) return false;
    final selected = DateTime.tryParse(_selectedDate!);
    if (selected == null) return false;
    final now = DateTime.now();
    return selected.year == now.year &&
        selected.month == now.month &&
        selected.day == now.day;
  }

  int _getSlotState(int index, SlotEntity slot) {
    if (slot.status == 'FIXED_SCHEDULE_RESERVED') return 5;
    if (slot.status == 'BOOKED') return 1;
    if (!slot.isAvailable) return 3;

    if (_isSelectedDateToday()) {
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;
      if (slot.startMinutes < currentMinutes) return 4;
    }

    final bookingStatus = _bookingSlotStatuses[index];
    if (bookingStatus == 'PENDING') return 2;
    if (_bookedSlotIndices.contains(index)) return 1;

    return 0;
  }

  ({Color bg, Color border, Color text, IconData icon, String label})
  _slotStateStyle(int state) {
    switch (state) {
      case 1:
        return (
          bg: const Color(0xFFFFF1F0),
          border: const Color(0xFFE57373),
          text: const Color(0xFFC62828),
          icon: Icons.remove_circle_outline_rounded,
          label: context.tr(vi: 'Đã đặt', en: 'Booked'),
        );
      case 2:
        return (
          bg: const Color(0xFFFFF8E1),
          border: const Color(0xFFFFCA28),
          text: const Color(0xFFF57F17),
          icon: Icons.hourglass_empty_rounded,
          label: context.tr(vi: 'Chờ duyệt', en: 'Pending'),
        );
      case 3:
        return (
          bg: const Color(0xFFFFF3E0),
          border: const Color(0xFFFFA726),
          text: const Color(0xFFEF6C00),
          icon: Icons.build_rounded,
          label: context.tr(vi: 'Tạm ngưng', en: 'Unavailable'),
        );
      case 4:
        return (
          bg: const Color(0xFFF5F5F5),
          border: const Color(0xFFBDBDBD),
          text: const Color(0xFF616161),
          icon: Icons.history_rounded,
          label: context.tr(vi: 'Quá giờ', en: 'Past'),
        );
      case 5:
        return (
          bg: const Color(0xFFEFF4F8),
          border: const Color(0xFF607D8B),
          text: const Color(0xFF37474F),
          icon: Icons.event_repeat_rounded,
          label: context.tr(vi: 'Lịch cố định', en: 'Fixed'),
        );
      case 0:
      default:
        return (
          bg: const Color(0xFFE8F5E9),
          border: const Color(0xFF66BB6A),
          text: const Color(0xFF2E7D32),
          icon: Icons.check_circle_rounded,
          label: context.tr(vi: 'Còn trống', en: 'Available'),
        );
    }
  }

  int _getDefaultTeamSize(String? sportName) {
    if (sportName == null) return 5;
    final name = sportName.toLowerCase();
    if (name.contains('soccer') ||
        name.contains('football') ||
        name.contains('bóng đá')) {
      return 5;
    }
    if (name.contains('basketball') || name.contains('bóng rổ')) return 5;
    if (name.contains('volleyball') || name.contains('bóng chuyền')) return 6;
    if (name.contains('tennis') ||
        name.contains('badminton') ||
        name.contains('cầu lông') ||
        name.contains('bóng bàn')) {
      return 2;
    }
    return 5;
  }

  int _getMaxAdditionalPlayersForSport(SportEntity sport) {
    final configuredTeamSize =
        sport is SportCatalogEntity && (sport.teamSize ?? 0) > 0
        ? sport.teamSize!
        : _getDefaultTeamSize(sport.name);
    final maxAdditionalPlayers = configuredTeamSize * 2 - 1;
    return maxAdditionalPlayers > 0 ? maxAdditionalPlayers : 1;
  }

  Future<void> _loadSlots() async {
    if (_selectedCourtId == null || _selectedDate == null) return;
    setState(() {
      _isLoadingSlots = true;
      _slots = [];
      _selectedSlotIndex = null;
      _bookedSlotIndices.clear();
      _bookingSlotStatuses.clear();
    });
    try {
      final useCase = GetIt.I<GetSlotConfigUseCase>();
      final response = await useCase(
        _selectedCourtId!,
        bookingDate: _selectedDate!,
      );
      if (response.success && response.data != null) {
        final config = response.data!;

        final bookingUseCase = GetIt.I<GetBookingHistoryUseCase>();
        final bookingsResponse = await bookingUseCase();
        final booked = <int>{};
        final bookingStatuses = <int, String>{};
        if (bookingsResponse.success && bookingsResponse.data != null) {
          final courtBookings = bookingsResponse.data!.where(
            (b) =>
                b.courtId == _selectedCourtId &&
                b.bookingDate == _selectedDate &&
                b.status != 'CANCELLED',
          );
          for (final booking in courtBookings) {
            final bStart = booking.startMinutes;
            final bEnd = booking.endMinutes;
            if (bStart != null && bEnd != null) {
              for (int i = 0; i < config.slots.length; i++) {
                final slot = config.slots[i];
                if (slot.startMinutes < bEnd && slot.endMinutes > bStart) {
                  booked.add(i);
                  if (booking.status == 'PENDING') {
                    bookingStatuses.putIfAbsent(i, () => 'PENDING');
                  } else {
                    bookingStatuses[i] = 'BOOKED';
                  }
                }
              }
            }
          }
        }
        setState(() {
          _slots = config.slots;
          _bookedSlotIndices = booked;
          _bookingSlotStatuses = bookingStatuses;
        });
      }
    } catch (e) {
      debugPrint('Error loading slots: $e');
    } finally {
      setState(() {
        _isLoadingSlots = false;
      });
    }
  }

  List<CourtEntity> get _filteredCourts {
    if (_selectedFacilityId == null || _selectedSportId == null) return [];
    return _allCourts
        .where(
          (c) =>
              c.facilityId == _selectedFacilityId &&
              c.sportId == _selectedSportId &&
              (c.status == null || c.status == 'ACTIVE'),
        )
        .toList();
  }

  List<FacilityEntity> get _filteredFacilities {
    if (_selectedSportId == null) return [];

    final facilityIdsForSport = _allCourts
        .where(
          (c) =>
              c.sportId == _selectedSportId &&
              (c.status == null || c.status == 'ACTIVE') &&
              (c.facilityId?.isNotEmpty ?? false),
        )
        .map((c) => c.facilityId!)
        .toSet();

    return _facilities
        .where(
          (f) =>
              facilityIdsForSport.contains(f.id) &&
              (f.status == null || f.status == 'ACTIVE'),
        )
        .toList();
  }

  String _labelForId<T>(
    Iterable<T> items,
    String? selectedId,
    String Function(T item) idOf,
    String Function(T item) labelOf,
  ) {
    if (selectedId == null) return '';
    for (final item in items) {
      if (idOf(item) == selectedId) return labelOf(item);
    }
    return '';
  }

  String _paymentPolicyLabel(String policy) {
    switch (policy) {
      case 'SPLIT_EQUALLY':
        return context.tr(vi: 'Chia đều theo tài khoản', en: 'Split equally');
      case 'TEAM_REPRESENTATIVES_SPLIT':
        return context.tr(
          vi: 'Đại diện hai đội chia đôi',
          en: 'Team representatives split',
        );
      case 'HOST_PAY_ALL':
      default:
        return context.tr(vi: 'Chủ phòng trả toàn bộ', en: 'Host pays all');
    }
  }

  bool get _canSubmit =>
      _selectedSportId != null &&
      _selectedFacilityId != null &&
      _selectedCourtId != null &&
      _selectedDate != null &&
      _selectedSlotIndex != null &&
      (!_isFixedMatchingSchedule ||
          (_fixedStartDate != null &&
              (_isInfiniteFixedEndDate || _fixedEndDate != null) &&
              (_fixedFrequency == 'DAILY' || _fixedDaysOfWeek.isNotEmpty)));

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 21),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primaryColor, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildPopupField({
    required String valueLabel,
    required String hint,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final hasValue = valueLabel.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        isEmpty: !hasValue,
        decoration: _fieldDecoration(
          hint: '',
          icon: icon,
        ).copyWith(enabled: enabled, hintText: null),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? valueLabel : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasValue ? Colors.grey.shade900 : Colors.grey.shade600,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Future<T?> _pickFromPopup<T>({
    required String title,
    required List<AppPopupOption<T>> options,
    T? selectedValue,
    IconData icon = Icons.list_alt_rounded,
    String? searchHint,
    String? emptySearchMessage,
  }) {
    return AppPopup.showSelection<T>(
      context,
      title: title,
      options: options,
      selectedValue: selectedValue,
      icon: icon,
      confirmLabel: context.tr(vi: 'Chọn', en: 'Select'),
      searchHint: searchHint,
      emptySearchMessage:
          emptySearchMessage ??
          context.tr(vi: 'Không tìm thấy kết quả', en: 'No results found'),
    );
  }

  Future<void> _showChoiceInfo({
    required String title,
    required List<({IconData icon, String title, String description})> items,
  }) {
    return AppPopup.showForm<void>(
      context,
      title: title,
      icon: Icons.info_outline_rounded,
      submitLabel: context.tr(vi: 'Đã hiểu', en: 'Got it'),
      builder: (sheetContext, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: _primaryColor, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.description,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
      onSubmit: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildLabelWithInfo({
    required String label,
    required VoidCallback onInfo,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          tooltip: context.tr(vi: 'Xem giải thích', en: 'View explanation'),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: onInfo,
          icon: const Icon(
            Icons.info_outline_rounded,
            color: _primaryColor,
            size: 21,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required int step,
    required String title,
    required IconData icon,
    required bool complete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: complete ? _primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: complete ? _primaryColor : Colors.grey.shade300,
              ),
            ),
            child: complete
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : Icon(icon, color: Colors.grey.shade700, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$step. $title',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _teamMode == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _teamMode = value;
            if (_teamMode == 'INDIVIDUAL' &&
                _paymentPolicy == 'TEAM_REPRESENTATIVES_SPLIT') {
              _paymentPolicy = 'HOST_PAY_ALL';
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _primaryColor : Colors.grey.shade300,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : icon,
                color: selected ? Colors.white : Colors.grey.shade700,
                size: 22,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey.shade900,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixedOptionChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      selectedColor: _primaryColor,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.grey.shade900,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? _primaryColor : Colors.grey.shade300,
          width: selected ? 1.6 : 1,
        ),
      ),
    );
  }

  Widget _buildDateTile({
    required String label,
    required DateTime? date,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined, color: _primaryColor, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date == null ? '-' : DateDisplayFormatter.date(date),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedWeekdayPicker() {
    final days = [
      (value: 1, label: context.tr(vi: 'T2', en: 'M')),
      (value: 2, label: context.tr(vi: 'T3', en: 'T')),
      (value: 3, label: context.tr(vi: 'T4', en: 'W')),
      (value: 4, label: context.tr(vi: 'T5', en: 'T')),
      (value: 5, label: context.tr(vi: 'T6', en: 'F')),
      (value: 6, label: context.tr(vi: 'T7', en: 'S')),
      (value: 0, label: context.tr(vi: 'CN', en: 'S')),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((day) {
        final selected = _fixedDaysOfWeek.contains(day.value);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _fixedDaysOfWeek.remove(day.value);
              } else {
                _fixedDaysOfWeek.add(day.value);
              }
            });
          },
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _primaryColor : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? _primaryColor : Colors.grey.shade300,
              ),
            ),
            child: Text(
              day.label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade900,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFixedMatchingSchedulePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isFixedMatchingSchedule
              ? _primaryColor.withOpacity(0.45)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isFixedMatchingSchedule,
            activeColor: _primaryColor,
            title: Text(
              context.tr(
                vi: 'Tạo lịch ghép cố định',
                en: 'Create fixed match schedule',
              ),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              context.tr(
                vi: 'Chủ phòng giữ template cố định; người khác chỉ tham gia từng ngày được sinh ra.',
                en: 'The host owns the template; others join generated one-day sessions.',
              ),
              style: const TextStyle(fontSize: 12),
            ),
            onChanged: (value) {
              setState(() {
                _isFixedMatchingSchedule = value;
                if (value) _ensureFixedScheduleDefaults();
              });
            },
          ),
          if (_isFixedMatchingSchedule) ...[
            const SizedBox(height: 10),
            Text(
              context.tr(vi: 'Tần suất lặp', en: 'Repeat frequency'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFixedOptionChip(
                  label: context.tr(vi: 'Hàng tuần', en: 'Weekly'),
                  selected: _fixedFrequency == 'WEEKLY',
                  onSelected: (value) {
                    if (value) setState(() => _fixedFrequency = 'WEEKLY');
                  },
                ),
                _buildFixedOptionChip(
                  label: context.tr(vi: 'Hàng ngày', en: 'Daily'),
                  selected: _fixedFrequency == 'DAILY',
                  onSelected: (value) {
                    if (value) setState(() => _fixedFrequency = 'DAILY');
                  },
                ),
              ],
            ),
            if (_fixedFrequency == 'WEEKLY') ...[
              const SizedBox(height: 12),
              Text(
                context.tr(vi: 'Thứ lặp lại', en: 'Repeat days'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildFixedWeekdayPicker(),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildDateTile(
                    label: context.tr(vi: 'Ngày bắt đầu', en: 'Start date'),
                    date: _fixedStartDate,
                    onTap: _pickFixedStartDate,
                  ),
                ),
                const SizedBox(width: 10),
                if (!_isInfiniteFixedEndDate)
                  Expanded(
                    child: _buildDateTile(
                      label: context.tr(vi: 'Ngày kết thúc', en: 'End date'),
                      date: _fixedEndDate,
                      onTap: _pickFixedEndDate,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isInfiniteFixedEndDate,
              activeColor: _primaryColor,
              title: Text(
                context.tr(vi: 'Không đặt ngày kết thúc', en: 'No end date'),
                style: const TextStyle(fontSize: 13),
              ),
              onChanged: (value) {
                setState(() => _isInfiniteFixedEndDate = value ?? false);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionSummary() {
    if (!_canSubmit) return const SizedBox.shrink();

    final sport = _sports.firstWhere(
      (item) => item.id == _selectedSportId,
      orElse: () => const SportEntity(id: ''),
    );
    final facility = _facilities.firstWhere(
      (item) => item.id == _selectedFacilityId,
      orElse: () => FacilityEntity(id: ''),
    );
    final court = _allCourts.firstWhere(
      (item) => item.id == _selectedCourtId,
      orElse: () => CourtEntity(id: ''),
    );
    final slot =
        _selectedSlotIndex != null && _selectedSlotIndex! < _slots.length
        ? _slots[_selectedSlotIndex!]
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primaryColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: _primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr(vi: 'Thông tin đã chọn', en: 'Selected details'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${sport.name ?? ''} • ${facility.name ?? ''} • ${court.name ?? ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade800),
          ),
          const SizedBox(height: 4),
          Text(
            '${DateDisplayFormatter.date(DateTime.parse(_selectedDate!))}'
            '${slot == null ? '' : ' • ${slot.startLabel} - ${slot.endLabel}'}',
            style: const TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(bool isLoading) {
    final busy = isLoading || _isSubmittingFixedSchedule;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _canSubmit && !busy ? () => _submit() : null,
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add_circle_outline_rounded),
            label: Text(
              _isFixedMatchingSchedule
                  ? context.tr(
                      vi: 'Tạo lịch ghép cố định',
                      en: 'Create fixed match',
                    )
                  : context.tr(vi: 'Tạo phòng ghép', en: 'Create match lobby'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              elevation: _canSubmit ? 3 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedSportId == null ||
        _selectedFacilityId == null ||
        _selectedCourtId == null ||
        _selectedDate == null ||
        _selectedSlotIndex == null) {
      _showError(
        context.tr(
          vi: 'Vui lòng điền các thông tin bắt buộc, bao gồm cả chọn sân và khung giờ',
          en: 'Please fill in all mandatory information, including selecting a court and slot',
        ),
      );
      return;
    }

    final isTeamMode = _teamMode != 'INDIVIDUAL';
    if (_isFixedMatchingSchedule) {
      if (!isTeamMode) {
        _showError(
          context.tr(
            vi: 'Lịch ghép cố định cần dùng chế độ chia đội.',
            en: 'Fixed matching requires a team mode.',
          ),
        );
        return;
      }
      if (_fixedFrequency == 'WEEKLY' && _fixedDaysOfWeek.isEmpty) {
        _showError(
          context.tr(
            vi: 'Vui lòng chọn ít nhất một thứ trong tuần.',
            en: 'Please select at least one repeat day.',
          ),
        );
        return;
      }

      setState(() => _isSubmittingFixedSchedule = true);
      try {
        final response = await GetIt.I<CreateFixedScheduleUseCase>()({
          'type': 'MATCHING',
          'sportId': _selectedSportId,
          'facilityId': _selectedFacilityId,
          'courtId': _selectedCourtId,
          'startMinutes': _startMinutes,
          'endMinutes': _endMinutes,
          'frequency': _fixedFrequency,
          if (_fixedFrequency == 'WEEKLY')
            'daysOfWeek': _fixedDaysOfWeek.toList()..sort(),
          'startDate': _formatDateQuery(
            _fixedStartDate ?? _selectedDateAsDateTime() ?? DateTime.now(),
          ),
          'endDate': _isInfiniteFixedEndDate
              ? null
              : _formatDateQuery(
                  _fixedEndDate ??
                      (_fixedStartDate ??
                              _selectedDateAsDateTime() ??
                              DateTime.now())
                          .add(const Duration(days: 30)),
                ),
          'matchingConfig': {
            'team_mode': _teamMode,
            'team_size': _teamSize,
            'payment_policy': _paymentPolicy,
            'host_team_code': _hostTeamCode,
            'host_represented_count': _hostRepresentedCount,
          },
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message ??
                  (response.success
                      ? context.tr(
                          vi: 'Đã gửi yêu cầu tạo lịch ghép cố định',
                          en: 'Fixed match schedule submitted',
                        )
                      : context.tr(
                          vi: 'Không thể tạo lịch ghép cố định',
                          en: 'Unable to create fixed match schedule',
                        )),
            ),
            backgroundColor: response.success ? Colors.green : Colors.red,
          ),
        );
        if (response.success) Navigator.pop(context);
      } catch (error) {
        if (!mounted) return;
        _showError(error.toString());
      } finally {
        if (mounted) setState(() => _isSubmittingFixedSchedule = false);
      }
      return;
    }

    final data = {
      'sportId': _selectedSportId,
      'facilityId': _selectedFacilityId,
      'courtId': _selectedCourtId,
      'bookingDate': _selectedDate,
      'startMinutes': _startMinutes,
      'endMinutes': _endMinutes,
      'totalPlayersNeeded': isTeamMode
          ? _teamSize * 2 - _hostRepresentedCount
          : _totalPlayersNeeded,
      'teamMode': _teamMode,
      if (isTeamMode) 'teamSize': _teamSize,
      if (isTeamMode) 'hostTeamCode': _hostTeamCode,
      if (isTeamMode) 'hostRepresentedCount': _hostRepresentedCount,
      if (_descController.text.trim().isNotEmpty)
        'description': _descController.text.trim(),
      'autoApprove': _autoApprove,
      'paymentPolicy': _paymentPolicy,
    };

    context.read<MatchingBloc>().add(CreateMatchingSessionEvent(data));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: Text(
          context.tr(vi: 'Tạo phòng ghép', en: 'Create match lobby'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: BlocBuilder<MatchingBloc, MatchingState>(
        builder: (context, state) =>
            _buildBottomAction(state is MatchingLoadingState),
      ),
      body: BlocConsumer<MatchingBloc, MatchingState>(
        listener: (context, state) {
          if (state is MatchingActionSuccessState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
          if (state is MatchingErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEE6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _primaryColor.withOpacity(0.24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sports_soccer_rounded,
                        color: _primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr(
                            vi: 'Chọn sân, thời gian và cách ghép đội',
                            en: 'Choose court, time and matching mode',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                _buildSectionHeader(
                  step: 1,
                  title: context.tr(vi: 'Môn và sân', en: 'Sport and court'),
                  icon: Icons.place_outlined,
                  complete:
                      _selectedSportId != null &&
                      _selectedFacilityId != null &&
                      _selectedCourtId != null,
                ),

                // Sport selection
                Text(
                  context.tr(vi: 'Môn thể thao *', en: 'Sport *'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildPopupField(
                  valueLabel: _labelForId(
                    _sports,
                    _selectedSportId,
                    (sport) => sport.id,
                    (sport) => sport.name ?? '',
                  ),
                  hint: context.tr(vi: 'Chọn bộ môn', en: 'Select sport'),
                  icon: Icons.sports_rounded,
                  onTap: () async {
                    final val = await _pickFromPopup<String>(
                      title: context.tr(
                        vi: 'Chọn môn thể thao',
                        en: 'Select sport',
                      ),
                      selectedValue: _selectedSportId,
                      icon: Icons.sports_rounded,
                      searchHint: context.tr(
                        vi: 'Tìm kiếm môn thể thao...',
                        en: 'Search sports...',
                      ),
                      emptySearchMessage: context.tr(
                        vi: 'Không tìm thấy môn thể thao phù hợp',
                        en: 'No matching sports found',
                      ),
                      options: _sports
                          .map(
                            (sport) => AppPopupOption<String>(
                              value: sport.id,
                              label: sport.name ?? '',
                              icon: Icons.sports_soccer_rounded,
                              imageUrl: sport.iconUrl,
                            ),
                          )
                          .toList(),
                    );
                    if (val == null || !mounted) return;
                    setState(() {
                      _selectedSportId = val;
                      _selectedFacilityId = null;
                      _selectedCourtId = null; // reset court
                      _slots = [];
                      _selectedSlotIndex = null;
                      _bookedSlotIndices.clear();
                      _bookingSlotStatuses.clear();

                      final sport = _sports.firstWhere(
                        (s) => s.id == val,
                        orElse: () => SportEntity(id: ''),
                      );
                      _teamSize =
                          sport is SportCatalogEntity &&
                              (sport.teamSize ?? 0) > 0
                          ? sport.teamSize!
                          : _getDefaultTeamSize(sport.name);
                      final maxAdditionalPlayers =
                          _getMaxAdditionalPlayersForSport(sport);
                      if (_hostRepresentedCount > _teamSize) {
                        _hostRepresentedCount = _teamSize;
                      }
                      _totalPlayersNeeded = maxAdditionalPlayers;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Facility selection
                Text(
                  context.tr(vi: 'Cơ sở sân *', en: 'Facility *'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildPopupField(
                  valueLabel: _labelForId(
                    _filteredFacilities,
                    _selectedFacilityId,
                    (facility) => facility.id,
                    (facility) => facility.name ?? '',
                  ),
                  hint: context.tr(vi: 'Chọn cơ sở sân', en: 'Select facility'),
                  icon: Icons.location_on_outlined,
                  onTap: _selectedSportId == null
                      ? null
                      : () async {
                          final val = await _pickFromPopup<String>(
                            title: context.tr(
                              vi: 'Chọn cơ sở sân',
                              en: 'Select facility',
                            ),
                            selectedValue: _selectedFacilityId,
                            icon: Icons.location_on_outlined,
                            options: _filteredFacilities
                                .map(
                                  (facility) => AppPopupOption<String>(
                                    value: facility.id,
                                    label: facility.name ?? '',
                                    subtitle: facility.address,
                                    icon: Icons.location_city_outlined,
                                  ),
                                )
                                .toList(),
                          );
                          if (val == null || !mounted) return;
                          setState(() {
                            _selectedFacilityId = val;
                            _selectedCourtId = null; // reset court
                            _slots = [];
                            _selectedSlotIndex = null;
                            _bookedSlotIndices.clear();
                            _bookingSlotStatuses.clear();
                          });
                          _loadSlots();
                        },
                ),
                const SizedBox(height: 16),

                // Court Selection (mandatory)
                if (_selectedFacilityId != null &&
                    _selectedSportId != null) ...[
                  Text(
                    context.tr(
                      vi: 'Chọn sân cụ thể *',
                      en: 'Select specific court *',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildPopupField(
                    valueLabel: _labelForId(
                      _filteredCourts,
                      _selectedCourtId,
                      (court) => court.id,
                      (court) => court.name ?? '',
                    ),
                    hint: context.tr(vi: 'Chọn sân đấu', en: 'Select court'),
                    icon: Icons.stadium_outlined,
                    onTap: () async {
                      final val = await _pickFromPopup<String>(
                        title: context.tr(
                          vi: 'Chọn sân đấu',
                          en: 'Select court',
                        ),
                        selectedValue: _selectedCourtId,
                        icon: Icons.stadium_outlined,
                        options: _filteredCourts
                            .map(
                              (court) => AppPopupOption<String>(
                                value: court.id,
                                label: court.name ?? '',
                                icon: Icons.sports_soccer_outlined,
                              ),
                            )
                            .toList(),
                      );
                      if (val == null || !mounted) return;
                      setState(() {
                        _selectedCourtId = val;
                        _slots = [];
                        _selectedSlotIndex = null;
                      });
                      _loadSlots();
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                Divider(height: 32, color: Colors.grey.shade300),
                _buildSectionHeader(
                  step: 2,
                  title: context.tr(
                    vi: 'Ngày và khung giờ',
                    en: 'Date and time',
                  ),
                  icon: Icons.schedule_rounded,
                  complete: _selectedDate != null && _selectedSlotIndex != null,
                ),

                // Date Picker
                Text(
                  context.tr(vi: 'Ngày chơi *', en: 'Play Date *'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          color: Colors.grey.shade600,
                          size: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedDate != null
                                ? DateDisplayFormatter.date(
                                    DateTime.parse(_selectedDate!),
                                  )
                                : context.tr(
                                    vi: 'Chọn ngày chơi',
                                    en: 'Select date',
                                  ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.expand_more_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Hours list (Grid)
                if (_selectedCourtId != null && _selectedDate != null) ...[
                  Text(
                    context.tr(vi: 'Khung giờ sân *', en: 'Time Slots *'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingSlots)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF5600),
                      ),
                    )
                  else if (_slots.isEmpty)
                    Text(
                      context.tr(
                        vi: 'Không có khung giờ nào hoạt động.',
                        en: 'No active time slots found.',
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 12.0;
                        final columnCount = constraints.maxWidth >= 520 ? 3 : 2;
                        final itemWidth =
                            (constraints.maxWidth - gap * (columnCount - 1)) /
                            columnCount;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: List.generate(_slots.length, (index) {
                            final slot = _slots[index];
                            final slotState = _getSlotState(index, slot);
                            final isUnavailable = slotState != 0;
                            final isSelected = _selectedSlotIndex == index;
                            final stateStyle = _slotStateStyle(slotState);

                            final color = isSelected
                                ? const Color(0xFFFF5600)
                                : stateStyle.bg;
                            final textColor = isSelected
                                ? Colors.white
                                : stateStyle.text;
                            final borderColor = isSelected
                                ? const Color(0xFFFF5600)
                                : stateStyle.border;

                            return SizedBox(
                              width: itemWidth,
                              child: GestureDetector(
                                onTap: isUnavailable
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedSlotIndex = index;
                                          _startMinutes = slot.startMinutes;
                                          _endMinutes = slot.endMinutes;
                                        });
                                      },
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 92,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            stateStyle.icon,
                                            size: 15,
                                            color: textColor,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              stateStyle.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${slot.startLabel} - ${slot.endLabel}',
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                ],

                Divider(height: 32, color: Colors.grey.shade300),
                _buildSectionHeader(
                  step: 3,
                  title: context.tr(
                    vi: 'Cấu hình người chơi',
                    en: 'Player configuration',
                  ),
                  icon: Icons.groups_2_outlined,
                  complete: _teamMode == 'INDIVIDUAL'
                      ? _totalPlayersNeeded > 0
                      : _teamSize > 0 && _hostRepresentedCount > 0,
                ),

                _buildLabelWithInfo(
                  label: context.tr(
                    vi: 'Kiểu phòng ghép *',
                    en: 'Matching mode *',
                  ),
                  onInfo: () => _showChoiceInfo(
                    title: context.tr(
                      vi: 'Chọn kiểu phòng ghép',
                      en: 'Choose matching mode',
                    ),
                    items: [
                      (
                        icon: Icons.person_outline_rounded,
                        title: context.tr(vi: 'Người lẻ', en: 'Individual'),
                        description: context.tr(
                          vi: 'Mỗi tài khoản tham gia như một người chơi. Phù hợp khi bạn muốn tuyển thêm các thành viên riêng lẻ.',
                          en: 'Each account joins as one player. Best for recruiting individual players.',
                        ),
                      ),
                      (
                        icon: Icons.group_add_outlined,
                        title: context.tr(vi: 'Chia đội A/B', en: 'Fill teams'),
                        description: context.tr(
                          vi: 'Người chơi hoặc nhóm nhỏ chọn Team A, Team B hoặc tự động để lấp đầy hai đội.',
                          en: 'Players or small groups choose Team A, Team B or automatic assignment.',
                        ),
                      ),
                      (
                        icon: Icons.sports_mma_outlined,
                        title: context.tr(
                          vi: 'Đội đấu đội',
                          en: 'Team vs team',
                        ),
                        description: context.tr(
                          vi: 'Dành cho chủ phòng đã có đội và muốn tìm một đội khác làm đối thủ.',
                          en: 'For a host who already has a team and wants to find an opposing team.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildModeOption(
                      value: 'INDIVIDUAL',
                      label: context.tr(vi: 'Người lẻ', en: 'Individual'),
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildModeOption(
                      value: 'TEAM_FILL',
                      label: context.tr(vi: 'Chia đội A/B', en: 'Fill teams'),
                      icon: Icons.group_add_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildModeOption(
                      value: 'TEAM_VS_TEAM',
                      label: context.tr(vi: 'Đội đấu đội', en: 'Team vs team'),
                      icon: Icons.sports_mma_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_teamMode == 'INDIVIDUAL') ...[
                  _buildLabelWithInfo(
                    label: context.tr(
                      vi: 'Số chân cần tuyển thêm *',
                      en: 'Players needed *',
                    ),
                    onInfo: () => _showChoiceInfo(
                      title: context.tr(
                        vi: 'Số chân cần tuyển',
                        en: 'Players needed',
                      ),
                      items: [
                        (
                          icon: Icons.person_add_alt_1_outlined,
                          title: context.tr(
                            vi: 'Không tính chủ phòng',
                            en: 'Host not included',
                          ),
                          description: context.tr(
                            vi: 'Đây là số người cần tuyển thêm ngoài bạn. Giới hạn được tính theo đội hình của môn đã chọn.',
                            en: 'This is the number of additional players besides you. The limit follows the selected sport.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPopupField(
                    valueLabel: context.tr(
                      vi: '$_totalPlayersNeeded người',
                      en: '$_totalPlayersNeeded players',
                    ),
                    hint: context.tr(
                      vi: 'Chọn số người cần tuyển',
                      en: 'Select players needed',
                    ),
                    icon: Icons.person_add_alt_1_outlined,
                    onTap: () async {
                      final sport = _sports.firstWhere(
                        (s) => s.id == _selectedSportId,
                        orElse: () => const SportEntity(id: ''),
                      );
                      final max = _getMaxAdditionalPlayersForSport(sport);
                      final value = await _pickFromPopup<int>(
                        title: context.tr(
                          vi: 'Số chân cần tuyển thêm',
                          en: 'Players needed',
                        ),
                        selectedValue: _totalPlayersNeeded,
                        icon: Icons.person_add_alt_1_outlined,
                        options: List.generate(max, (index) {
                          final count = index + 1;
                          return AppPopupOption<int>(
                            value: count,
                            label: context.tr(
                              vi: '$count người',
                              en: '$count players',
                            ),
                          );
                        }),
                      );
                      if (value == null || !mounted) return;
                      setState(() => _totalPlayersNeeded = value);
                    },
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  _buildLabelWithInfo(
                    label: context.tr(
                      vi: 'Số người mỗi đội *',
                      en: 'Players per team *',
                    ),
                    onInfo: () => _showChoiceInfo(
                      title: context.tr(vi: 'Quy mô đội', en: 'Team size'),
                      items: [
                        (
                          icon: Icons.groups_outlined,
                          title: context.tr(
                            vi: 'Số người của một đội',
                            en: 'Players in one team',
                          ),
                          description: context.tr(
                            vi: 'Ví dụ bóng đá sân 5 chọn 5 người mỗi đội. Phòng chỉ đầy khi Team A và Team B đều đủ số người.',
                            en: 'For five-a-side football, select 5 players per team. The lobby is full when both teams are complete.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPopupField(
                    valueLabel: context.tr(
                      vi: '$_teamSize người/đội',
                      en: '$_teamSize players/team',
                    ),
                    hint: context.tr(
                      vi: 'Số người mỗi đội',
                      en: 'Players per team',
                    ),
                    icon: Icons.groups_outlined,
                    onTap: () async {
                      final value = await _pickFromPopup<int>(
                        title: context.tr(
                          vi: 'Số người mỗi đội',
                          en: 'Players per team',
                        ),
                        selectedValue: _teamSize,
                        icon: Icons.groups_outlined,
                        options: List.generate(
                          11,
                          (index) => AppPopupOption<int>(
                            value: index + 1,
                            label: context.tr(
                              vi: '${index + 1} người/đội',
                              en: '${index + 1} players/team',
                            ),
                          ),
                        ),
                      );
                      if (value == null || !mounted) return;
                      setState(() {
                        _teamSize = value;
                        if (_hostRepresentedCount > _teamSize) {
                          _hostRepresentedCount = _teamSize;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabelWithInfo(
                    label: context.tr(
                      vi: 'Đội của chủ phòng *',
                      en: 'Host team *',
                    ),
                    onInfo: () => _showChoiceInfo(
                      title: context.tr(
                        vi: 'Chọn đội của bạn',
                        en: 'Choose your team',
                      ),
                      items: [
                        (
                          icon: Icons.shield_outlined,
                          title: context.tr(
                            vi: 'Team A hoặc Team B',
                            en: 'Team A or Team B',
                          ),
                          description: context.tr(
                            vi: 'Đây chỉ là phía đội của chủ phòng. Đội còn lại sẽ dành cho người chơi hoặc đối thủ tham gia.',
                            en: 'This identifies the host team. The other team is reserved for joining players or opponents.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith(
                        (states) => states.contains(MaterialState.selected)
                            ? _primaryColor
                            : Colors.white,
                      ),
                      foregroundColor: MaterialStateProperty.resolveWith(
                        (states) => states.contains(MaterialState.selected)
                            ? Colors.white
                            : Colors.grey.shade800,
                      ),
                      side: MaterialStatePropertyAll(
                        BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(value: 'A', label: Text('Team A')),
                      ButtonSegment(value: 'B', label: Text('Team B')),
                    ],
                    selected: {_hostTeamCode},
                    onSelectionChanged: (value) {
                      setState(() {
                        _hostTeamCode = value.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabelWithInfo(
                    label: context.tr(
                      vi: 'Số người chủ phòng đại diện *',
                      en: 'Players represented by host *',
                    ),
                    onInfo: () => _showChoiceInfo(
                      title: context.tr(
                        vi: 'Số người bạn đã có',
                        en: 'Players represented by host',
                      ),
                      items: [
                        (
                          icon: Icons.badge_outlined,
                          title: context.tr(
                            vi: 'Tính cả bạn',
                            en: 'Includes you',
                          ),
                          description: context.tr(
                            vi: 'Nhập tổng số người trong nhóm bạn mang theo, có tính cả tài khoản chủ phòng.',
                            en: 'Enter the total number of players in your group, including the host account.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPopupField(
                    valueLabel: context.tr(
                      vi: '$_hostRepresentedCount người',
                      en: '$_hostRepresentedCount players',
                    ),
                    hint: context.tr(
                      vi: 'Số người bạn đại diện',
                      en: 'Players represented',
                    ),
                    icon: Icons.badge_outlined,
                    onTap: () async {
                      final value = await _pickFromPopup<int>(
                        title: context.tr(
                          vi: 'Số người chủ phòng đại diện',
                          en: 'Players represented by host',
                        ),
                        selectedValue: _hostRepresentedCount,
                        icon: Icons.badge_outlined,
                        options: List.generate(
                          _teamSize,
                          (index) => AppPopupOption<int>(
                            value: index + 1,
                            label: context.tr(
                              vi: '${index + 1} người',
                              en: '${index + 1} players',
                            ),
                          ),
                        ),
                      );
                      if (value == null || !mounted) return;
                      setState(() => _hostRepresentedCount = value);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                _buildFixedMatchingSchedulePanel(),
                const SizedBox(height: 16),
                Divider(height: 32, color: Colors.grey.shade300),
                _buildSectionHeader(
                  step: 4,
                  title: context.tr(
                    vi: 'Thanh toán và quyền tham gia',
                    en: 'Payment and joining',
                  ),
                  icon: Icons.tune_rounded,
                  complete: _paymentPolicy.isNotEmpty,
                ),

                // Payment policy
                _buildLabelWithInfo(
                  label: context.tr(
                    vi: 'Chính sách thanh toán *',
                    en: 'Payment policy *',
                  ),
                  onInfo: () => _showChoiceInfo(
                    title: context.tr(
                      vi: 'Cách chia tiền sân',
                      en: 'Payment policy',
                    ),
                    items: [
                      (
                        icon: Icons.person_rounded,
                        title: context.tr(
                          vi: 'Chủ phòng trả toàn bộ',
                          en: 'Host pays all',
                        ),
                        description: context.tr(
                          vi: 'Chỉ chủ phòng nhận hóa đơn cho toàn bộ tiền sân.',
                          en: 'Only the host receives the invoice for the full court fee.',
                        ),
                      ),
                      (
                        icon: Icons.groups_rounded,
                        title: context.tr(
                          vi: 'Chia đều theo tài khoản',
                          en: 'Split equally',
                        ),
                        description: context.tr(
                          vi: 'Tiền sân được chia đều cho chủ phòng và các thành viên dùng tài khoản ứng dụng khi phòng đủ người.',
                          en: 'The court fee is divided among the host and app members when the lobby is full.',
                        ),
                      ),
                      if (_teamMode != 'INDIVIDUAL')
                        (
                          icon: Icons.handshake_outlined,
                          title: context.tr(
                            vi: 'Đại diện hai đội chia đôi',
                            en: 'Team representatives split',
                          ),
                          description: context.tr(
                            vi: 'Đại diện Team A và Team B mỗi người thanh toán một nửa tiền sân.',
                            en: 'The representatives of Team A and Team B each pay half of the court fee.',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildPopupField(
                  valueLabel: _paymentPolicyLabel(_paymentPolicy),
                  hint: context.tr(
                    vi: 'Chọn cách thanh toán',
                    en: 'Select payment policy',
                  ),
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () async {
                    final options = <AppPopupOption<String>>[
                      AppPopupOption<String>(
                        value: 'HOST_PAY_ALL',
                        label: _paymentPolicyLabel('HOST_PAY_ALL'),
                        subtitle: context.tr(
                          vi: 'Chỉ chủ phòng nhận hóa đơn toàn bộ tiền sân',
                          en: 'Only the host receives the full invoice',
                        ),
                        icon: Icons.person_rounded,
                      ),
                      AppPopupOption<String>(
                        value: 'SPLIT_EQUALLY',
                        label: _paymentPolicyLabel('SPLIT_EQUALLY'),
                        subtitle: context.tr(
                          vi: 'Chia tiền cho các tài khoản khi phòng đủ người',
                          en: 'Split among accounts when the lobby is full',
                        ),
                        icon: Icons.groups_rounded,
                      ),
                      if (_teamMode != 'INDIVIDUAL')
                        AppPopupOption<String>(
                          value: 'TEAM_REPRESENTATIVES_SPLIT',
                          label: _paymentPolicyLabel(
                            'TEAM_REPRESENTATIVES_SPLIT',
                          ),
                          subtitle: context.tr(
                            vi: 'Đại diện Team A và Team B mỗi người trả một nửa',
                            en: 'Team A and Team B representatives each pay half',
                          ),
                          icon: Icons.handshake_outlined,
                        ),
                    ];
                    final value = await _pickFromPopup<String>(
                      title: context.tr(
                        vi: 'Chọn cách thanh toán',
                        en: 'Select payment policy',
                      ),
                      selectedValue: _paymentPolicy,
                      icon: Icons.account_balance_wallet_outlined,
                      options: options,
                    );
                    if (value == null || !mounted) return;
                    setState(() {
                      _paymentPolicy = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Auto approve switch
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: _primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                vi: 'Duyệt tự động',
                                en: 'Auto approve',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              context.tr(
                                vi: 'Thành viên được vào phòng ngay',
                                en: 'Members join immediately',
                              ),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr(
                          vi: 'Xem giải thích',
                          en: 'View explanation',
                        ),
                        onPressed: () => _showChoiceInfo(
                          title: context.tr(
                            vi: 'Duyệt thành viên',
                            en: 'Member approval',
                          ),
                          items: [
                            (
                              icon: Icons.flash_on_rounded,
                              title: context.tr(
                                vi: 'Bật duyệt tự động',
                                en: 'Auto approval on',
                              ),
                              description: context.tr(
                                vi: 'Yêu cầu tham gia được chấp nhận ngay nếu phòng hoặc đội vẫn còn chỗ.',
                                en: 'Join requests are accepted immediately when capacity is available.',
                              ),
                            ),
                            (
                              icon: Icons.rule_rounded,
                              title: context.tr(
                                vi: 'Tắt duyệt tự động',
                                en: 'Auto approval off',
                              ),
                              description: context.tr(
                                vi: 'Chủ phòng phải xem và duyệt từng yêu cầu tham gia.',
                                en: 'The host reviews and approves each join request manually.',
                              ),
                            ),
                          ],
                        ),
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          color: _primaryColor,
                          size: 21,
                        ),
                      ),
                      Switch(
                        value: _autoApprove,
                        activeColor: _primaryColor,
                        onChanged: (val) {
                          setState(() {
                            _autoApprove = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  context.tr(
                    vi: 'Mô tả kèo đấu (không bắt buộc)',
                    en: 'Match description (optional)',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: _fieldDecoration(
                    hint: context.tr(
                      vi: 'Nhập mô tả trình độ, chia tiền sân hoặc lưu ý khác...',
                      en: 'Enter description of skill level, fee division or other notes...',
                    ),
                    icon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSelectionSummary(),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  void _pickDate() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate != null
          ? DateTime.tryParse(_selectedDate!) ?? firstDate
          : firstDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = _formatDateQuery(picked);
        if (_isFixedMatchingSchedule) {
          _fixedStartDate ??= picked;
          if (_fixedDaysOfWeek.isEmpty) {
            _fixedDaysOfWeek.add(_apiWeekday(picked));
          }
        }
      });
      _loadSlots();
    }
  }

  void _pickFixedStartDate() async {
    final selected = _selectedDateAsDateTime() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fixedStartDate ?? selected,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fixedStartDate = picked;
      if (_fixedEndDate != null && _fixedEndDate!.isBefore(picked)) {
        _fixedEndDate = picked.add(const Duration(days: 30));
      }
      if (_fixedFrequency == 'WEEKLY' && _fixedDaysOfWeek.isEmpty) {
        _fixedDaysOfWeek.add(_apiWeekday(picked));
      }
    });
  }

  void _pickFixedEndDate() async {
    final start =
        _fixedStartDate ?? _selectedDateAsDateTime() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fixedEndDate ?? start.add(const Duration(days: 30)),
      firstDate: start,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _fixedEndDate = picked);
  }
}
