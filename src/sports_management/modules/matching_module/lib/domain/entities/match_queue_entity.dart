import 'package:equatable/equatable.dart';

class MatchQueueEntity extends Equatable {
  final String id;
  final String userId;
  final String sportId;
  final String sportName;
  final String sportIconUrl;
  final String facilityId;
  final String facilityName;
  final String bookingDate;
  final String timeRange;
  final int groupSize;
  final String teamMode;
  final String preferredTeam;
  final int memberCount;
  final int? teamSize;
  final String paymentPolicy;
  final String status; // SEARCHING, MATCHED, CANCELLED, EXPIRED
  final String? matchingSessionId;

  const MatchQueueEntity({
    required this.id,
    required this.userId,
    required this.sportId,
    required this.sportName,
    this.sportIconUrl = '',
    required this.facilityId,
    required this.facilityName,
    required this.bookingDate,
    required this.timeRange,
    required this.groupSize,
    this.teamMode = 'INDIVIDUAL',
    this.preferredTeam = 'AUTO',
    this.memberCount = 1,
    this.teamSize,
    this.paymentPolicy = 'SPLIT_EQUALLY',
    required this.status,
    this.matchingSessionId,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    sportId,
    sportName,
    sportIconUrl,
    facilityId,
    facilityName,
    bookingDate,
    timeRange,
    groupSize,
    teamMode,
    preferredTeam,
    memberCount,
    teamSize,
    paymentPolicy,
    status,
    matchingSessionId,
  ];
}
