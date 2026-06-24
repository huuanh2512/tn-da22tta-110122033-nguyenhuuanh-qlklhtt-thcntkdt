// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/remote/matching_remote_data_source.dart';
import '../../data/models/matching_session_model.dart';
import '../../domain/usecases/get_matching_sessions_usecase.dart';
import '../../domain/usecases/get_matching_session_detail_usecase.dart';
import '../../domain/usecases/create_matching_session_usecase.dart';
import '../../domain/usecases/join_matching_session_usecase.dart';
import '../../domain/usecases/leave_matching_session_usecase.dart';
import '../../domain/usecases/update_member_status_usecase.dart';
import '../../domain/usecases/update_session_status_usecase.dart';
import 'matching_event.dart';
import 'matching_state.dart';

class MatchingBloc extends Bloc<MatchingEvent, MatchingState> {
  final GetMatchingSessionsUseCase _getSessionsUseCase;
  final GetMatchingSessionDetailUseCase _getSessionDetailUseCase;
  final CreateMatchingSessionUseCase _createSessionUseCase;
  final JoinMatchingSessionUseCase _joinSessionUseCase;
  final LeaveMatchingSessionUseCase _leaveSessionUseCase;
  final UpdateMemberStatusUseCase _updateMemberStatusUseCase;
  final UpdateSessionStatusUseCase _updateSessionStatusUseCase;
  final MatchingRemoteDataSource _remoteDataSource;

  StreamSubscription? _socketSubscription;

  MatchingBloc({
    required GetMatchingSessionsUseCase getSessionsUseCase,
    required GetMatchingSessionDetailUseCase getSessionDetailUseCase,
    required CreateMatchingSessionUseCase createSessionUseCase,
    required JoinMatchingSessionUseCase joinSessionUseCase,
    required LeaveMatchingSessionUseCase leaveSessionUseCase,
    required UpdateMemberStatusUseCase updateMemberStatusUseCase,
    required UpdateSessionStatusUseCase updateSessionStatusUseCase,
    required MatchingRemoteDataSource remoteDataSource,
  }) : _getSessionsUseCase = getSessionsUseCase,
       _getSessionDetailUseCase = getSessionDetailUseCase,
       _createSessionUseCase = createSessionUseCase,
       _joinSessionUseCase = joinSessionUseCase,
       _leaveSessionUseCase = leaveSessionUseCase,
       _updateMemberStatusUseCase = updateMemberStatusUseCase,
       _updateSessionStatusUseCase = updateSessionStatusUseCase,
       _remoteDataSource = remoteDataSource,
       super(MatchingInitialState()) {
    on<LoadMatchingSessionsEvent>(_onLoadSessions);
    on<LoadMatchingSessionDetailEvent>(_onLoadSessionDetail);
    on<CreateMatchingSessionEvent>(_onCreateSession);
    on<JoinMatchingSessionEvent>(_onJoinSession);
    on<LeaveMatchingSessionEvent>(_onLeaveSession);
    on<UpdateMemberStatusEvent>(_onUpdateMemberStatus);
    on<CancelMatchingSessionEvent>(_onCancelSession);
    on<StartListeningToSessionEvent>(_onStartListening);
    on<StopListeningToSessionEvent>(_onStopListening);
    on<SessionUpdatedRealtimeEvent>(_onSessionUpdatedRealtime);
  }

  Future<void> _onLoadSessions(
    LoadMatchingSessionsEvent event,
    Emitter<MatchingState> emit,
  ) async {
    emit(MatchingLoadingState());
    final response = await _getSessionsUseCase(
      sportId: event.sportId,
      facilityId: event.facilityId,
      bookingDate: event.bookingDate,
      neededSpots: event.neededSpots,
    );

    if (response.success && response.data != null) {
      emit(MatchingSessionsLoadedState(response.data!));
    } else {
      emit(
        MatchingErrorState(response.message ?? 'Lỗi tải danh sách phòng ghép'),
      );
    }
  }

  Future<void> _onLoadSessionDetail(
    LoadMatchingSessionDetailEvent event,
    Emitter<MatchingState> emit,
  ) async {
    emit(MatchingLoadingState());
    final response = await _getSessionDetailUseCase(event.sessionId);

    if (response.success && response.data != null) {
      emit(MatchingSessionDetailLoadedState(response.data!));
    } else {
      emit(
        MatchingErrorState(response.message ?? 'Lỗi tải chi tiết phòng ghép'),
      );
    }
  }

  Future<void> _onCreateSession(
    CreateMatchingSessionEvent event,
    Emitter<MatchingState> emit,
  ) async {
    emit(MatchingLoadingState());
    final response = await _createSessionUseCase(event.data);

    if (response.success && response.data != null) {
      emit(
        MatchingActionSuccessState(
          'Tạo phòng ghép trận thành công!',
          session: response.data,
        ),
      );
    } else {
      emit(MatchingErrorState(response.message ?? 'Lỗi tạo phòng ghép'));
    }
  }

  Future<void> _onJoinSession(
    JoinMatchingSessionEvent event,
    Emitter<MatchingState> emit,
  ) async {
    emit(MatchingLoadingState());
    final response = await _joinSessionUseCase(
      event.sessionId,
      data: event.data,
    );

    if (response.success && response.data != null) {
      emit(
        MatchingActionSuccessState(
          response.message ?? 'Gửi yêu cầu tham gia thành công!',
          session: response.data,
        ),
      );
    } else {
      emit(MatchingErrorState(response.message ?? 'Lỗi tham gia phòng ghép'));
    }
  }

  Future<void> _onLeaveSession(
    LeaveMatchingSessionEvent event,
    Emitter<MatchingState> emit,
  ) async {
    emit(MatchingLoadingState());
    final response = await _leaveSessionUseCase(event.sessionId);

    if (response.success && response.data != null) {
      emit(
        MatchingActionSuccessState(
          'Rời phòng ghép thành công!',
          session: response.data,
        ),
      );
    } else {
      emit(MatchingErrorState(response.message ?? 'Lỗi rời phòng ghép'));
    }
  }

  Future<void> _onUpdateMemberStatus(
    UpdateMemberStatusEvent event,
    Emitter<MatchingState> emit,
  ) async {
    emit(MatchingLoadingState());
    final response = await _updateMemberStatusUseCase(
      id: event.sessionId,
      userId: event.userId,
      status: event.status,
    );

    if (response.success && response.data != null) {
      emit(
        MatchingActionSuccessState(
          event.status == 'APPROVED'
              ? 'Đã duyệt thành viên!'
              : 'Đã từ chối thành viên!',
          session: response.data,
        ),
      );
    } else {
      emit(
        MatchingErrorState(
          response.message ?? 'Lỗi cập nhật trạng thái thành viên',
        ),
      );
    }
  }

  Future<void> _onCancelSession(
    CancelMatchingSessionEvent event,
    Emitter<MatchingState> emit,
  ) async {
    emit(MatchingLoadingState());
    final response = await _updateSessionStatusUseCase(
      event.sessionId,
      'CANCELLED',
    );

    if (response.success && response.data != null) {
      emit(
        MatchingActionSuccessState(
          'Hủy phòng ghép trận thành công!',
          session: response.data,
        ),
      );
    } else {
      emit(MatchingErrorState(response.message ?? 'Lỗi hủy phòng ghép'));
    }
  }

  void _onStartListening(
    StartListeningToSessionEvent event,
    Emitter<MatchingState> emit,
  ) {
    _socketSubscription?.cancel();
    _remoteDataSource.joinMatchingRoom(event.sessionId);

    _socketSubscription = _remoteDataSource.matchingSessionUpdates.listen((
      payload,
    ) {
      add(SessionUpdatedRealtimeEvent(payload));
    });
  }

  void _onStopListening(
    StopListeningToSessionEvent event,
    Emitter<MatchingState> emit,
  ) {
    _socketSubscription?.cancel();
    _remoteDataSource.leaveMatchingRoom(event.sessionId);
  }

  void _onSessionUpdatedRealtime(
    SessionUpdatedRealtimeEvent event,
    Emitter<MatchingState> emit,
  ) {
    try {
      final sessionData =
          event.payload['session'] as Map<String, dynamic>? ?? event.payload;
      final session = MatchingSessionModel.fromJson(sessionData);
      emit(MatchingSessionDetailLoadedState(session));
    } catch (e) {
      debugPrint('[MatchingBloc] Error processing realtime session update: $e');
    }
  }

  @override
  Future<void> close() {
    _socketSubscription?.cancel();
    return super.close();
  }
}
