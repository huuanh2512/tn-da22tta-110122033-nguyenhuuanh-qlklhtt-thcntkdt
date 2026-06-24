// ignore_for_file: avoid_print
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:booking_module/booking_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:payment_module/payment_module.dart';
import 'staff_payment_state.dart';
import 'package:get_it/get_it.dart';
import 'package:notification_module/notification_module.dart';

class StaffPaymentCubit extends Cubit<StaffPaymentState> {
  final GetFacilitiesUseCase _getFacilitiesUseCase;
  final GetBookingHistoryUseCase _getBookingHistoryUseCase;
  final GetPaymentsUseCase _getPaymentsUseCase;
  final UpdatePaymentStatusUseCase _updatePaymentStatusUseCase;
  final GetLocalUserUseCase _getLocalUserUseCase;

  StaffPaymentCubit(
    this._getFacilitiesUseCase,
    this._getBookingHistoryUseCase,
    this._getPaymentsUseCase,
    this._updatePaymentStatusUseCase,
    this._getLocalUserUseCase,
  ) : super(StaffPaymentInitial());

  Future<void> loadPayments({String? facilityId}) async {
    emit(StaffPaymentLoading());
    try {
      final userRes = await _getLocalUserUseCase();
      final user = userRes.fold((_) => null, (u) => u);
      if (user == null || user.userId == null) {
        emit(const StaffPaymentError('Không thể xác thực người dùng.'));
        return;
      }

      // 1. Fetch facilities
      final facilitiesResponse = await _getFacilitiesUseCase();
      if (!facilitiesResponse.success || facilitiesResponse.data == null) {
        emit(
          StaffPaymentError(
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

      // 2. Fetch bookings to get the set of booking IDs for this facility
      final bookingsResponse = await _getBookingHistoryUseCase();
      if (!bookingsResponse.success || bookingsResponse.data == null) {
        emit(
          StaffPaymentError(
            bookingsResponse.message ?? 'Lỗi tải danh sách đặt sân.',
          ),
        );
        return;
      }

      final allBookings = bookingsResponse.data!;
      print('DEBUG PAYMENTS: activeFacilityId=$activeFacilityId');
      print('DEBUG PAYMENTS: allBookings count=${allBookings.length}');
      for (var b in allBookings) {
        print(
          'DEBUG PAYMENTS: Booking id=${b.id}, courtId=${b.courtId}, court.facilityId=${b.court?.facilityId}',
        );
      }
      final facilityBookings = allBookings
          .where((b) => b.court?.facilityId == activeFacilityId)
          .toList();
      final facilityBookingIds = facilityBookings.map((b) => b.id).toSet();
      print(
        'DEBUG PAYMENTS: facilityBookings count=${facilityBookings.length}',
      );
      print('DEBUG PAYMENTS: facilityBookingIds=$facilityBookingIds');

      // 3. Fetch payments
      final paymentsResponse = await _getPaymentsUseCase();
      if (!paymentsResponse.success || paymentsResponse.data == null) {
        emit(
          StaffPaymentError(
            paymentsResponse.message ?? 'Lỗi tải danh sách hóa đơn.',
          ),
        );
        return;
      }

      final allPayments = paymentsResponse.data!;
      print('DEBUG PAYMENTS: allPayments count=${allPayments.length}');
      for (var p in allPayments) {
        print(
          'DEBUG PAYMENTS: Payment id=${p.id}, bookingId=${p.bookingId}, status=${p.status}',
        );
      }
      // Filter payments belonging to bookings in our facility
      final facilityPayments = allPayments
          .where((p) => facilityBookingIds.contains(p.bookingId))
          .toList();
      print(
        'DEBUG PAYMENTS: filtered facilityPayments count=${facilityPayments.length}',
      );

      emit(
        StaffPaymentLoaded(
          payments: facilityPayments,
          bookings: facilityBookings,
          facilities: filteredFacilities,
          selectedFacilityId: activeFacilityId,
        ),
      );
    } catch (e) {
      emit(StaffPaymentError('Đã xảy ra lỗi: $e'));
    }
  }

  Future<void> confirmPaymentSuccess(
    String paymentId,
    String currentFacilityId,
  ) async {
    emit(StaffPaymentLoading());
    try {
      final response = await _updatePaymentStatusUseCase(paymentId, 'SUCCESS');
      if (response.success) {
        try {
          GetIt.I<AppNotificationEventBus>().emit(
            const AppNotificationEvent(
              type: AppNotificationEventType.paymentOfflineConfirmed,
            ),
          );
        } catch (e) {
          print('Error emitting paymentOfflineConfirmed event: $e');
        }

        emit(
          const StaffPaymentActionSuccess(
            'Xác nhận thanh toán tại quầy thành công!',
          ),
        );
        await loadPayments(facilityId: currentFacilityId);
      } else {
        emit(
          StaffPaymentError(
            response.message ?? 'Cập nhật thanh toán thất bại.',
          ),
        );
        await loadPayments(facilityId: currentFacilityId);
      }
    } catch (e) {
      emit(StaffPaymentError('Lỗi cập nhật thanh toán: $e'));
      await loadPayments(facilityId: currentFacilityId);
    }
  }
}
