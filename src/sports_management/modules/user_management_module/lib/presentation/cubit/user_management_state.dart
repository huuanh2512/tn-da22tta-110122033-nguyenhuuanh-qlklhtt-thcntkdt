import 'package:equatable/equatable.dart';
import 'package:server_module/server_module.dart';

abstract class UserManagementState extends Equatable {
  const UserManagementState();

  @override
  List<Object?> get props => [];
}

class UserManagementInitial extends UserManagementState {}

class UserManagementLoading extends UserManagementState {}

class UserManagementLoaded extends UserManagementState {
  final List<UserEntity> users;

  const UserManagementLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class UserManagementSuccess extends UserManagementState {
  final String message;

  const UserManagementSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class UserManagementError extends UserManagementState {
  final String message;

  const UserManagementError(this.message);

  @override
  List<Object?> get props => [message];
}
