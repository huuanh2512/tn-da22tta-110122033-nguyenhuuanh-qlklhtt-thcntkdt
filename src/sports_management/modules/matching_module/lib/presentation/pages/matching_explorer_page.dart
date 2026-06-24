// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:facility_module/facility_module.dart';
import 'package:server_module/server_module.dart';
import 'package:booking_module/booking_module.dart';
import '../bloc/matching_bloc.dart';
import '../bloc/matching_event.dart';
import '../bloc/matching_state.dart';
import '../../domain/entities/matching_session_entity.dart';
import 'package:notification_module/notification_module.dart';

class MatchingExplorerPage extends StatefulWidget {
  const MatchingExplorerPage({super.key});

  @override
  State<MatchingExplorerPage> createState() => _MatchingExplorerPageState();
}

class _MatchingExplorerPageState extends State<MatchingExplorerPage> {
  List<FacilityEntity> _facilities = [];
  List<SportEntity> _sports = [];
  List<CourtEntity> _allCourts = [];
  String? _selectedSportId;
  String? _selectedFacilityId;
  String? _selectedDate;
  int? _neededSpots;
  List<MatchingSessionEntity>? _sessions;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _loadSessions();
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
      debugPrint('[MatchingExplorer] Error loading metadata: $e');
    }
  }

  void _loadSessions() {
    context.read<MatchingBloc>().add(
      LoadMatchingSessionsEvent(
        sportId: _selectedSportId,
        facilityId: _selectedFacilityId,
        bookingDate: _selectedDate,
        neededSpots: _neededSpots,
      ),
    );
  }

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final min = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  String _formatDateValue(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateLabel(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  bool _isSessionFull(MatchingSessionEntity session) {
    if (session.status == 'FULL') return true;
    if (session.teamMode != 'INDIVIDUAL') {
      return session.teamSize > 0 &&
          session.teamAOccupancy >= session.teamSize &&
          session.teamBOccupancy >= session.teamSize;
    }
    return session.userJoinStatus == 'FULL' ||
        (session.totalPlayersNeeded > 0 &&
            session.approvedCount >= session.totalPlayersNeeded);
  }

  String _sessionStatusLabel(MatchingSessionEntity session) {
    if (_isSessionFull(session)) {
      return context.tr(vi: 'Full phòng', en: 'Full');
    }
    return context.tr(vi: 'Đang ghép', en: 'Matching');
  }

  Future<void> _pickFilterDate(StateSetter setModalState) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selectedDate ?? '') ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setModalState(() => _selectedDate = _formatDateValue(selected));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(vi: 'Lobby Ghép Trận', en: 'Matchmaking Lobby'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.tune), onPressed: _showFilterSheet),
          IconButton(
            icon: const Icon(Icons.flash_on),
            color: const Color(0xFFFF5600),
            tooltip: context.tr(vi: 'Ghép tự động', en: 'Auto match'),
            onPressed: () async {
              await context.push('/matching/auto-lobby');
              _loadSessions();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadSessions();
        },
        color: const Color(0xFFFF5600),
        child: Column(
          children: [
            // Filter Bar Overview
            if (_selectedSportId != null ||
                _selectedFacilityId != null ||
                _selectedDate != null ||
                _neededSpots != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (_selectedSportId != null)
                              _buildActiveFilterChip(
                                _sports
                                        .firstWhere(
                                          (s) => s.id == _selectedSportId,
                                        )
                                        .name ??
                                    '',
                                () => setState(() {
                                  _selectedSportId = null;
                                  _sessions = null;
                                  _loadSessions();
                                }),
                              ),
                            if (_selectedFacilityId != null)
                              _buildActiveFilterChip(
                                _facilities
                                        .firstWhere(
                                          (f) => f.id == _selectedFacilityId,
                                        )
                                        .name ??
                                    '',
                                () => setState(() {
                                  _selectedFacilityId = null;
                                  _sessions = null;
                                  _loadSessions();
                                }),
                              ),
                            if (_selectedDate != null)
                              _buildActiveFilterChip(
                                _formatDateLabel(_selectedDate!),
                                () => setState(() {
                                  _selectedDate = null;
                                  _sessions = null;
                                  _loadSessions();
                                }),
                              ),
                            if (_neededSpots != null)
                              _buildActiveFilterChip(
                                context.tr(
                                  vi: 'Trống >= $_neededSpots chỗ',
                                  en: 'Min $_neededSpots spots available',
                                ),
                                () => setState(() {
                                  _neededSpots = null;
                                  _sessions = null;
                                  _loadSessions();
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedSportId = null;
                          _selectedFacilityId = null;
                          _selectedDate = null;
                          _neededSpots = null;
                          _sessions = null;
                        });
                        _loadSessions();
                      },
                      child: Text(
                        context.tr(vi: 'Xóa lọc', en: 'Clear filters'),
                        style: const TextStyle(color: Color(0xFFFF5600)),
                      ),
                    ),
                  ],
                ),
              ),

            // Main List Content
            Expanded(
              child: BlocBuilder<MatchingBloc, MatchingState>(
                buildWhen: (previous, current) =>
                    current is MatchingLoadingState ||
                    current is MatchingErrorState ||
                    current is MatchingSessionsLoadedState,
                builder: (context, state) {
                  if (state is MatchingLoadingState) {
                    if (_sessions == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF5600),
                        ),
                      );
                    }
                  }

                  if (state is MatchingErrorState) {
                    if (_sessions == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(state.errorMessage),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5600),
                              ),
                              onPressed: _loadSessions,
                              child: Text(
                                context.tr(vi: 'Thử lại', en: 'Retry'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  }

                  if (state is MatchingSessionsLoadedState) {
                    _sessions = state.sessions;
                  }

                  if (_sessions != null) {
                    final sessions = _sessions!;
                    if (sessions.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.25,
                          ),
                          Center(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.sports_outlined,
                                  size: 72,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  context.tr(
                                    vi: 'Chưa có phòng ghép nào được mở.',
                                    en: 'No matchmaking lobbies are open yet.',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.tr(
                                    vi: 'Hãy bấm "+" để khởi tạo hoặc dùng ghép tự động.',
                                    en: 'Press "+" to create one or use auto-matching.',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        return _buildSessionCard(sessions[index]);
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF5600),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await context.push('/matching/create');
          _loadSessions();
        },
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFF5600),
        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
        onDeleted: onDelete,
      ),
    );
  }

  Widget _buildSessionCard(MatchingSessionEntity session) {
    final theme = Theme.of(context);
    final isFull = _isSessionFull(session);
    final description = session.description.trim();
    final visibleDescription =
        description == 'Fixed matching schedule occurrence snapshot.'
        ? ''
        : description;
    final progress = session.totalPlayersNeeded > 0
        ? session.approvedCount / session.totalPlayersNeeded
        : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () async {
            await context.push('/matching/detail/${session.id}');
            _loadSessions();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Sport Name + Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF5600,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SportIconImage(
                              imageUrl: session.sportIconUrl,
                              fallbackIcon: Icons.sports_soccer,
                              fallbackColor: const Color(0xFFFF5600),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              session.sportName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        children: [
                          if (session.isFixedSchedule)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                context.tr(
                                  vi: 'Lịch cố định',
                                  en: 'Fixed schedule',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isFull
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _sessionStatusLabel(session),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isFull ? Colors.red : Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Center Title: Facility + Address
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        session.facilityName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (session.courtId != null)
                      Builder(
                        builder: (context) {
                          final court = _allCourts.firstWhere(
                            (c) => c.id == session.courtId,
                            orElse: () => CourtEntity(
                              id: '',
                              name: context.tr(
                                vi: 'Sân chưa xác định',
                                en: 'Undefined court',
                              ),
                            ),
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF5600,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              court.name ?? context.tr(vi: 'Sân', en: 'Court'),
                              style: const TextStyle(
                                color: Color(0xFFFF5600),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${DateDisplayFormatter.fromApiDate(session.occurrenceDate)} | ${_formatTime(session.startMinutes)} - ${_formatTime(session.endMinutes)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${context.tr(vi: 'Thanh toán', en: 'Payment')}: '
                        '${_paymentPolicyLabel(session.paymentPolicy)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.hintColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (session.isFixedSchedule) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.tr(vi: '', en: ''),
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Description snippet
                if (visibleDescription.isNotEmpty) ...[
                  Text(
                    visibleDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Footer: Host Info + Progress indicators
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: session.hostAvatarUrl.isNotEmpty
                          ? NetworkImage(session.hostAvatarUrl)
                          : null,
                      child: session.hostAvatarUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.hostName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            context.tr(vi: 'Host', en: 'Host'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Progress indicators
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${context.tr(vi: 'Thành viên: ', en: 'Members: ')}${session.approvedCount}/${session.totalPlayersNeeded}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 100,
                          height: 6,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              color: const Color(0xFFFF5600),
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(vi: 'Bộ lọc tìm kiếm', en: 'Search Filters'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sport Filter
                  Text(
                    context.tr(vi: 'Môn thể thao', en: 'Sport'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedSportId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    hint: Text(
                      context.tr(vi: 'Chọn bộ môn', en: 'Select sport'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: _sports.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() => _selectedSportId = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Facility Filter
                  Text(
                    context.tr(vi: 'Cơ sở', en: 'Facility'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedFacilityId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    hint: Text(
                      context.tr(vi: 'Chọn cơ sở sân', en: 'Select facility'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: _facilities.map((f) {
                      return DropdownMenuItem(
                        value: f.id,
                        child: Text(
                          f.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() => _selectedFacilityId = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  Text(
                    context.tr(vi: 'Ngày thi đấu', en: 'Match date'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _pickFilterDate(setModalState),
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.calendar_month_outlined),
                        suffixIcon: _selectedDate == null
                            ? const Icon(Icons.keyboard_arrow_down)
                            : IconButton(
                                tooltip: context.tr(
                                  vi: 'Bỏ chọn ngày',
                                  en: 'Clear date',
                                ),
                                onPressed: () =>
                                    setModalState(() => _selectedDate = null),
                                icon: const Icon(Icons.close),
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        _selectedDate == null
                            ? context.tr(vi: '7 ngày tới', en: 'Next 7 days')
                            : _formatDateLabel(_selectedDate!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Needed spots filter
                  Text(
                    context.tr(
                      vi: 'Số chỗ trống tối thiểu',
                      en: 'Minimum open spots',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _neededSpots,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    hint: Text(context.tr(vi: 'Bất kỳ', en: 'Any')),
                    items: [
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          context.tr(
                            vi: 'Trống ít nhất 1 chỗ',
                            en: 'At least 1 empty spot',
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(
                          context.tr(
                            vi: 'Trống ít nhất 2 chỗ',
                            en: 'At least 2 empty spots',
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text(
                          context.tr(
                            vi: 'Trống ít nhất 3 chỗ',
                            en: 'At least 3 empty spots',
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 5,
                        child: Text(
                          context.tr(
                            vi: 'Trống ít nhất 5 chỗ',
                            en: 'At least 5 empty spots',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setModalState(() => _neededSpots = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedSportId = null;
                              _selectedFacilityId = null;
                              _selectedDate = null;
                              _neededSpots = null;
                            });
                          },
                          child: Text(context.tr(vi: 'Đặt lại', en: 'Reset')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5600),
                          ),
                          onPressed: () {
                            setState(() {
                              _sessions = null;
                              // Sync back to page state
                            });
                            _loadSessions();
                            Navigator.pop(context);
                          },
                          child: Text(
                            context.tr(vi: 'Áp dụng', en: 'Apply'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
