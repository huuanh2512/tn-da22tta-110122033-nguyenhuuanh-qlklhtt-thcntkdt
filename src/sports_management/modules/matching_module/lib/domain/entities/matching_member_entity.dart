import 'package:equatable/equatable.dart';

class MatchingMemberEntity extends Equatable {
  final String userId;
  final String name;
  final String avatarUrl;
  final String status; // PENDING, APPROVED, REJECTED
  final String? teamCode;
  final int representedCount;
  final String joinMode;
  final String teamName;
  final String note;
  final DateTime? joinedAt;

  const MatchingMemberEntity({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.status,
    this.teamCode,
    this.representedCount = 1,
    this.joinMode = 'INDIVIDUAL',
    this.teamName = '',
    this.note = '',
    this.joinedAt,
  });

  @override
  List<Object?> get props => [
    userId,
    name,
    avatarUrl,
    status,
    teamCode,
    representedCount,
    joinMode,
    teamName,
    note,
    joinedAt,
  ];
}
