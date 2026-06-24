import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:server_module/server_module.dart';
import '../../domain/usecases/get_fixed_schedules_usecase.dart';
import '../../domain/usecases/cancel_fixed_schedule_usecase.dart';
import '../../domain/usecases/approve_fixed_schedule_usecase.dart';
import '../../domain/usecases/reject_fixed_schedule_usecase.dart';

abstract class FixedScheduleState extends Equatable {
  const FixedScheduleState();

  @override
  List<Object?> get props => [];
}

class FixedScheduleInitial extends FixedScheduleState {}

class FixedScheduleLoading extends FixedScheduleState {}

class FixedScheduleLoaded extends FixedScheduleState {
  final List<FixedScheduleEntity> schedules;

  const FixedScheduleLoaded(this.schedules);

  @override
  List<Object?> get props => [schedules];
}

class FixedScheduleError extends FixedScheduleState {
  final String message;

  const FixedScheduleError(this.message);

  @override
  List<Object?> get props => [message];
}

class FixedScheduleCubit extends Cubit<FixedScheduleState> {
  final GetFixedSchedulesUseCase _getFixedSchedulesUseCase;
  final CancelFixedScheduleUseCase _cancelFixedScheduleUseCase;
  final ApproveFixedScheduleUseCase _approveFixedScheduleUseCase;
  final RejectFixedScheduleUseCase _rejectFixedScheduleUseCase;
  String? _currentStatus;
  String? _currentType;

  FixedScheduleCubit(
    this._getFixedSchedulesUseCase,
    this._cancelFixedScheduleUseCase,
    this._approveFixedScheduleUseCase,
    this._rejectFixedScheduleUseCase,
  ) : super(FixedScheduleInitial());

  Future<void> loadFixedSchedules({String? status, String? type}) async {
    _currentStatus = status;
    _currentType = type;
    emit(FixedScheduleLoading());
    try {
      final response = await _getFixedSchedulesUseCase(
        status: status,
        type: type,
      );
      if (isClosed) return;
      if (response.success && response.data != null) {
        emit(FixedScheduleLoaded(response.data!));
      } else {
        emit(FixedScheduleError(response.message ?? 'Lỗi không xác định'));
      }
    } catch (e) {
      if (isClosed) return;
      emit(FixedScheduleError('Lỗi kết nối: $e'));
    }
  }

  Future<void> cancelFixedSchedule(String id) async {
    try {
      final response = await _cancelFixedScheduleUseCase(id);
      if (isClosed) return;
      if (response.success) {
        loadFixedSchedules(status: _currentStatus, type: _currentType);
      } else {
        emit(
          FixedScheduleError(response.message ?? 'Lỗi khi hủy lịch cố định'),
        );
      }
    } catch (e) {
      if (isClosed) return;
      emit(FixedScheduleError('Lỗi kết nối khi hủy: $e'));
    }
  }

  Future<String?> approveFixedSchedule(String id) async {
    try {
      final response = await _approveFixedScheduleUseCase(id);
      if (isClosed) return null;
      if (response.success) {
        await loadFixedSchedules(status: _currentStatus, type: _currentType);
        return null;
      }
      final message = response.message ?? 'Lỗi khi duyệt lịch cố định';
      emit(FixedScheduleError(message));
      return message;
    } catch (e) {
      if (isClosed) return 'Lỗi kết nối khi duyệt: $e';
      final message = 'Lỗi kết nối khi duyệt: $e';
      emit(FixedScheduleError(message));
      return message;
    }
  }

  Future<String?> rejectFixedSchedule(String id, {String? reason}) async {
    try {
      final response = await _rejectFixedScheduleUseCase(id, reason: reason);
      if (isClosed) return null;
      if (response.success) {
        await loadFixedSchedules(status: _currentStatus, type: _currentType);
        return null;
      }
      final message = response.message ?? 'Lỗi khi từ chối lịch cố định';
      emit(FixedScheduleError(message));
      return message;
    } catch (e) {
      if (isClosed) return 'Lỗi kết nối khi từ chối: $e';
      final message = 'Lỗi kết nối khi từ chối: $e';
      emit(FixedScheduleError(message));
      return message;
    }
  }
}
