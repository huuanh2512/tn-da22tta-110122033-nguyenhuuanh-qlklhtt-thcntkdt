import 'package:equatable/equatable.dart';
import 'package:server_module/server_module.dart';

abstract class CourtManagementState extends Equatable {
  const CourtManagementState();

  @override
  List<Object?> get props => [];
}

class CourtManagementInitial extends CourtManagementState {}

class CourtManagementLoading extends CourtManagementState {}

class CourtManagementLoaded extends CourtManagementState {
  final List<CourtEntity> courts;

  const CourtManagementLoaded(this.courts);

  @override
  List<Object?> get props => [courts];
}

class CourtManagementSuccess extends CourtManagementState {
  final String message;

  const CourtManagementSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class CourtManagementError extends CourtManagementState {
  final String message;

  const CourtManagementError(this.message);

  @override
  List<Object?> get props => [message];
}
