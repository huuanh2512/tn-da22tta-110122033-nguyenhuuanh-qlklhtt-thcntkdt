import 'package:equatable/equatable.dart';
import 'package:server_module/server_module.dart';
import 'package:booking_module/booking_module.dart';

abstract class StaffBookingState extends Equatable {
  const StaffBookingState();

  @override
  List<Object?> get props => [];
}

class StaffBookingInitial extends StaffBookingState {}

class StaffBookingLoading extends StaffBookingState {}

class StaffBookingLoaded extends StaffBookingState {
  final List<BookingDetailEntity> bookings;
  final List<FacilityEntity> facilities;
  final String? selectedFacilityId;

  const StaffBookingLoaded({
    required this.bookings,
    required this.facilities,
    required this.selectedFacilityId,
  });

  @override
  List<Object?> get props => [bookings, facilities, selectedFacilityId];
}

class StaffBookingActionSuccess extends StaffBookingState {
  final String message;

  const StaffBookingActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class StaffBookingError extends StaffBookingState {
  final String message;

  const StaffBookingError(this.message);

  @override
  List<Object?> get props => [message];
}
