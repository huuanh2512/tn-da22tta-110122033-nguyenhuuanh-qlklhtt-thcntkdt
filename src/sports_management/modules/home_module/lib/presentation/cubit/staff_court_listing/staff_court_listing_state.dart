import 'package:equatable/equatable.dart';
import 'package:server_module/server_module.dart';

abstract class StaffCourtListingState extends Equatable {
  const StaffCourtListingState();

  @override
  List<Object?> get props => [];
}

class StaffCourtListingInitial extends StaffCourtListingState {}

class StaffCourtListingLoading extends StaffCourtListingState {}

class StaffCourtListingLoaded extends StaffCourtListingState {
  final List<FacilityEntity> facilities;
  final List<CourtEntity> courts;

  const StaffCourtListingLoaded({
    required this.facilities,
    required this.courts,
  });

  @override
  List<Object?> get props => [facilities, courts];
}

class StaffCourtListingError extends StaffCourtListingState {
  final String message;

  const StaffCourtListingError(this.message);

  @override
  List<Object?> get props => [message];
}
