import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/booking_detail_entity.dart';
import '../../domain/usecases/get_booking_history_usecase.dart';

abstract class BookingHistoryState extends Equatable {
  const BookingHistoryState();

  @override
  List<Object?> get props => [];
}

class BookingHistoryInitial extends BookingHistoryState {}

class BookingHistoryLoading extends BookingHistoryState {}

class BookingHistoryLoaded extends BookingHistoryState {
  final List<BookingDetailEntity> bookings;

  const BookingHistoryLoaded(this.bookings);

  @override
  List<Object?> get props => [bookings];
}

class BookingHistoryError extends BookingHistoryState {
  final String message;

  const BookingHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

class BookingHistoryCubit extends Cubit<BookingHistoryState> {
  final GetBookingHistoryUseCase _getBookingHistoryUseCase;

  BookingHistoryCubit(this._getBookingHistoryUseCase) : super(BookingHistoryInitial());

  Future<void> loadBookingHistory({String? status}) async {
    emit(BookingHistoryLoading());
    try {
      final response = await _getBookingHistoryUseCase(status: status);
      if (isClosed) return;
      if (response.success && response.data != null) {
        emit(BookingHistoryLoaded(response.data!));
      } else {
        emit(BookingHistoryError(response.message ?? 'Lỗi không xác định'));
      }
    } catch (e) {
      if (isClosed) return;
      emit(BookingHistoryError('Lỗi kết nối: $e'));
    }
  }
}
