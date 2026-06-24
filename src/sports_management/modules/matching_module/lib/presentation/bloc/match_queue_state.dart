import 'package:equatable/equatable.dart';
import '../../domain/entities/match_queue_entity.dart';

abstract class MatchQueueState extends Equatable {
  const MatchQueueState();

  @override
  List<Object?> get props => [];
}

class MatchQueueInitialState extends MatchQueueState {}

class MatchQueueLoadingState extends MatchQueueState {}

class MatchQueueIdleState extends MatchQueueState {}

class MatchQueueSearchingState extends MatchQueueState {
  final MatchQueueEntity queue;

  const MatchQueueSearchingState(this.queue);

  @override
  List<Object?> get props => [queue];
}

class MatchQueueSuccessState extends MatchQueueState {
  final String message;

  const MatchQueueSuccessState(this.message);

  @override
  List<Object?> get props => [message];
}

class MatchQueueErrorState extends MatchQueueState {
  final String errorMessage;

  const MatchQueueErrorState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
