import 'package:equatable/equatable.dart';
import 'package:server_module/server_module.dart';

abstract class FacilityManagementState extends Equatable {
  const FacilityManagementState();

  @override
  List<Object?> get props => [];
}

class FacilityManagementInitial extends FacilityManagementState {}

class FacilityManagementLoading extends FacilityManagementState {}

class FacilityManagementLoaded extends FacilityManagementState {
  final List<FacilityEntity> facilities;

  const FacilityManagementLoaded(this.facilities);

  @override
  List<Object?> get props => [facilities];
}

class FacilityManagementSuccess extends FacilityManagementState {
  final String message;

  const FacilityManagementSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class FacilityManagementError extends FacilityManagementState {
  final String message;

  const FacilityManagementError(this.message);

  @override
  List<Object?> get props => [message];
}
