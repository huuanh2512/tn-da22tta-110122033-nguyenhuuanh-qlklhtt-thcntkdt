import '../../domain/entities/match_queue_entity.dart';

class MatchQueueModel extends MatchQueueEntity {
  const MatchQueueModel({
    required super.id,
    required super.userId,
    required super.sportId,
    required super.sportName,
    super.sportIconUrl,
    required super.facilityId,
    required super.facilityName,
    required super.bookingDate,
    required super.timeRange,
    required super.groupSize,
    super.teamMode,
    super.preferredTeam,
    super.memberCount,
    super.teamSize,
    super.paymentPolicy,
    required super.status,
    super.matchingSessionId,
  });

  factory MatchQueueModel.fromJson(Map<String, dynamic> json) {
    return MatchQueueModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      sportId:
          json['sportId']?.toString() ?? json['sport_id']?.toString() ?? '',
      sportName:
          json['sportName']?.toString() ??
          json['sport']?.toString() ??
          'Môn thể thao',
      sportIconUrl: json['sportIconUrl']?.toString() ?? '',
      facilityId:
          json['facilityId']?.toString() ??
          json['facility_id']?.toString() ??
          '',
      facilityName:
          json['facilityName']?.toString() ??
          json['facility']?.toString() ??
          'Cơ sở',
      bookingDate:
          json['bookingDate']?.toString() ??
          json['booking_date']?.toString() ??
          '',
      timeRange:
          json['timeRange']?.toString() ?? json['time']?.toString() ?? '',
      groupSize:
          (json['groupSize'] as num?)?.toInt() ??
          (json['group_size'] as num?)?.toInt() ??
          1,
      teamMode:
          json['teamMode']?.toString() ??
          json['team_mode']?.toString() ??
          'INDIVIDUAL',
      preferredTeam:
          json['preferredTeam']?.toString() ??
          json['preferred_team']?.toString() ??
          'AUTO',
      memberCount:
          (json['memberCount'] as num?)?.toInt() ??
          (json['member_count'] as num?)?.toInt() ??
          1,
      teamSize:
          (json['teamSize'] as num?)?.toInt() ??
          (json['team_size'] as num?)?.toInt(),
      paymentPolicy:
          json['paymentPolicy']?.toString() ??
          json['payment_policy']?.toString() ??
          'SPLIT_EQUALLY',
      status: json['status']?.toString() ?? 'SEARCHING',
      matchingSessionId:
          json['matchingSessionId']?.toString() ??
          json['matching_session_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'sportId': sportId,
      'sportName': sportName,
      'sportIconUrl': sportIconUrl,
      'facilityId': facilityId,
      'facilityName': facilityName,
      'bookingDate': bookingDate,
      'timeRange': timeRange,
      'groupSize': groupSize,
      'teamMode': teamMode,
      'preferredTeam': preferredTeam,
      'memberCount': memberCount,
      'teamSize': teamSize,
      'paymentPolicy': paymentPolicy,
      'status': status,
      'matchingSessionId': matchingSessionId,
    };
  }
}
