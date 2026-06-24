import 'package:equatable/equatable.dart';
import 'package:server_module/server_module.dart';

abstract class SportManagementState extends Equatable {
  const SportManagementState();

  @override
  List<Object?> get props => [];
}

class SportManagementInitial extends SportManagementState {}

class SportManagementLoading extends SportManagementState {}

class SportManagementLoaded extends SportManagementState {
  final List<SportEntity> sports;

  const SportManagementLoaded(this.sports);

  @override
  List<Object?> get props => [sports];
}

class SportManagementSuccess extends SportManagementState {
  final String message;

  const SportManagementSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class SportManagementError extends SportManagementState {
  final String message;

  const SportManagementError(this.message);

  @override
  List<Object?> get props => [message];
}
