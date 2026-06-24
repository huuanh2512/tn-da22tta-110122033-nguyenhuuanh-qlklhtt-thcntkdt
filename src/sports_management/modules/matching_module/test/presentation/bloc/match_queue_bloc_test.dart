import 'package:flutter_test/flutter_test.dart';
import 'package:matching_module/domain/entities/match_queue_entity.dart';
import 'package:matching_module/domain/repositories/matching_repository.dart';
import 'package:matching_module/domain/usecases/get_queue_status_usecase.dart';
import 'package:matching_module/domain/usecases/join_queue_usecase.dart';
import 'package:matching_module/domain/usecases/leave_queue_usecase.dart';
import 'package:matching_module/presentation/bloc/match_queue_bloc.dart';
import 'package:matching_module/presentation/bloc/match_queue_event.dart';
import 'package:matching_module/presentation/bloc/match_queue_state.dart';
import 'package:server_module/server_module.dart';

class _FakeMatchingRepository implements MatchingRepository {
  _FakeMatchingRepository(this.queueResponse);

  BaseResponse<MatchQueueEntity> queueResponse;

  @override
  Future<BaseResponse<MatchQueueEntity>> getQueueStatus() async => queueResponse;

  @override
  Future<BaseResponse<MatchQueueEntity>> joinQueue(
    Map<String, dynamic> data,
  ) async => queueResponse;

  @override
  Future<BaseResponse<void>> leaveQueue() async =>
      const BaseResponse(success: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _searchingQueue = MatchQueueEntity(
  id: 'queue-1',
  userId: 'user-1',
  sportId: 'sport-1',
  sportName: 'Football',
  facilityId: 'facility-1',
  facilityName: 'Main facility',
  bookingDate: '2026-07-01',
  timeRange: '17h - 18h',
  groupSize: 4,
  status: 'SEARCHING',
);

void main() {
  late _FakeMatchingRepository repository;
  late MatchQueueBloc bloc;

  setUp(() {
    repository = _FakeMatchingRepository(
      const BaseResponse(success: true, data: _searchingQueue),
    );
    bloc = MatchQueueBloc(
      getQueueStatusUseCase: GetQueueStatusUseCase(repository),
      joinQueueUseCase: JoinQueueUseCase(repository),
      leaveQueueUseCase: LeaveQueueUseCase(repository),
    );
  });

  tearDown(() => bloc.close());

  test('silent polling refreshes SEARCHING queue without loading state', () async {
    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([isA<MatchQueueSearchingState>()]),
    );

    bloc.add(const LoadQueueStatusEvent(silent: true));
    await expectation;
  });

  test('polling response with no active queue returns idle state', () async {
    repository.queueResponse = const BaseResponse(success: true);
    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([isA<MatchQueueIdleState>()]),
    );

    bloc.add(const LoadQueueStatusEvent(silent: true));
    await expectation;
  });
}
