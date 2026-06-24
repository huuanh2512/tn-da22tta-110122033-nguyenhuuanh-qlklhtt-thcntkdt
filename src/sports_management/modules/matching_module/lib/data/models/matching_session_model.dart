import '../../domain/entities/matching_session_entity.dart';
import 'matching_member_model.dart';
import 'matching_team_model.dart';

class MatchingSessionModel extends MatchingSessionEntity {
  const MatchingSessionModel({
    required super.id,
    required super.hostId,
    required super.hostName,
    required super.hostAvatarUrl,
    required super.hostEmail,
    required super.sportId,
    required super.sportName,
    super.sportIconUrl,
    required super.facilityId,
    required super.facilityName,
    required super.facilityCity,
    super.courtId,
    super.bookingId,
    super.fixedScheduleId,
    super.isFixedSchedule,
    required super.bookingDate,
    super.occurrenceDate,
    required super.startMinutes,
    required super.endMinutes,
    super.joinMode,
    super.readiness,
    super.userJoinStatus,
    required super.totalPlayersNeeded,
    required super.approvedCount,
    required super.availableSpots,
    required super.description,
    required super.autoApprove,
    super.paymentPolicy,
    super.teamMode,
    super.hostTeamCode,
    super.hostRepresentedCount,
    super.teamSize,
    super.teamAOccupancy,
    super.teamBOccupancy,
    super.teamAName,
    super.teamBName,
    super.teamBJoinType,
    super.teamBRepresentativeName,
    super.teamBRepresentativeTeamName,
    super.teamBRepresentativeMemberCount,
    super.teams,
    required super.members,
    required super.status,
    super.createdAt,
  });

  factory MatchingSessionModel.fromJson(Map<String, dynamic> json) {
    final hostJson = json['host'] as Map<String, dynamic>? ?? {};
    final sportJson = json['sport'] as Map<String, dynamic>? ?? {};
    final facilityJson = json['facility'] as Map<String, dynamic>? ?? {};
    final membersList = json['members'] as List<dynamic>? ?? [];
    final teamsList = json['teams'] as List<dynamic>? ?? [];
    final teamAJson = json['teamA'] as Map<String, dynamic>? ?? {};
    final teamBJson = json['teamB'] as Map<String, dynamic>? ?? {};

    return MatchingSessionModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      hostId:
          hostJson['id']?.toString() ??
          hostJson['_id']?.toString() ??
          json['hostId']?.toString() ??
          '',
      hostName: hostJson['name']?.toString() ?? 'Chủ phòng',
      hostAvatarUrl: hostJson['avatarUrl']?.toString() ?? '',
      hostEmail: hostJson['email']?.toString() ?? '',
      sportId: sportJson['id']?.toString() ?? json['sportId']?.toString() ?? '',
      sportName: sportJson['name']?.toString() ?? 'Môn thể thao',
      sportIconUrl: sportJson['iconUrl']?.toString() ?? '',
      facilityId:
          facilityJson['id']?.toString() ??
          json['facilityId']?.toString() ??
          '',
      facilityName: facilityJson['name']?.toString() ?? 'Cơ sở',
      facilityCity: facilityJson['city']?.toString() ?? '',
      courtId: json['courtId']?.toString(),
      bookingId: json['bookingId']?.toString(),
      fixedScheduleId:
          json['fixedScheduleId']?.toString() ??
          json['fixed_schedule_id']?.toString(),
      isFixedSchedule:
          json['isFixedSchedule'] as bool? ??
          json['is_fixed_schedule'] as bool? ??
          (json['fixedScheduleId'] != null ||
              json['fixed_schedule_id'] != null),
      bookingDate: json['bookingDate']?.toString() ?? '',
      occurrenceDate:
          json['occurrenceDate']?.toString() ??
          json['occurrence_date']?.toString() ??
          json['bookingDate']?.toString(),
      startMinutes: (json['startMinutes'] as num?)?.toInt() ?? 0,
      endMinutes: (json['endMinutes'] as num?)?.toInt() ?? 0,
      joinMode: json['joinMode']?.toString() ?? 'SESSION_ONLY',
      readiness: json['readiness']?.toString() ?? 'RECRUITING',
      userJoinStatus: json['userJoinStatus']?.toString() ?? 'CAN_JOIN',
      totalPlayersNeeded: (json['totalPlayersNeeded'] as num?)?.toInt() ?? 0,
      approvedCount: (json['approvedCount'] as num?)?.toInt() ?? 0,
      availableSpots: (json['availableSpots'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString() ?? '',
      autoApprove: json['autoApprove'] as bool? ?? true,
      paymentPolicy:
          json['paymentPolicy']?.toString() ??
          json['payment_policy']?.toString() ??
          'HOST_PAY_ALL',
      teamMode:
          json['teamMode']?.toString() ??
          json['team_mode']?.toString() ??
          'INDIVIDUAL',
      hostTeamCode:
          json['hostTeamCode']?.toString() ??
          json['host_team_code']?.toString() ??
          'A',
      hostRepresentedCount:
          (json['hostRepresentedCount'] as num?)?.toInt() ??
          (json['host_represented_count'] as num?)?.toInt() ??
          1,
      teamSize:
          (json['teamSize'] as num?)?.toInt() ??
          (json['team_size'] as num?)?.toInt() ??
          0,
      teamAOccupancy: (json['teamAOccupancy'] as num?)?.toInt() ?? 0,
      teamBOccupancy: (json['teamBOccupancy'] as num?)?.toInt() ?? 0,
      teamAName: teamAJson['name']?.toString() ?? 'Team A',
      teamBName: teamBJson['name']?.toString() ?? 'Team B',
      teamBJoinType: teamBJson['joinType']?.toString() ?? 'EMPTY',
      teamBRepresentativeName: teamBJson['representativeName']?.toString(),
      teamBRepresentativeTeamName: teamBJson['teamName']?.toString(),
      teamBRepresentativeMemberCount: (teamBJson['memberCount'] as num?)
          ?.toInt(),
      teams: teamsList
          .whereType<Map<String, dynamic>>()
          .map(MatchingTeamModel.fromJson)
          .toList(),
      members: membersList
          .map((m) => MatchingMemberModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      status: json['status']?.toString() ?? 'OPEN',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'host': {
        'id': hostId,
        'name': hostName,
        'avatarUrl': hostAvatarUrl,
        'email': hostEmail,
      },
      'sport': {'id': sportId, 'name': sportName, 'iconUrl': sportIconUrl},
      'facility': {
        'id': facilityId,
        'name': facilityName,
        'city': facilityCity,
      },
      'courtId': courtId,
      'bookingId': bookingId,
      'fixedScheduleId': fixedScheduleId,
      'isFixedSchedule': isFixedSchedule,
      'bookingDate': bookingDate,
      'occurrenceDate': occurrenceDate,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'joinMode': joinMode,
      'readiness': readiness,
      'userJoinStatus': userJoinStatus,
      'totalPlayersNeeded': totalPlayersNeeded,
      'approvedCount': approvedCount,
      'availableSpots': availableSpots,
      'description': description,
      'autoApprove': autoApprove,
      'paymentPolicy': paymentPolicy,
      'teamMode': teamMode,
      'hostTeamCode': hostTeamCode,
      'hostRepresentedCount': hostRepresentedCount,
      'teamSize': teamSize,
      'teamAOccupancy': teamAOccupancy,
      'teamBOccupancy': teamBOccupancy,
      'teamA': {
        'name': teamAName,
        'currentCount': teamAOccupancy,
        'maxCount': teamSize,
      },
      'teamB': {
        'name': teamBName,
        'currentCount': teamBOccupancy,
        'maxCount': teamSize,
        'joinType': teamBJoinType,
        'representativeName': teamBRepresentativeName,
        'teamName': teamBRepresentativeTeamName,
        'memberCount': teamBRepresentativeMemberCount,
      },
      'teams': teams
          .map((team) => (team as MatchingTeamModel).toJson())
          .toList(),
      'members': members
          .map((m) => (m as MatchingMemberModel).toJson())
          .toList(),
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
