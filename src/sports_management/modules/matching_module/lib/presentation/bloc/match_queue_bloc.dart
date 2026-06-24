// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/join_queue_usecase.dart';
import '../../domain/usecases/leave_queue_usecase.dart';
import '../../domain/usecases/get_queue_status_usecase.dart';
import 'match_queue_event.dart';
import 'match_queue_state.dart';

class MatchQueueBloc extends Bloc<MatchQueueEvent, MatchQueueState> {
  final JoinQueueUseCase _joinQueueUseCase;
  final LeaveQueueUseCase _leaveQueueUseCase;
  final GetQueueStatusUseCase _getQueueStatusUseCase;

  MatchQueueBloc({
    required JoinQueueUseCase joinQueueUseCase,
    required LeaveQueueUseCase leaveQueueUseCase,
    required GetQueueStatusUseCase getQueueStatusUseCase,
  }) : _joinQueueUseCase = joinQueueUseCase,
       _leaveQueueUseCase = leaveQueueUseCase,
       _getQueueStatusUseCase = getQueueStatusUseCase,
       super(MatchQueueInitialState()) {
    on<LoadQueueStatusEvent>(_onLoadQueueStatus);
    on<JoinQueueEvent>(_onJoinQueue);
    on<LeaveQueueEvent>(_onLeaveQueue);
  }

  Future<void> _onLoadQueueStatus(
    LoadQueueStatusEvent event,
    Emitter<MatchQueueState> emit,
  ) async {
    if (!event.silent) emit(MatchQueueLoadingState());
    final response = await _getQueueStatusUseCase();

    if (response.success) {
      if (response.data != null) {
        emit(MatchQueueSearchingState(response.data!));
      } else {
        emit(MatchQueueIdleState());
      }
    } else {
      emit(
        MatchQueueErrorState(response.message ?? 'Lỗi tải trạng thái hàng chờ'),
      );
    }
  }

  Future<void> _onJoinQueue(
    JoinQueueEvent event,
    Emitter<MatchQueueState> emit,
  ) async {
    emit(MatchQueueLoadingState());
    final response = await _joinQueueUseCase(event.data);

    if (response.success && response.data != null) {
      emit(MatchQueueSearchingState(response.data!));
    } else {
      emit(
        MatchQueueErrorState(response.message ?? 'Lỗi đăng ký vào hàng chờ'),
      );
    }
  }

  Future<void> _onLeaveQueue(
    LeaveQueueEvent event,
    Emitter<MatchQueueState> emit,
  ) async {
    emit(MatchQueueLoadingState());
    final response = await _leaveQueueUseCase();

    if (response.success) {
      emit(MatchQueueIdleState());
    } else {
      emit(MatchQueueErrorState(response.message ?? 'Lỗi rời hàng chờ'));
    }
  }
}
