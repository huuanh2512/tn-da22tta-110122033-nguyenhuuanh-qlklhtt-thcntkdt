import 'package:authentication_module/application/session/session_manager.dart';
import 'package:authentication_module/domain/usecases/get_local_user_usecase.dart';
import 'package:authentication_module/domain/usecases/refresh_session_usecase.dart';
import 'package:authentication_module/domain/usecases/reset_password_usecase.dart';
import 'package:authentication_module/domain/usecases/sign_in_usecase.dart';
import 'package:authentication_module/domain/usecases/sign_out_usecase.dart';
import 'package:authentication_module/domain/usecases/sign_up_usecase.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._signInUseCase,
    this._signUpUseCase,
    this._signOutUseCase,
    this._refreshSessionUseCase,
    this._resetPasswordUseCase,
  ) : super(const AuthInitial()) {
    on<AuthStarted>((event, emit) => emit(const AuthUnauthenticated()));
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthSessionRefreshRequested>(_onRefreshSession);
    on<AuthResetPasswordRequested>(_onResetPassword);
    on<AuthSessionExpired>((event, emit) {
      stopSessionManager();
      emit(const AuthUnauthenticated());
    });
    on<AuthSessionValidated>(_onSessionValidated);
  }

  final SignInUseCase _signInUseCase;
  final SignUpUseCase _signUpUseCase;
  final SignOutUseCase _signOutUseCase;
  final RefreshSessionUseCase _refreshSessionUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;

  void startSessionManager() {
    SessionManager.instance.onSessionExpired = () {
      if (!isClosed) add(const AuthSessionExpired());
    };
    SessionManager.instance.startChecking();
  }

  void stopSessionManager() => SessionManager.instance.stopChecking();

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _signInUseCase(event.request);
    result.fold((failure) => emit(AuthFailureState(failure.message)), (user) {
      if (user.isSuccess) {
        startSessionManager();
        emit(AuthAuthenticated(user));
      } else {
        emit(
          AuthFailureState(
            user.error ?? 'Đăng nhập thất bại.',
            code: user.code,
          ),
        );
      }
    });
  }

  Future<void> _onSignUp(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _signUpUseCase(event.request);
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => user.isSuccess
          ? emit(AuthSuccess(message: user.error))
          : emit(
              AuthFailureState(
                user.error ?? 'Đăng ký thất bại.',
                code: user.code,
              ),
            ),
    );
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await GetIt.I<UserService>().removeFCMToken(token);
    } catch (error) {
      debugPrint('[AuthBloc] FCM removal failed: $error');
    }
    stopSessionManager();
    final result = await _signOutUseCase(event.request);
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (_) => emit(const AuthUnauthenticated()),
    );
  }

  Future<void> _onRefreshSession(
    AuthSessionRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _refreshSessionUseCase(event.refreshToken);
    result.fold(
      (failure) => emit(const AuthUnauthenticated()),
      (user) => user.isSuccess
          ? emit(AuthAuthenticated(user))
          : emit(const AuthUnauthenticated()),
    );
  }

  Future<void> _onResetPassword(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _resetPasswordUseCase(event.request);
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => user.isSuccess
          ? emit(const AuthSuccess(message: 'Đặt lại mật khẩu thành công.'))
          : emit(AuthFailureState(user.error ?? 'Thất bại.')),
    );
  }

  Future<void> _onSessionValidated(
    AuthSessionValidated event,
    Emitter<AuthState> emit,
  ) async {
    final result = await GetIt.I<GetLocalUserUseCase>()();
    result.fold((failure) => emit(const AuthUnauthenticated()), (user) {
      startSessionManager();
      emit(AuthAuthenticated(user));
    });
  }

  @override
  Future<void> close() {
    stopSessionManager();
    return super.close();
  }
}
