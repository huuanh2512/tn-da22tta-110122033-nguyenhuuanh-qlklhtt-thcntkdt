// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:server_module/server_module.dart';
import 'package:facility_module/facility_module.dart';
import '../bloc/match_queue_bloc.dart';
import '../bloc/match_queue_event.dart';
import '../bloc/match_queue_state.dart';
import '../widgets/pulse_animation.dart';
import 'package:notification_module/notification_module.dart';

class AutoMatchingLobbyPage extends StatefulWidget {
  const AutoMatchingLobbyPage({super.key});

  @override
  State<AutoMatchingLobbyPage> createState() => _AutoMatchingLobbyPageState();
}

class _AutoMatchingLobbyPageState extends State<AutoMatchingLobbyPage> {
  List<FacilityEntity> _facilities = [];
  List<SportEntity> _sports = [];
  String? _selectedSportId;
  String? _selectedFacilityId;
  String? _selectedDate;
  int _startHour = 17;
  int _endHour = 21;
  int _groupSize = 4;
  String _teamMode = 'INDIVIDUAL';
  String _preferredTeam = 'AUTO';
  int _memberCount = 1;
  int _teamSize = 5;
  String _paymentPolicy = 'SPLIT_EQUALLY';

  Timer? _timer;
  Timer? _queueStatusTimer;
  int _elapsedSeconds = 0;
  bool _isPollingRequestInFlight = false;
  bool _wasSearching = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    context.read<MatchQueueBloc>().add(LoadQueueStatusEvent());
  }

  @override
  void dispose() {
    _stopSearching();
    super.dispose();
  }

  void _loadMetadata() async {
    try {
      final sportsResp = await GetIt.I<GetSportsUseCase>()();
      final facilitiesResp = await GetIt.I<GetFacilitiesUseCase>()();

      if (mounted) {
        setState(() {
          if (sportsResp.success && sportsResp.data != null) {
            _sports = sportsResp.data!;
          }
          if (facilitiesResp.success && facilitiesResp.data != null) {
            _facilities = facilitiesResp.data!;
          }
        });
      }
    } catch (e) {
      debugPrint('[AutoMatching] Error loading metadata: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _elapsedSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _startQueueStatusPolling() {
    if (_queueStatusTimer != null) return;
    _queueStatusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _isPollingRequestInFlight) return;
      _isPollingRequestInFlight = true;
      context.read<MatchQueueBloc>().add(LoadQueueStatusEvent(silent: true));
    });
  }

  void _stopQueueStatusPolling() {
    _queueStatusTimer?.cancel();
    _queueStatusTimer = null;
    _isPollingRequestInFlight = false;
  }

  void _stopSearching() {
    _stopTimer();
    _stopQueueStatusPolling();
  }

  void _leaveQueue() {
    _stopSearching();
    context.read<MatchQueueBloc>().add(LeaveQueueEvent());
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDateString(String dateStr) {
    try {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) {
        return DateDisplayFormatter.date(parsed);
      }
    } catch (_) {}
    return dateStr;
  }

  bool get _isTeamMode => _teamMode != 'INDIVIDUAL';

  int? _sportTeamSize(String? sportId) {
    for (final sport in _sports) {
      if (sport.id == sportId && sport is SportCatalogEntity) {
        return sport.teamSize;
      }
    }
    return null;
  }

  String _teamLabel(String teamCode) {
    if (teamCode == 'A') return 'Team A';
    if (teamCode == 'B') return 'Team B';
    return context.tr(vi: 'Tự động xếp đội', en: 'Auto assign');
  }

  void _joinQueue() {
    if (_selectedSportId == null ||
        _selectedFacilityId == null ||
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              vi: 'Vui lòng điền đầy đủ các trường thông tin',
              en: 'Please fill in all information fields',
            ),
          ),
        ),
      );
      return;
    }

    if (_endHour <= _startHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              vi: 'Giờ kết thúc phải lớn hơn giờ bắt đầu',
              en: 'End time must be after start time',
            ),
          ),
        ),
      );
      return;
    }

    if (_isTeamMode &&
        (_teamSize < 1 || _memberCount < 1 || _memberCount > _teamSize)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              vi: 'Số người đại diện phải từ 1 đến kích thước mỗi đội',
              en: 'Represented players must be between 1 and the team size',
            ),
          ),
        ),
      );
      return;
    }

    final data = {
      'sportId': _selectedSportId,
      'facilityId': _selectedFacilityId,
      'bookingDate': _selectedDate,
      'startMinutes': _startHour * 60,
      'endMinutes': _endHour * 60,
      'groupSize': _groupSize,
      'teamMode': _teamMode,
      'paymentPolicy': _paymentPolicy,
      if (_isTeamMode) 'preferredTeam': _preferredTeam,
      if (_isTeamMode) 'memberCount': _memberCount,
      if (_isTeamMode) 'teamSize': _teamSize,
    };

    context.read<MatchQueueBloc>().add(JoinQueueEvent(data));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(vi: 'Ghép Trận Tự Động', en: 'Auto Matchmaking'),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocConsumer<MatchQueueBloc, MatchQueueState>(
        listener: (context, state) {
          if (state is MatchQueueSearchingState) {
            _isPollingRequestInFlight = false;
            if (state.queue.status == 'SEARCHING') {
              _wasSearching = true;
              if (_timer == null) {
                _startTimer();
              }
              _startQueueStatusPolling();
            } else {
              _stopSearching();
            }
          } else if (state is MatchQueueIdleState) {
            final hadActiveQueue = _wasSearching;
            _wasSearching = false;
            _stopSearching();
            if (hadActiveQueue) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.tr(
                      vi: 'Yêu cầu ghép trận đã kết thúc. Bạn có thể đăng ký lại.',
                      en: 'This matchmaking request has ended. You can join again.',
                    ),
                  ),
                ),
              );
            }
          } else if (state is MatchQueueErrorState) {
            _wasSearching = false;
            _stopSearching();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is MatchQueueLoadingState) {
            // Keep current timers alive while an explicit action or a silent
            // polling request is in flight.
          } else {
            _wasSearching = false;
            _stopSearching();
          }
        },
        builder: (context, state) {
          if (state is MatchQueueLoadingState) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5600)),
            );
          }

          if (state is MatchQueueSearchingState) {
            final queue = state.queue;
            if (queue.status == 'MATCHED') {
              return _buildMatchedLobby(queue);
            }
            return _buildSearchingLobby(queue);
          }

          return _buildSetupForm(theme);
        },
      ),
    );
  }

  Widget _buildSearchingLobby(dynamic queue) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    Text(
                      context.tr(
                        vi: 'Hệ thống đang tìm trận...',
                        en: 'System is looking for a match...',
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        vi: 'Chúng tôi đang tìm những người chơi có cùng khung giờ rảnh và địa điểm.',
                        en: 'We are finding players with the same free hours and location.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 48),

                    // Radar pulse animation
                    const PulsingRadarWidget(size: 220),

                    const SizedBox(height: 48),
                    Text(
                      _formatDuration(_elapsedSeconds),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Details summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryRow(
                            Icons.sports_soccer,
                            context.tr(vi: 'Môn thể thao', en: 'Sport'),
                            queue.sportName,
                            imageUrl: queue.sportIconUrl,
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            Icons.location_on_outlined,
                            context.tr(vi: 'Cơ sở', en: 'Facility'),
                            queue.facilityName,
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            Icons.calendar_month_outlined,
                            context.tr(vi: 'Ngày đấu', en: 'Date'),
                            _formatDateString(
                              queue.bookingDate?.toString() ?? '',
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            Icons.access_time,
                            context.tr(vi: 'Thời gian rảnh', en: 'Free Time'),
                            queue.timeRange,
                          ),
                          if (queue.teamMode != 'INDIVIDUAL') ...[
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              Icons.groups_outlined,
                              context.tr(vi: 'Chế độ', en: 'Mode'),
                              queue.teamMode == 'TEAM_VS_TEAM'
                                  ? context.tr(
                                      vi: 'Đội vs đội',
                                      en: 'Team vs team',
                                    )
                                  : context.tr(
                                      vi: 'Ghép theo đội',
                                      en: 'Team fill',
                                    ),
                            ),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              Icons.swap_horiz,
                              context.tr(
                                vi: 'Đội mong muốn',
                                en: 'Preferred team',
                              ),
                              _teamLabel(queue.preferredTeam),
                            ),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              Icons.person_outline,
                              context.tr(
                                vi: 'Số người đại diện',
                                en: 'Represented players',
                              ),
                              '${queue.memberCount}',
                            ),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              Icons.format_list_numbered,
                              context.tr(
                                vi: 'Số người mỗi đội',
                                en: 'Team size',
                              ),
                              '${queue.teamSize ?? 0}',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Leave queue button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _leaveQueue,
                child: Text(
                  context.tr(vi: 'HỦY TÌM KIẾM', en: 'CANCEL SEARCH'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchedLobby(dynamic queue) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 88),
          const SizedBox(height: 24),
          Text(
            context.tr(
              vi: 'Đã ghép trận thành công',
              en: 'Match found successfully',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              vi: 'Hệ thống đã giữ sân và tạo phòng ghép cho bạn.',
              en: 'The system has reserved a court and created your match lobby.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _buildSummaryRow(
            Icons.calendar_month_outlined,
            context.tr(vi: 'Ngày đấu', en: 'Date'),
            _formatDateString(queue.bookingDate?.toString() ?? ''),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            Icons.access_time,
            context.tr(vi: 'Thời gian', en: 'Time'),
            queue.timeRange,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: queue.matchingSessionId == null
                  ? null
                  : () => context.push(
                      '/matching/detail/${queue.matchingSessionId}',
                    ),
              child: Text(
                context.tr(vi: 'Xem phòng ghép', en: 'View match lobby'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    IconData icon,
    String label,
    String value, {
    String? imageUrl,
  }) {
    return Row(
      children: [
        SportIconImage(
          imageUrl: imageUrl,
          fallbackIcon: icon,
          fallbackColor: Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSetupForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              vi: 'Chọn Tiêu Chí Ghép Trận',
              en: 'Select Match Criteria',
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              vi: 'Hệ thống sẽ gom các nhóm có chung nhu cầu để tạo phòng đấu tối ưu nhất.',
              en: 'The system will group players with the same needs to create the optimal match lobby.',
            ),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Sport selection
          Text(
            context.tr(vi: 'Bộ môn thể thao', en: 'Sport'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedSportId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            hint: Text(context.tr(vi: 'Chọn bộ môn', en: 'Select sport')),
            items: _sports.map((s) {
              return DropdownMenuItem(value: s.id, child: Text(s.name ?? ''));
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedSportId = val;
                final configuredTeamSize = _sportTeamSize(val);
                if (configuredTeamSize != null && configuredTeamSize > 0) {
                  _teamSize = configuredTeamSize;
                  if (_memberCount > _teamSize) {
                    _memberCount = _teamSize;
                  }
                }
              });
            },
          ),
          const SizedBox(height: 16),

          Text(
            context.tr(vi: 'Kiểu ghép trận', en: 'Matching mode'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _teamMode,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            items: [
              DropdownMenuItem(
                value: 'INDIVIDUAL',
                child: Text(
                  context.tr(
                    vi: 'Ghép cá nhân / thông thường',
                    en: 'Individual matching',
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'TEAM_FILL',
                child: Text(context.tr(vi: 'Ghép theo đội', en: 'Team fill')),
              ),
              DropdownMenuItem(
                value: 'TEAM_VS_TEAM',
                child: Text(context.tr(vi: 'Đội vs đội', en: 'Team vs team')),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _teamMode = value ?? 'INDIVIDUAL';
                _preferredTeam = 'AUTO';
                _paymentPolicy = _teamMode == 'TEAM_VS_TEAM'
                    ? 'TEAM_REPRESENTATIVES_SPLIT'
                    : 'SPLIT_EQUALLY';
              });
            },
          ),
          if (_isTeamMode) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNumberDropdown(
                    label: context.tr(vi: 'Số người mỗi đội', en: 'Team size'),
                    value: _teamSize,
                    values: List.generate(10, (index) => index + 1),
                    onChanged: (value) {
                      setState(() {
                        _teamSize = value;
                        if (_memberCount > value) {
                          _memberCount = value;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberDropdown(
                    label: context.tr(
                      vi: 'Số người bạn đại diện',
                      en: 'Players represented',
                    ),
                    value: _memberCount,
                    values: List.generate(_teamSize, (index) => index + 1),
                    onChanged: (value) {
                      setState(() => _memberCount = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(vi: 'Đội mong muốn', en: 'Preferred team'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _preferredTeam,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              items: [
                DropdownMenuItem(
                  value: 'AUTO',
                  child: Text(
                    context.tr(vi: 'Hệ thống tự xếp', en: 'Auto assign'),
                  ),
                ),
                const DropdownMenuItem(value: 'A', child: Text('Team A')),
                const DropdownMenuItem(value: 'B', child: Text('Team B')),
              ],
              onChanged: (value) {
                setState(() => _preferredTeam = value ?? 'AUTO');
              },
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(vi: 'Cách chia thanh toán', en: 'Payment policy'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _paymentPolicy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              items: [
                DropdownMenuItem(
                  value: 'SPLIT_EQUALLY',
                  child: Text(
                    context.tr(
                      vi: 'Chia đều theo tài khoản',
                      en: 'Split between app users',
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'TEAM_REPRESENTATIVES_SPLIT',
                  child: Text(
                    context.tr(
                      vi: 'Đại diện mỗi đội trả một nửa',
                      en: 'Team representatives split',
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _paymentPolicy = value ?? 'SPLIT_EQUALLY';
                });
              },
            ),
          ],
          const SizedBox(height: 16),

          // Facility selection
          Text(
            context.tr(vi: 'Địa điểm / Cụm sân', en: 'Location / Facilities'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedFacilityId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            hint: Text(context.tr(vi: 'Chọn cơ sở sân', en: 'Select facility')),
            items: _facilities.map((f) {
              return DropdownMenuItem(value: f.id, child: Text(f.name ?? ''));
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedFacilityId = val;
              });
            },
          ),
          const SizedBox(height: 16),

          // Date Selection
          Text(
            context.tr(vi: 'Ngày chơi', en: 'Play Date'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDate != null
                        ? DateDisplayFormatter.date(
                            DateTime.parse(_selectedDate!),
                          )
                        : context.tr(vi: 'Chọn ngày chơi', en: 'Select date'),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time range selection
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(vi: 'Rảnh từ', en: 'Free from'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _startHour,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      items: List.generate(24, (index) {
                        return DropdownMenuItem(
                          value: index,
                          child: Text('$index:00'),
                        );
                      }),
                      onChanged: (val) {
                        setState(() {
                          _startHour = val ?? 17;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(vi: 'Đến', en: 'To'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _endHour,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      items: List.generate(24, (index) {
                        return DropdownMenuItem(
                          value: index,
                          child: Text('$index:00'),
                        );
                      }),
                      onChanged: (val) {
                        setState(() {
                          _endHour = val ?? 21;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!_isTeamMode) ...[
            Text(
              context.tr(
                vi: 'Tổng số người cần cho trận',
                en: 'Total players needed',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _groupSize,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              items: [
                DropdownMenuItem(
                  value: 2,
                  child: Text(context.tr(vi: '2 người', en: '2 players')),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Text(context.tr(vi: '3 người', en: '3 players')),
                ),
                DropdownMenuItem(
                  value: 4,
                  child: Text(context.tr(vi: '4 người', en: '4 players')),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _groupSize = val ?? 4;
                });
              },
            ),
          ],
          const SizedBox(height: 40),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _joinQueue,
              child: Text(
                context.tr(vi: 'BẮT ĐẦU TÌM KIẾM', en: 'START SEARCH'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberDropdown({
    required String label,
    required int value,
    required List<int> values,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: value,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
          ),
          items: values
              .map(
                (item) =>
                    DropdownMenuItem<int>(value: item, child: Text('$item')),
              )
              .toList(),
          onChanged: (item) {
            if (item != null) onChanged(item);
          },
        ),
      ],
    );
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }
}
