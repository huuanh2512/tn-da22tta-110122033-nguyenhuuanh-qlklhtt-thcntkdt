import 'package:equatable/equatable.dart';

class MatchingTeamEntity extends Equatable {
  final String teamCode;
  final String name;
  final int maxPlayers;
  final String? representativeUserId;

  const MatchingTeamEntity({
    required this.teamCode,
    required this.name,
    required this.maxPlayers,
    this.representativeUserId,
  });

  @override
  List<Object?> get props => [teamCode, name, maxPlayers, representativeUserId];
}
