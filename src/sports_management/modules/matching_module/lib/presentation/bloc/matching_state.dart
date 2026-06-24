import 'package:equatable/equatable.dart';
import '../../domain/entities/matching_session_entity.dart';

abstract class MatchingState extends Equatable {
  const MatchingState();

  @override
  List<Object?> get props => [];
}

class MatchingInitialState extends MatchingState {}

class MatchingLoadingState extends MatchingState {}

class MatchingSessionsLoadedState extends MatchingState {
  final List<MatchingSessionEntity> sessions;

  const MatchingSessionsLoadedState(this.sessions);

  @override
  List<Object?> get props => [sessions];
}

class MatchingSessionDetailLoadedState extends MatchingState {
  final MatchingSessionEntity session;

  const MatchingSessionDetailLoadedState(this.session);

  @override
  List<Object?> get props => [session];
}

class MatchingActionSuccessState extends MatchingState {
  final String message;
  final MatchingSessionEntity? session;

  const MatchingActionSuccessState(this.message, {this.session});

  @override
  List<Object?> get props => [message, session];
}

class MatchingErrorState extends MatchingState {
  final String errorMessage;

  const MatchingErrorState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
