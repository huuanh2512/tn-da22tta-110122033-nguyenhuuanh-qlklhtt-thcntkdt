import 'package:equatable/equatable.dart';

abstract class MatchingEvent extends Equatable {
  const MatchingEvent();

  @override
  List<Object?> get props => [];
}

class LoadMatchingSessionsEvent extends MatchingEvent {
  final String? sportId;
  final String? facilityId;
  final String? bookingDate;
  final int? neededSpots;

  const LoadMatchingSessionsEvent({
    this.sportId,
    this.facilityId,
    this.bookingDate,
    this.neededSpots,
  });

  @override
  List<Object?> get props => [sportId, facilityId, bookingDate, neededSpots];
}

class LoadMatchingSessionDetailEvent extends MatchingEvent {
  final String sessionId;

  const LoadMatchingSessionDetailEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class CreateMatchingSessionEvent extends MatchingEvent {
  final Map<String, dynamic> data;

  const CreateMatchingSessionEvent(this.data);

  @override
  List<Object?> get props => [data];
}

class JoinMatchingSessionEvent extends MatchingEvent {
  final String sessionId;
  final Map<String, dynamic>? data;

  const JoinMatchingSessionEvent(this.sessionId, {this.data});

  @override
  List<Object?> get props => [sessionId, data];
}

class LeaveMatchingSessionEvent extends MatchingEvent {
  final String sessionId;

  const LeaveMatchingSessionEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class UpdateMemberStatusEvent extends MatchingEvent {
  final String sessionId;
  final String userId;
  final String status;

  const UpdateMemberStatusEvent({
    required this.sessionId,
    required this.userId,
    required this.status,
  });

  @override
  List<Object?> get props => [sessionId, userId, status];
}

class CancelMatchingSessionEvent extends MatchingEvent {
  final String sessionId;

  const CancelMatchingSessionEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class StartListeningToSessionEvent extends MatchingEvent {
  final String sessionId;

  const StartListeningToSessionEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class StopListeningToSessionEvent extends MatchingEvent {
  final String sessionId;

  const StopListeningToSessionEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class SessionUpdatedRealtimeEvent extends MatchingEvent {
  final Map<String, dynamic> payload;

  const SessionUpdatedRealtimeEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}
