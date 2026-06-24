// ignore_for_file: avoid_print
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:booking_module/booking_module.dart';
import 'staff_booking_state.dart';
import 'package:get_it/get_it.dart';
import 'package:notification_module/notification_module.dart';

class StaffBookingCubit extends Cubit<StaffBookingState> {
  final GetFacilitiesUseCase _getFacilitiesUseCase;
  final GetBookingHistoryUseCase _getBookingHistoryUseCase;
  final UpdateBookingStatusUseCase _updateBookingStatusUseCase;
  final GetLocalUserUseCase _getLocalUserUseCase;

  StaffBookingCubit(
    this._getFacilitiesUseCase,
    this._getBookingHistoryUseCase,
    this._updateBookingStatusUseCase,
    this._getLocalUserUseCase,
  ) : super(StaffBookingInitial());

  Future<void> loadBookings({String? facilityId}) async {
    emit(StaffBookingLoading());
    try {
      final userRes = await _getLocalUserUseCase();
      final user = userRes.fold((_) => null, (u) => u);
      if (user == null || user.userId == null) {
        emit(const StaffBookingError('Không thể xác thực người dùng.'));
        return;
      }

      final facilitiesResponse = await _getFacilitiesUseCase();
      if (!facilitiesResponse.success || facilitiesResponse.data == null) {
        emit(
          StaffBookingError(
            facilitiesResponse.message ?? 'Lỗi tải danh sách cơ sở.',
          ),
        );
        return;
      }

      final allFacilities = facilitiesResponse.data!;
      var filteredFacilities = allFacilities;
      if (user.role == 'STAFF') {
        filteredFacilities = allFacilities
            .where((f) => f.ownerId == user.userId)
            .toList();
        if (filteredFacilities.isEmpty) {
          filteredFacilities = allFacilities;
        }
      }

      final activeFacilityId =
          facilityId ??
          (filteredFacilities.isNotEmpty ? filteredFacilities.first.id : null);

      final bookingsResponse = await _getBookingHistoryUseCase();
      if (!bookingsResponse.success || bookingsResponse.data == null) {
        emit(
          StaffBookingError(
            bookingsResponse.message ?? 'Lỗi tải danh sách đặt sân.',
          ),
        );
        return;
      }

      final allBookings = bookingsResponse.data!;
      print('DEBUG BOOKINGS: activeFacilityId=$activeFacilityId');
      print('DEBUG BOOKINGS: allBookings count=${allBookings.length}');
      for (var b in allBookings) {
        print(
          'DEBUG BOOKINGS: Booking id=${b.id}, courtId=${b.courtId}, court.facilityId=${b.court?.facilityId}',
        );
      }
      var facilityBookings = allBookings;
      if (activeFacilityId != null) {
        facilityBookings = facilityBookings
            .where((b) => b.court?.facilityId == activeFacilityId)
            .toList();
      }
      print(
        'DEBUG BOOKINGS: filtered facilityBookings count=${facilityBookings.length}',
      );

      emit(
        StaffBookingLoaded(
          bookings: facilityBookings,
          facilities: filteredFacilities,
          selectedFacilityId: activeFacilityId,
        ),
      );
    } catch (e) {
      emit(StaffBookingError('Đã xảy ra lỗi: $e'));
    }
  }

  Future<void> updateBookingStatus(
    String bookingId,
    String status,
    String currentFacilityId,
  ) async {
    emit(StaffBookingLoading());
    try {
      final response = await _updateBookingStatusUseCase(bookingId, status);
      if (response.success) {
        try {
          AppNotificationEventType? eventType;
          if (status == 'CONFIRMED' || status == 'COMPLETED') {
            eventType = AppNotificationEventType.bookingConfirmed;
          } else if (status == 'CANCELLED') {
            eventType = AppNotificationEventType.bookingCancelled;
          }
          if (eventType != null) {
            GetIt.I<AppNotificationEventBus>().emit(
              AppNotificationEvent(type: eventType),
            );
          }
        } catch (e) {
          print('Error emitting booking update event: $e');
        }

        emit(
          StaffBookingActionSuccess(
            status == 'CONFIRMED'
                ? 'Check-in thành công!'
                : status == 'COMPLETED'
                ? 'Hoàn thành ca đấu!'
                : 'Đã hủy lịch đặt sân.',
          ),
        );
        await loadBookings(facilityId: currentFacilityId);
      } else {
        emit(
          StaffBookingError(
            response.message ?? 'Cập nhật trạng thái thất bại.',
          ),
        );
        await loadBookings(facilityId: currentFacilityId);
      }
    } catch (e) {
      emit(StaffBookingError('Lỗi cập nhật: $e'));
      await loadBookings(facilityId: currentFacilityId);
    }
  }
}
