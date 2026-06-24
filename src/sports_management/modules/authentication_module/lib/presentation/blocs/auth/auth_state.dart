import 'package:equatable/equatable.dart';
import 'package:authentication_module/data/models/user_result.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final UserResult user;

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthSuccess extends AuthState {
  const AuthSuccess({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class AuthFailureState extends AuthState {
  const AuthFailureState(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}
