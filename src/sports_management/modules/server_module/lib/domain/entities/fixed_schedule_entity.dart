import 'package:equatable/equatable.dart';
import 'user_entity.dart';
import 'sport_entity.dart';
import 'facility_entity.dart';
import 'court_entity.dart';

class FixedMatchingTeamEntity extends Equatable {
  final String teamCode;
  final int maxPlayers;
  final String? representativeUserId;
  final String? name;

  const FixedMatchingTeamEntity({
    required this.teamCode,
    required this.maxPlayers,
    this.representativeUserId,
    this.name,
  });

  factory FixedMatchingTeamEntity.fromJson(Map<String, dynamic> json) {
    return FixedMatchingTeamEntity(
      teamCode:
          json['teamCode']?.toString() ?? json['team_code']?.toString() ?? '',
      maxPlayers:
          (json['maxPlayers'] as num?)?.toInt() ??
          (json['max_players'] as num?)?.toInt() ??
          0,
      representativeUserId:
          json['representativeUserId']?.toString() ??
          json['representative_user_id']?.toString(),
      name: json['name']?.toString(),
    );
  }

  @override
  List<Object?> get props => [teamCode, maxPlayers, representativeUserId, name];
}

class FixedMatchingMemberEntity extends Equatable {
  final String userId;
  final String? name;
  final String? email;
  final String? teamCode;
  final int representedCount;
  final String? status;
  final DateTime? joinedAt;

  const FixedMatchingMemberEntity({
    required this.userId,
    this.name,
    this.email,
    this.teamCode,
    this.representedCount = 1,
    this.status,
    this.joinedAt,
  });

  factory FixedMatchingMemberEntity.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json['user_id'] is Map<String, dynamic>
        ? json['user_id'] as Map<String, dynamic>
        : null;
    return FixedMatchingMemberEntity(
      userId:
          json['userId']?.toString() ??
          json['user_id']?.toString() ??
          user?['id']?.toString() ??
          user?['_id']?.toString() ??
          '',
      name: json['name']?.toString() ?? user?['name']?.toString(),
      email: json['email']?.toString() ?? user?['email']?.toString(),
      teamCode: json['teamCode']?.toString() ?? json['team_code']?.toString(),
      representedCount:
          (json['representedCount'] as num?)?.toInt() ??
          (json['represented_count'] as num?)?.toInt() ??
          1,
      status: json['status']?.toString(),
      joinedAt: json['joinedAt'] != null || json['joined_at'] != null
          ? DateTime.tryParse(
              (json['joinedAt'] ?? json['joined_at']).toString(),
            )
          : null,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    name,
    email,
    teamCode,
    representedCount,
    status,
    joinedAt,
  ];
}

class FixedMatchingConfigEntity extends Equatable {
  final String? teamMode;
  final int teamSize;
  final String? paymentPolicy;
  final String hostTeamCode;
  final int hostRepresentedCount;
  final String? readiness;
  final int teamAOccupancy;
  final int teamBOccupancy;
  final List<FixedMatchingTeamEntity> teams;
  final List<FixedMatchingMemberEntity> members;

  const FixedMatchingConfigEntity({
    this.teamMode,
    this.teamSize = 0,
    this.paymentPolicy,
    this.hostTeamCode = 'A',
    this.hostRepresentedCount = 1,
    this.readiness,
    this.teamAOccupancy = 0,
    this.teamBOccupancy = 0,
    this.teams = const [],
    this.members = const [],
  });

  factory FixedMatchingConfigEntity.fromJson(Map<String, dynamic> json) {
    return FixedMatchingConfigEntity(
      teamMode: json['teamMode']?.toString() ?? json['team_mode']?.toString(),
      teamSize:
          (json['teamSize'] as num?)?.toInt() ??
          (json['team_size'] as num?)?.toInt() ??
          0,
      paymentPolicy:
          json['paymentPolicy']?.toString() ??
          json['payment_policy']?.toString(),
      hostTeamCode:
          json['hostTeamCode']?.toString() ??
          json['host_team_code']?.toString() ??
          'A',
      hostRepresentedCount:
          (json['hostRepresentedCount'] as num?)?.toInt() ??
          (json['host_represented_count'] as num?)?.toInt() ??
          1,
      readiness: json['readiness']?.toString(),
      teamAOccupancy:
          (json['teamAOccupancy'] as num?)?.toInt() ??
          (json['team_a_occupancy'] as num?)?.toInt() ??
          0,
      teamBOccupancy:
          (json['teamBOccupancy'] as num?)?.toInt() ??
          (json['team_b_occupancy'] as num?)?.toInt() ??
          0,
      teams: (json['teams'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FixedMatchingTeamEntity.fromJson)
          .toList(),
      members: (json['members'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FixedMatchingMemberEntity.fromJson)
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    teamMode,
    teamSize,
    paymentPolicy,
    hostTeamCode,
    hostRepresentedCount,
    readiness,
    teamAOccupancy,
    teamBOccupancy,
    teams,
    members,
  ];
}

class FixedScheduleEntity extends Equatable {
  final String id;
  final UserEntity? user;
  final String? type;
  final SportEntity? sport;
  final FacilityEntity? facility;
  final CourtEntity? court;
  final int? pricePerHour;
  final int? startMinutes;
  final int? endMinutes;
  final String? frequency;
  final List<int>? daysOfWeek;
  final String? startDate;
  final String? endDate;
  final String? status;
  final Map<String, dynamic>? matchingConfig;
  final FixedMatchingConfigEntity? fixedMatchingConfig;
  final String? readiness;
  final List<Map<String, dynamic>>? exceptionDates;
  final Map<String, dynamic>? cancellationSummary;
  final DateTime? pausedAt;
  final DateTime? createdAt;

  const FixedScheduleEntity({
    required this.id,
    this.user,
    this.type,
    this.sport,
    this.facility,
    this.court,
    this.pricePerHour,
    this.startMinutes,
    this.endMinutes,
    this.frequency,
    this.daysOfWeek,
    this.startDate,
    this.endDate,
    this.status,
    this.matchingConfig,
    this.fixedMatchingConfig,
    this.readiness,
    this.exceptionDates,
    this.cancellationSummary,
    this.pausedAt,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    user,
    type,
    sport,
    facility,
    court,
    pricePerHour,
    startMinutes,
    endMinutes,
    frequency,
    daysOfWeek,
    startDate,
    endDate,
    status,
    matchingConfig,
    fixedMatchingConfig,
    readiness,
    exceptionDates,
    cancellationSummary,
    pausedAt,
    createdAt,
  ];
}
