import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:app_module/app_module.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:server_module/server_module.dart';
import 'package:booking_module/booking_module.dart';
import 'package:facility_module/facility_module.dart';

class StaffCourtReportPage extends StatefulWidget {
  final String? facilityId;

  const StaffCourtReportPage({super.key, this.facilityId});

  @override
  State<StaffCourtReportPage> createState() => _StaffCourtReportPageState();
}

class _StaffCourtReportPageState extends State<StaffCourtReportPage> {
  static const _allSportsValue = '__all_sports__';

  bool _isLoading = true;
  String? _selectedFacilityId;
  String? _selectedSportId;
  String? _selectedCourtId;
  List<FacilityEntity> _facilities = [];
  List<SportEntity> _sports = [];
  List<CourtEntity> _courts = [];
  AdvancedPerformanceReportEntity? _report;
  String? _errorMessage;
  String _selectedRange = 'All'; // 'Day', 'Week', 'Month', 'All'

  @override
  void initState() {
    super.initState();
    _selectedFacilityId = widget.facilityId;
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _courts = [];
      _report = null;
    });

    try {
      final userRes = await GetIt.I<GetLocalUserUseCase>()();
      final user = userRes.fold((_) => null, (u) => u);
      if (user == null || user.userId == null) {
        setState(() {
          _errorMessage = 'Không thể xác thực tài khoản.';
          _isLoading = false;
        });
        return;
      }

      // 1. Fetch facilities
      final getFacilitiesUseCase = GetIt.I<GetFacilitiesUseCase>();
      final facilitiesResponse = await getFacilitiesUseCase();
      if (!facilitiesResponse.success || facilitiesResponse.data == null) {
        setState(() {
          _errorMessage = facilitiesResponse.message ?? 'Lỗi tải cơ sở.';
          _isLoading = false;
        });
        return;
      }

      final allFacilities = facilitiesResponse.data!;
      _facilities = allFacilities;
      if (user.role == 'STAFF') {
        _facilities = allFacilities
            .where((f) => f.ownerId == user.userId)
            .toList();
        if (_selectedFacilityId != null) {
          _facilities = allFacilities
              .where((f) => f.id == _selectedFacilityId)
              .toList();
        }
        if (_facilities.isEmpty) {
          setState(() {
            _errorMessage = 'Tài khoản nhân viên chưa được phân quyền cơ sở.';
            _isLoading = false;
          });
          return;
        }
      }

      if (_selectedFacilityId == null && _facilities.isNotEmpty) {
        _selectedFacilityId = _facilities.first.id;
      }

      if (_selectedFacilityId != null) {
        // 2. Fetch courts and sports available for the selected facility.
        final getCourtsUseCase = GetIt.I<GetCourtsUseCase>();
        final getSportsUseCase = GetIt.I<GetSportsUseCase>();
        final courtsResponse = await getCourtsUseCase(
          facilityId: _selectedFacilityId,
        );
        final sportsResponse = await getSportsUseCase();
        if (courtsResponse.success && courtsResponse.data != null) {
          _courts = courtsResponse.data!;
        } else {
          setState(() {
            _errorMessage = courtsResponse.message ?? 'Lỗi tải danh sách sân.';
            _isLoading = false;
          });
          return;
        }
        if (sportsResponse.success && sportsResponse.data != null) {
          _sports = sportsResponse.data!;
        } else {
          setState(() {
            _errorMessage =
                sportsResponse.message ??
                'Không thể tải danh sách môn thể thao.';
            _isLoading = false;
          });
          return;
        }

        final availableSportIds = _courts
            .map((court) => court.sportId)
            .whereType<String>()
            .toSet();
        if (_selectedSportId != null &&
            !availableSportIds.contains(_selectedSportId)) {
          _selectedSportId = null;
        }
        if (_selectedCourtId != null &&
            !_courts.any((court) => court.id == _selectedCourtId)) {
          _selectedCourtId = null;
        }

        // 3. Fetch aggregate report
        final getReportUseCase = GetIt.I<GetAdvancedPerformanceReportUseCase>();
        final dateBounds = _dateBoundsForRange(_selectedRange);
        final reportResponse = await getReportUseCase(
          facilityId: _selectedFacilityId,
          sportId: _selectedSportId,
          courtId: _selectedCourtId,
          dateFrom: dateBounds.$1,
          dateTo: dateBounds.$2,
          include:
              'summary,courtStats,peakHours,customerStats,sportStats,facilityStats',
        );
        if (reportResponse.success && reportResponse.data != null) {
          _report = reportResponse.data;
        } else {
          setState(() {
            _errorMessage =
                reportResponse.message ?? 'Không thể tải dữ liệu báo cáo.';
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Đã xảy ra lỗi: $e';
        _isLoading = false;
      });
    }
  }

  (String, String) _dateBoundsForRange(String range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (range) {
      'Day' => today,
      'Week' => today.subtract(const Duration(days: 6)),
      'Month' => today.subtract(const Duration(days: 29)),
      _ => today.subtract(const Duration(days: 364)),
    };

    String format(DateTime date) =>
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return (format(start), format(today));
  }

  String _formatCurrency(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
  }

  Widget _buildRangeFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildRangeChip('Hôm nay', 'Day'),
          _buildRangeChip('7 ngày qua', 'Week'),
          _buildRangeChip('30 ngày qua', 'Month'),
          _buildRangeChip('12 tháng', 'All'),
        ],
      ),
    );
  }

  Widget _buildRangeChip(String label, String value) {
    final isSelected = _selectedRange == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFFFF5600),
        labelStyle: TextStyle(
          color: isSelected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (val) {
          if (val) {
            setState(() {
              _selectedRange = value;
            });
            _loadReportData();
          }
        },
      ),
    );
  }

  List<SportEntity> get _availableSports => _sports
      .where(
        (sport) => _courts.any((court) => court.sportId == sport.id),
      )
      .toList();

  Future<void> _showSportFilterPopup() async {
    final selected = await AppPopup.showSelection<String>(
      context,
      title: 'Chọn môn thể thao',
      subtitle: 'Lọc báo cáo hiệu suất theo môn thể thao.',
      icon: Icons.sports_soccer_outlined,
      confirmLabel: 'Áp dụng',
      searchHint: 'Tìm môn thể thao...',
      selectedValue: _selectedSportId ?? _allSportsValue,
      options: [
        const AppPopupOption<String>(
          value: _allSportsValue,
          label: 'Tất cả môn thể thao',
          icon: Icons.select_all_rounded,
        ),
        ..._availableSports.map(
          (sport) => AppPopupOption<String>(
            value: sport.id,
            label: sport.name ?? 'Môn thể thao',
            icon: Icons.sports_soccer_outlined,
            imageUrl: sport.iconUrl,
          ),
        ),
      ],
    );
    if (selected == null || !mounted) return;

    setState(() {
      _selectedSportId = selected == _allSportsValue ? null : selected;
      _selectedCourtId = null;
    });
    _loadReportData();
  }

  Widget _buildSportFilterPopupButton() {
    final matchingSports = _availableSports
        .where((sport) => sport.id == _selectedSportId)
        .toList();
    final selectedSportName =
        matchingSports.isEmpty ? null : matchingSports.first.name;
    final isSelected = _selectedSportId != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showSportFilterPopup,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Lọc theo môn thể thao',
            prefixIcon: const Icon(Icons.sports),
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: isSelected ? const Color(0xFFFF5600) : Colors.grey,
              ),
            ),
          ),
          child: Text(
            selectedSportName ?? 'Tất cả môn thể thao',
            style: TextStyle(
              color: isSelected ? const Color(0xFFFF5600) : null,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;
    final totalActiveCount = report?.summary.activeBookings ?? 0;
    final peakHours = report?.peakHours ?? const <AdvancedPeakHourStatEntity>[];
    final topCustomers =
        report?.customerStats ?? const <ReportCustomerStatEntity>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BÁO CÁO & HIỆU SUẤT',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5600)),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadReportData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5600),
                      ),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadReportData,
              color: const Color(0xFFFF5600),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Facility Selector Dropdown
                    if (_facilities.isNotEmpty) ...[
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.business,
                                color: Color(0xFFFF5600),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedFacilityId,
                                    isExpanded: true,
                                    items: _facilities.map((f) {
                                      return DropdownMenuItem<String>(
                                        value: f.id,
                                        child: Text(
                                          f.name ?? 'Cơ sở',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedFacilityId = val;
                                          _selectedSportId = null;
                                          _selectedCourtId = null;
                                        });
                                        _loadReportData();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_sports.isNotEmpty) ...[
                      _buildSportFilterPopupButton(),
                      const SizedBox(height: 16),
                    ],

                    if (_courts.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        key: ValueKey(
                          'court-$_selectedFacilityId-$_selectedSportId',
                        ),
                        initialValue: _selectedCourtId,
                        decoration: const InputDecoration(
                          labelText: 'Lọc theo sân',
                          prefixIcon: Icon(Icons.sports_soccer),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tất cả sân'),
                          ),
                          ..._courts
                              .where(
                                (court) =>
                                    _selectedSportId == null ||
                                    court.sportId == _selectedSportId,
                              )
                              .map(
                                (court) => DropdownMenuItem<String?>(
                                  value: court.id,
                                  child: Text(court.name ?? 'Sân đấu'),
                                ),
                              ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCourtId = value);
                          _loadReportData();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildRangeFilterRow(),
                    const SizedBox(height: 16),

                    // OVERVIEW CARDS
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Doanh thu thực nhận',
                            _formatCurrency(report?.summary.paidRevenue ?? 0),
                            Icons.payments,
                            Colors.green,
                            theme,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Ca đấu',
                            '$totalActiveCount lượt',
                            Icons.sports_soccer,
                            Colors.blue,
                            theme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // COURT OCCUPANCY BREAKDOWN
                    const Text(
                      'HIỆU SUẤT KHAI THÁC TỪNG SÂN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (report == null || report.courtStats.isEmpty)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'Cơ sở này hiện chưa có sân đấu nào.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      )
                    else
                      ...report.courtStats.map((court) {
                        final pct = court.utilizationRate.clamp(0.0, 1.0);
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      court.courtName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (court.status == 'ACTIVE'
                                                    ? Colors.green
                                                    : Colors.red)
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        court.status == 'ACTIVE'
                                            ? 'Hoạt động'
                                            : 'Tạm khóa',
                                        style: TextStyle(
                                          color: court.status == 'ACTIVE'
                                              ? Colors.green.shade800
                                              : Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (court.sportName.isNotEmpty ||
                                    court.facilityName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      if (court.sportName.isNotEmpty)
                                        court.sportName,
                                      if (court.facilityName.isNotEmpty)
                                        court.facilityName,
                                    ].join(' • '),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${court.activeBookings} lượt, '
                                      '${court.bookedMinutes ~/ 60} giờ đã đặt',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(court.paidRevenue),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Đã đặt: ${court.bookedMinutes} phút  •  '
                                  'Khả dụng: ${court.availableMinutes} phút',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Bảo trì/khóa: ${court.unavailableMinutes} phút'
                                  ' (${court.blockCount} block)  •  '
                                  'Hiệu suất: '
                                  '${(court.utilizationRate * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 8,
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    color: const Color(0xFFFF5600),
                                  ),
                                ),
                                if (court.utilizationNote.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    court.utilizationNote,
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    if (report != null &&
                        report.utilizationNote.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        report.utilizationNote,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // PEAK HOURS DISTRIBUTION
                    const Text(
                      'PHÂN BỔ KHUNG GIỜ CAO ĐIỂM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildTimeDistributionRow(
                              'Sáng (Trước 12h)',
                              peakHours.isNotEmpty
                                  ? peakHours[0].bookingCount
                                  : 0,
                              totalActiveCount,
                              Colors.orange,
                            ),
                            const Divider(height: 24),
                            _buildTimeDistributionRow(
                              'Chiều (12h - 17h)',
                              peakHours.length > 1
                                  ? peakHours[1].bookingCount
                                  : 0,
                              totalActiveCount,
                              Colors.blue,
                            ),
                            const Divider(height: 24),
                            _buildTimeDistributionRow(
                              'Tối (Sau 17h)',
                              peakHours.length > 2
                                  ? peakHours[2].bookingCount
                                  : 0,
                              totalActiveCount,
                              Colors.indigo,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // CUSTOMER LEADERBOARD
                    const Text(
                      'TOP KHÁCH HÀNG THÂN THIẾT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (topCustomers.isEmpty)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'Chưa có lịch sử khách đặt sân.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      )
                    else
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: topCustomers.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final customer = topCustomers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(
                                  0xFFFF5600,
                                ).withValues(alpha: 0.1),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Color(0xFFFF5600),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                customer.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                '${customer.bookingCount} lượt đặt',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                _formatCurrency(customer.paidRevenue),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
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

  Widget _buildTimeDistributionRow(
    String period,
    int count,
    int total,
    Color barColor,
  ) {
    final double pct = total > 0 ? (count / total) : 0.0;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            period,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              color: barColor,
              backgroundColor: barColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: Text(
            '$count lượt',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
