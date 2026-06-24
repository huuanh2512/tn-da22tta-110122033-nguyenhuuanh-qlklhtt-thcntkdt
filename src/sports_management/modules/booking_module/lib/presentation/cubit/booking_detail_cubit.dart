import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/booking_detail_entity.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/get_booking_detail_usecase.dart';

abstract class BookingDetailState extends Equatable {
  const BookingDetailState();

  @override
  List<Object?> get props => [];
}

class BookingDetailInitial extends BookingDetailState {}

class BookingDetailLoading extends BookingDetailState {}

class BookingDetailLoaded extends BookingDetailState {
  final BookingDetailEntity booking;
  final bool isCancelling;

  const BookingDetailLoaded(this.booking, {this.isCancelling = false});

  @override
  List<Object?> get props => [booking, isCancelling];
}

class BookingDetailError extends BookingDetailState {
  final String message;

  const BookingDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class BookingDetailCubit extends Cubit<BookingDetailState> {
  final GetBookingDetailUseCase _getBookingDetailUseCase;
  final CancelBookingUseCase _cancelBookingUseCase;

  BookingDetailCubit(this._getBookingDetailUseCase, this._cancelBookingUseCase)
      : super(BookingDetailInitial());

  Future<void> loadBookingDetail(String id) async {
    emit(BookingDetailLoading());
    try {
      final response = await _getBookingDetailUseCase(id);
      if (response.success && response.data != null) {
        emit(BookingDetailLoaded(response.data!));
      } else {
        emit(BookingDetailError(response.message ?? 'Lỗi không xác định'));
      }
    } catch (e) {
      emit(BookingDetailError('Lỗi kết nối: $e'));
    }
  }

  Future<String?> cancelBooking(String id) async {
    final currentState = state;
    try {
      if (currentState is BookingDetailLoaded) {
        emit(BookingDetailLoaded(currentState.booking, isCancelling: true));
      }

      final response = await _cancelBookingUseCase(id);
      if (response.success) {
        await loadBookingDetail(id);
        return null;
      }

      if (currentState is BookingDetailLoaded) {
        emit(BookingDetailLoaded(currentState.booking));
      }
      return response.message ?? 'Không thể hủy đặt sân. Vui lòng thử lại.';
    } catch (e) {
      if (currentState is BookingDetailLoaded) {
        emit(BookingDetailLoaded(currentState.booking));
      }
      return 'Lỗi kết nối: $e';
    }
  }
}
