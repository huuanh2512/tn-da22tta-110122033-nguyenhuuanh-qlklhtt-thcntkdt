import 'package:equatable/equatable.dart';
import 'package:server_module/server_module.dart';
import 'package:booking_module/booking_module.dart';
import 'package:payment_module/payment_module.dart';

abstract class StaffPaymentState extends Equatable {
  const StaffPaymentState();

  @override
  List<Object?> get props => [];
}

class StaffPaymentInitial extends StaffPaymentState {}

class StaffPaymentLoading extends StaffPaymentState {}

class StaffPaymentLoaded extends StaffPaymentState {
  final List<PaymentDetailEntity> payments;
  final List<BookingDetailEntity> bookings;
  final List<FacilityEntity> facilities;
  final String? selectedFacilityId;

  const StaffPaymentLoaded({
    required this.payments,
    required this.bookings,
    required this.facilities,
    this.selectedFacilityId,
  });

  @override
  List<Object?> get props => [payments, bookings, facilities, selectedFacilityId];
}

class StaffPaymentActionSuccess extends StaffPaymentState {
  final String message;

  const StaffPaymentActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class StaffPaymentError extends StaffPaymentState {
  final String message;

  const StaffPaymentError(this.message);

  @override
  List<Object?> get props => [message];
}
