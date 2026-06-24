import 'package:equatable/equatable.dart';
import 'package:authentication_module/data/models/sign_in_request.dart';
import 'package:authentication_module/data/models/sign_up_request.dart';
import 'package:authentication_module/data/models/sign_out_request.dart';
import 'package:authentication_module/data/models/reset_password_request.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested(this.request);

  final SignInRequest request;

  @override
  List<Object?> get props => [request];
}

class AuthSignUpRequested extends AuthEvent {
  const AuthSignUpRequested(this.request);

  final SignUpRequest request;

  @override
  List<Object?> get props => [request];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested(this.request);

  final SignOutRequest request;

  @override
  List<Object?> get props => [request];
}

class AuthResetPasswordRequested extends AuthEvent {
  const AuthResetPasswordRequested(this.request);

  final ResetPasswordRequest request;

  @override
  List<Object?> get props => [request];
}

class AuthSessionRefreshRequested extends AuthEvent {
  const AuthSessionRefreshRequested(this.refreshToken);

  final String refreshToken;

  @override
  List<Object?> get props => [refreshToken];
}

/// Được emit bởi SessionManager khi refresh token hết hạn hoàn toàn.
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

/// Khôi phục trạng thái đăng nhập từ session hợp lệ đã lưu.
class AuthSessionValidated extends AuthEvent {
  const AuthSessionValidated();
}