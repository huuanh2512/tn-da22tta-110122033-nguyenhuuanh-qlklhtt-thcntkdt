import 'package:equatable/equatable.dart';
import 'matching_member_entity.dart';
import 'matching_team_entity.dart';

class MatchingSessionEntity extends Equatable {
  final String id;
  final String hostId;
  final String hostName;
  final String hostAvatarUrl;
  final String hostEmail;
  final String sportId;
  final String sportName;
  final String sportIconUrl;
  final String facilityId;
  final String facilityName;
  final String facilityCity;
  final String? courtId;
  final String? bookingId;
  final String? fixedScheduleId;
  final bool isFixedSchedule;
  final String bookingDate;
  final String occurrenceDate;
  final int startMinutes;
  final int endMinutes;
  final String joinMode;
  final String readiness;
  final String userJoinStatus;
  final int totalPlayersNeeded;
  final int approvedCount;
  final int availableSpots;
  final String description;
  final bool autoApprove;
  final String paymentPolicy;
  final String teamMode;
  final String hostTeamCode;
  final int hostRepresentedCount;
  final int teamSize;
  final int teamAOccupancy;
  final int teamBOccupancy;
  final String teamAName;
  final String teamBName;
  final String teamBJoinType;
  final String? teamBRepresentativeName;
  final String? teamBRepresentativeTeamName;
  final int? teamBRepresentativeMemberCount;
  final List<MatchingTeamEntity> teams;
  final List<MatchingMemberEntity> members;
  final String status; // OPEN, FULL, CANCELLED, COMPLETED
  final DateTime? createdAt;

  const MatchingSessionEntity({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.hostAvatarUrl,
    required this.hostEmail,
    required this.sportId,
    required this.sportName,
    this.sportIconUrl = '',
    required this.facilityId,
    required this.facilityName,
    required this.facilityCity,
    this.courtId,
    this.bookingId,
    this.fixedScheduleId,
    this.isFixedSchedule = false,
    required this.bookingDate,
    String? occurrenceDate,
    required this.startMinutes,
    required this.endMinutes,
    this.joinMode = 'SESSION_ONLY',
    this.readiness = 'RECRUITING',
    this.userJoinStatus = 'CAN_JOIN',
    required this.totalPlayersNeeded,
    required this.approvedCount,
    required this.availableSpots,
    required this.description,
    required this.autoApprove,
    this.paymentPolicy = 'HOST_PAY_ALL',
    this.teamMode = 'INDIVIDUAL',
    this.hostTeamCode = 'A',
    this.hostRepresentedCount = 1,
    this.teamSize = 0,
    this.teamAOccupancy = 0,
    this.teamBOccupancy = 0,
    this.teamAName = 'Team A',
    this.teamBName = 'Team B',
    this.teamBJoinType = 'EMPTY',
    this.teamBRepresentativeName,
    this.teamBRepresentativeTeamName,
    this.teamBRepresentativeMemberCount,
    this.teams = const [],
    required this.members,
    required this.status,
    this.createdAt,
  }) : occurrenceDate = occurrenceDate ?? bookingDate;

  @override
  List<Object?> get props => [
    id,
    hostId,
    hostName,
    hostAvatarUrl,
    hostEmail,
    sportId,
    sportName,
    sportIconUrl,
    facilityId,
    facilityName,
    facilityCity,
    courtId,
    bookingId,
    fixedScheduleId,
    isFixedSchedule,
    bookingDate,
    occurrenceDate,
    startMinutes,
    endMinutes,
    joinMode,
    readiness,
    userJoinStatus,
    totalPlayersNeeded,
    approvedCount,
    availableSpots,
    description,
    autoApprove,
    paymentPolicy,
    teamMode,
    hostTeamCode,
    hostRepresentedCount,
    teamSize,
    teamAOccupancy,
    teamBOccupancy,
    teamAName,
    teamBName,
    teamBJoinType,
    teamBRepresentativeName,
    teamBRepresentativeTeamName,
    teamBRepresentativeMemberCount,
    teams,
    members,
    status,
    createdAt,
  ];
}
