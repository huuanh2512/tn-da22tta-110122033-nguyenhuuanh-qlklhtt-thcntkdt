import '../../domain/entities/matching_member_entity.dart';

class MatchingMemberModel extends MatchingMemberEntity {
  const MatchingMemberModel({
    required super.userId,
    required super.name,
    required super.avatarUrl,
    required super.status,
    super.teamCode,
    super.representedCount,
    super.joinMode,
    super.teamName,
    super.note,
    super.joinedAt,
  });

  factory MatchingMemberModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    return MatchingMemberModel(
      userId:
          userJson['id']?.toString() ??
          userJson['_id']?.toString() ??
          json['userId']?.toString() ??
          '',
      name: userJson['name']?.toString() ?? 'Người chơi',
      avatarUrl: userJson['avatarUrl']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      teamCode: json['teamCode']?.toString() ?? json['team_code']?.toString(),
      representedCount:
          (json['representedCount'] as num?)?.toInt() ??
          (json['represented_count'] as num?)?.toInt() ??
          1,
      joinMode:
          json['joinMode']?.toString() ??
          json['join_mode']?.toString() ??
          'INDIVIDUAL',
      teamName:
          json['teamName']?.toString() ?? json['team_name']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': {'id': userId, 'name': name, 'avatarUrl': avatarUrl},
      'status': status,
      'teamCode': teamCode,
      'representedCount': representedCount,
      'joinMode': joinMode,
      'teamName': teamName,
      'note': note,
      'joinedAt': joinedAt?.toIso8601String(),
    };
  }
}
