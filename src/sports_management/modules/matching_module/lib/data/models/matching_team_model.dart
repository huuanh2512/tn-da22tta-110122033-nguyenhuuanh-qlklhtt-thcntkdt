import '../../domain/entities/matching_team_entity.dart';

class MatchingTeamModel extends MatchingTeamEntity {
  const MatchingTeamModel({
    required super.teamCode,
    required super.name,
    required super.maxPlayers,
    super.representativeUserId,
  });

  factory MatchingTeamModel.fromJson(Map<String, dynamic> json) {
    return MatchingTeamModel(
      teamCode:
          json['teamCode']?.toString() ?? json['team_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      maxPlayers:
          (json['maxPlayers'] as num?)?.toInt() ??
          (json['max_players'] as num?)?.toInt() ??
          0,
      representativeUserId:
          json['representativeUserId']?.toString() ??
          json['representative_user_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teamCode': teamCode,
      'name': name,
      'maxPlayers': maxPlayers,
      'representativeUserId': representativeUserId,
    };
  }
}
