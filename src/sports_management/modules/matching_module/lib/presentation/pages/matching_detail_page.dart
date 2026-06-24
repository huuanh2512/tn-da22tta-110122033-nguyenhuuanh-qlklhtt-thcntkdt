import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:server_module/server_module.dart';
import 'package:booking_module/booking_module.dart';
import '../bloc/matching_bloc.dart';
import '../bloc/matching_event.dart';
import '../bloc/matching_state.dart';
import '../../domain/entities/matching_session_entity.dart';
import '../../domain/entities/matching_member_entity.dart';
import '../../data/datasources/remote/matching_remote_data_source.dart';
import 'package:notification_module/notification_module.dart';

class MatchingDetailPage extends StatefulWidget {
  final String sessionId;

  const MatchingDetailPage({super.key, required this.sessionId});

  @override
  State<MatchingDetailPage> createState() => _MatchingDetailPageState();
}

class _MatchingDetailPageState extends State<MatchingDetailPage> {
  String? _currentUserId;
  List<CourtEntity> _allCourts = [];
  late MatchingBloc _matchingBloc;

  @override
  void initState() {
    super.initState();
    _matchingBloc = context.read<MatchingBloc>();
    _loadUserAndConnectSocket();
    _matchingBloc.add(LoadMatchingSessionDetailEvent(widget.sessionId));
  }

  void _loadUserAndConnectSocket() async {
    try {
      final courtsResp = await GetIt.I<GetCourtsUseCase>()();
      if (courtsResp.success && courtsResp.data != null) {
        if (mounted) {
          setState(() {
            _allCourts = courtsResp.data!;
          });
        }
      }

      final userResult = await GetIt.I<GetLocalUserUseCase>()();
      final user = userResult.fold((_) => null, (u) => u);
      if (user != null) {
        if (mounted) {
          setState(() {
            _currentUserId = user.userId;
          });
        }
        final token = await AuthTokenProviderRegistry.currentToken();
        if (token != null && token.isNotEmpty) {
          GetIt.I<MatchingRemoteDataSource>().connectSocket(token);
        }
      }
    } catch (e) {
      debugPrint('[MatchingDetail] Error connecting socket: $e');
    }

    if (mounted) {
      _matchingBloc.add(StartListeningToSessionEvent(widget.sessionId));
    }
  }

  @override
  void dispose() {
    _matchingBloc.add(StopListeningToSessionEvent(widget.sessionId));
    super.dispose();
  }

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final min = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
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

  String _statusLabel(MatchingSessionEntity session) {
    if (session.status == 'COMPLETED') {
      return context.tr(vi: 'Đã hoàn thành', en: 'Completed');
    }
    if (session.status == 'CANCELLED') {
      return context.tr(vi: 'Đã hủy', en: 'Cancelled');
    }
    if (_isSessionFull(session)) {
      return session.isFixedSchedule
          ? context.tr(vi: 'Đã đủ đội', en: 'Teams full')
          : context.tr(vi: 'Phòng đã đủ người', en: 'Lobby is full');
    }
    return context.tr(vi: 'Đang ghép', en: 'Matching');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(vi: 'Chi Tiết Kèo Đấu', en: 'Match Details')),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
            if (state.session != null) {
              // Reload detail with the updated session
              context.read<MatchingBloc>().add(
                LoadMatchingSessionDetailEvent(widget.sessionId),
              );
            }
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
          if (state is MatchingLoadingState && _currentUserId == null) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5600)),
            );
          }

          if (state is MatchingErrorState && _currentUserId == null) {
            return Center(child: Text(state.errorMessage));
          }

          MatchingSessionEntity? session;
          if (state is MatchingSessionDetailLoadedState) {
            session = state.session;
          } else if (state is MatchingActionSuccessState &&
              state.session != null) {
            session = state.session;
          }

          if (session == null) {
            return Center(
              child: Text(
                context.tr(
                  vi: 'Đang tải phòng ghép trận...',
                  en: 'Loading match lobby...',
                ),
              ),
            );
          }

          final isHost = session.hostId == _currentUserId;
          final isMember = session.members.any(
            (m) => m.userId == _currentUserId,
          );
          final memberStatus = isMember
              ? session.members
                    .firstWhere((m) => m.userId == _currentUserId)
                    .status
              : null;
          final isFull =
              _isSessionFull(session) || session.status == 'COMPLETED';
          final isCancelled = session.status == 'CANCELLED';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session Card Details
                _buildHeaderCard(session, isCancelled),
                const SizedBox(height: 24),

                // Description
                if (session.description.isNotEmpty) ...[
                  Text(
                    context.tr(vi: 'Mô tả kèo đấu', en: 'Match description'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      session.description,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (session.teamMode == 'INDIVIDUAL') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${context.tr(vi: 'Thành viên', en: 'Members')} (${session.approvedCount}/${session.totalPlayersNeeded})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (session.autoApprove)
                        Text(
                          context.tr(vi: 'Duyệt tự động', en: 'Auto approve'),
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHostTile(session),
                  ...session.members.map(
                    (m) => _buildMemberTile(m, session!, isHost),
                  ),
                ] else
                  _buildTeams(session, isHost),

                const SizedBox(height: 40),

                // Bottom Action buttons
                if (!isCancelled)
                  _buildActionButtons(
                    session,
                    isHost,
                    isMember,
                    memberStatus,
                    isFull,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(MatchingSessionEntity session, bool isCancelled) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCancelled
            ? Colors.grey.shade100
            : const Color(0xFFFF5600).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCancelled
              ? Colors.grey.shade300
              : const Color(0xFFFF5600).withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCancelled ? Colors.grey : const Color(0xFFFF5600),
                  shape: BoxShape.circle,
                ),
                child: SportIconImage(
                  imageUrl: session.sportIconUrl,
                  fallbackIcon: Icons.sports_soccer,
                  fallbackColor: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.sportName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${context.tr(vi: 'Trạng thái: ', en: 'Status: ')}${_statusLabel(session)}',
                      style: TextStyle(
                        color: isCancelled
                            ? Colors.red
                            : _isSessionFull(session)
                            ? Colors.blue
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (session.isFixedSchedule) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          vi: 'Lịch cố định - tham gia theo ngày',
                          en: 'Fixed schedule - one day only',
                        ),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${session.facilityName} (${session.facilityCity})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (session.courtId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.grid_3x3, color: Colors.grey, size: 18),
                const SizedBox(width: 8),
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
                    return Text(
                      '${context.tr(vi: 'Sân: ', en: 'Court: ')}${court.name ?? context.tr(vi: 'Sân', en: 'Court')}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF5600),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${context.tr(vi: 'Ngày: ', en: 'Date: ')}${DateDisplayFormatter.fromApiDate(session.occurrenceDate)}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time_outlined,
                color: Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${context.tr(vi: 'Giờ: ', en: 'Time: ')}${_formatTime(session.startMinutes)} - ${_formatTime(session.endMinutes)}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHostTile(MatchingSessionEntity session) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade300,
          backgroundImage: session.hostAvatarUrl.isNotEmpty
              ? NetworkImage(session.hostAvatarUrl)
              : null,
          child: session.hostAvatarUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        title: Text(
          session.hostRepresentedCount > 1
              ? '${session.hostName} (+${session.hostRepresentedCount - 1})'
              : session.hostName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          session.hostEmail,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5600).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'HOST',
            style: TextStyle(
              color: Color(0xFFFF5600),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeams(MatchingSessionEntity session, bool isHost) {
    Widget teamPanel(String teamCode, int occupancy) {
      final members = session.members
          .where((member) => member.teamCode == teamCode)
          .toList();
      final hostInTeam = session.hostTeamCode == teamCode;
      final teamName = teamCode == 'A' ? session.teamAName : session.teamBName;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$teamName: $occupancy/${session.teamSize}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (teamCode == 'B' &&
              session.teamBJoinType == 'TEAM_REPRESENTATIVE') ...[
            const SizedBox(height: 4),
            Text(
              context.tr(
                vi: 'Đại diện: ${session.teamBRepresentativeName ?? ''}',
                en: 'Representative: ${session.teamBRepresentativeName ?? ''}',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (hostInTeam) _buildHostTile(session),
          ...members.map((member) => _buildMemberTile(member, session, isHost)),
          if (!hostInTeam && members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                context.tr(vi: 'Chưa có thành viên', en: 'No members yet'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final teamA = teamPanel('A', session.teamAOccupancy);
        final teamB = teamPanel('B', session.teamBOccupancy);

        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [teamA, const SizedBox(height: 20), teamB],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: teamA),
            const SizedBox(width: 16),
            Expanded(child: teamB),
          ],
        );
      },
    );
  }

  Widget _buildMemberTile(
    MatchingMemberEntity member,
    MatchingSessionEntity session,
    bool isHost,
  ) {
    final theme = Theme.of(context);
    final isPending = member.status == 'PENDING';
    final isApproved = member.status == 'APPROVED';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade300,
          backgroundImage: member.avatarUrl.isNotEmpty
              ? NetworkImage(member.avatarUrl)
              : null,
          child: member.avatarUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        title: Text(
          member.representedCount > 1
              ? '${member.name} (+${member.representedCount - 1})'
              : member.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.joinMode == 'TEAM_REPRESENTATIVE')
              Text(
                context.tr(
                  vi: 'Đại diện ${member.teamName}',
                  en: 'Represents ${member.teamName}',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              isPending
                  ? context.tr(vi: 'Chờ duyệt', en: 'Pending')
                  : context.tr(vi: 'Đã tham gia', en: 'Joined'),
              style: TextStyle(
                color: isPending ? Colors.orange : Colors.green,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: isHost && isPending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () {
                      context.read<MatchingBloc>().add(
                        UpdateMemberStatusEvent(
                          sessionId: session.id,
                          userId: member.userId,
                          status: 'APPROVED',
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () {
                      context.read<MatchingBloc>().add(
                        UpdateMemberStatusEvent(
                          sessionId: session.id,
                          userId: member.userId,
                          status: 'REJECTED',
                        ),
                      );
                    },
                  ),
                ],
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isApproved
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  member.status == 'APPROVED'
                      ? context.tr(vi: 'Đã tham gia', en: 'Joined')
                      : member.status == 'PENDING'
                      ? context.tr(vi: 'Chờ duyệt', en: 'Pending')
                      : context.tr(vi: 'Bị từ chối', en: 'Rejected'),
                  style: TextStyle(
                    color: isApproved ? Colors.green : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildActionButtons(
    MatchingSessionEntity session,
    bool isHost,
    bool isMember,
    String? memberStatus,
    bool isFull,
  ) {
    if (isHost) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () {
            _showCancelConfirmation(session.id);
          },
          child: Text(
            context.tr(vi: 'HỦY KÈO ĐẤU', en: 'CANCEL MATCH'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (isMember) {
      return SizedBox(
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
          onPressed: () {
            context.read<MatchingBloc>().add(
              LeaveMatchingSessionEvent(session.id),
            );
          },
          child: Text(
            context.tr(vi: 'RỜI KÈO ĐẤU', en: 'LEAVE MATCH'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      );
    }

    if (session.userJoinStatus == 'TEAM_REPRESENTATIVE_EXISTS') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          context.tr(
            vi: 'Team B đã có đội tham gia.',
            en: 'Team B already has a participating team.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Guest not registered yet
    if (isFull) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Center(
          child: Text(
            _statusLabel(session),
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session.isFixedSchedule) ...[
            Text(
              context.tr(vi: '', en: ''),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                if (session.teamMode == 'INDIVIDUAL') {
                  context.read<MatchingBloc>().add(
                    JoinMatchingSessionEvent(
                      session.id,
                      data: const {'joinMode': 'INDIVIDUAL'},
                    ),
                  );
                } else {
                  _showJoinModeSheet(session);
                }
              },
              child: Text(
                session.isFixedSchedule
                    ? context.tr(vi: 'THAM GIA NGÀY NÀY', en: 'JOIN THIS DAY')
                    : context.tr(vi: 'XIN GIA NHẬP KÈO', en: 'REQUEST TO JOIN'),
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

  Future<void> _showJoinModeSheet(MatchingSessionEntity session) async {
    final representativeDisabled = session.teamBJoinType != 'EMPTY';
    final representativeMessage = session.teamBJoinType == 'TEAM_REPRESENTATIVE'
        ? context.tr(
            vi: 'Team B đã có đội tham gia.',
            en: 'Team B already has a participating team.',
          )
        : context.tr(
            vi: 'Team B đã có người tham gia lẻ.',
            en: 'Team B already has individual players.',
          );

    final selectedMode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  vi: 'Bạn muốn tham gia bằng cách nào?',
                  en: 'How would you like to join?',
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(
                  context.tr(vi: 'Tham gia cá nhân', en: 'Join individually'),
                ),
                subtitle: Text(
                  context.tr(
                    vi: 'Bạn được thêm vào Team B của buổi này.',
                    en: 'You will join Team B for this occurrence.',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(sheetContext, 'INDIVIDUAL'),
              ),
              const Divider(),
              ListTile(
                enabled: !representativeDisabled,
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                title: Text(
                  context.tr(vi: 'Đại diện một đội', en: 'Represent a team'),
                ),
                subtitle: Text(
                  representativeDisabled
                      ? representativeMessage
                      : context.tr(
                          vi: 'Đăng ký Team B bằng tên đội và quân số.',
                          en: 'Register Team B with a team name and roster size.',
                        ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: representativeDisabled
                    ? null
                    : () => Navigator.pop(sheetContext, 'TEAM_REPRESENTATIVE'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selectedMode == null) return;
    if (selectedMode == 'INDIVIDUAL') {
      context.read<MatchingBloc>().add(
        JoinMatchingSessionEvent(
          session.id,
          data: const {'joinMode': 'INDIVIDUAL'},
        ),
      );
      return;
    }
    await _showTeamRepresentativeForm(session);
  }

  Future<void> _showTeamRepresentativeForm(
    MatchingSessionEntity session,
  ) async {
    final formKey = GlobalKey<FormState>();
    final teamNameController = TextEditingController();
    final memberCountController = TextEditingController(
      text: session.teamSize.toString(),
    );
    final noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    vi: 'Thông tin đội tham gia',
                    en: 'Participating team details',
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: teamNameController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: context.tr(vi: 'Tên đội', en: 'Team name'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.tr(
                          vi: 'Vui lòng nhập tên đội',
                          en: 'Please enter a team name',
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: memberCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      vi: 'Số lượng thành viên',
                      en: 'Member count',
                    ),
                    helperText: context.tr(
                      vi: 'Tối đa ${session.teamSize} người',
                      en: 'Maximum ${session.teamSize} players',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final count = int.tryParse(value?.trim() ?? '');
                    if (count == null || count < 1) {
                      return context.tr(
                        vi: 'Số lượng phải lớn hơn 0',
                        en: 'Member count must be greater than 0',
                      );
                    }
                    if (count > session.teamSize) {
                      return context.tr(
                        vi: 'Đội chỉ được tối đa ${session.teamSize} người',
                        en: 'The team can have at most ${session.teamSize} players',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      vi: 'Ghi chú (không bắt buộc)',
                      en: 'Note (optional)',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5600),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      Navigator.pop(sheetContext);
                      context.read<MatchingBloc>().add(
                        JoinMatchingSessionEvent(
                          session.id,
                          data: {
                            'joinMode': 'TEAM_REPRESENTATIVE',
                            'teamName': teamNameController.text.trim(),
                            'memberCount': int.parse(
                              memberCountController.text.trim(),
                            ),
                            if (noteController.text.trim().isNotEmpty)
                              'note': noteController.text.trim(),
                          },
                        ),
                      );
                    },
                    child: Text(
                      context.tr(vi: 'XÁC NHẬN THAM GIA', en: 'CONFIRM JOIN'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    teamNameController.dispose();
    memberCountController.dispose();
    noteController.dispose();
  }

  void _showCancelConfirmation(String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(vi: 'Hủy Kèo Đấu', en: 'Cancel Match')),
        content: Text(
          context.tr(
            vi: 'Bạn có chắc chắn muốn hủy kèo đấu này? Tất cả thành viên đã phê duyệt sẽ nhận được thông báo hủy.',
            en: 'Are you sure you want to cancel this match? All approved members will be notified.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr(vi: 'Quay lại', en: 'Back')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              context.read<MatchingBloc>().add(
                CancelMatchingSessionEvent(sessionId),
              );
            },
            child: Text(context.tr(vi: 'Xác nhận Hủy', en: 'Confirm Cancel')),
          ),
        ],
      ),
    );
  }
}
