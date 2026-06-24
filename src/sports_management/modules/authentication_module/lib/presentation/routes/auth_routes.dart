import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:authentication_module/presentation/blocs/auth/auth_bloc.dart';
import 'package:authentication_module/presentation/blocs/auth/auth_event.dart';
import 'package:authentication_module/presentation/pages/sign_in_page.dart';
import 'package:authentication_module/presentation/pages/sign_up_page.dart';
import 'package:authentication_module/presentation/pages/reset_password_page.dart';
import 'package:authentication_module/presentation/pages/verify_email_page.dart';

final class AuthRoutes {
  const AuthRoutes._();

  static List<GoRoute> get routes => [
    GoRoute(
      name: 'sign-in',
      path: '/sign-in',
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.I<AuthBloc>()..add(const AuthStarted()),
        child: const SignInPage(),
      ),
    ),
    GoRoute(
      name: 'sign-up',
      path: '/sign-up',
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.I<AuthBloc>()..add(const AuthStarted()),
        child: const SignUpPage(),
      ),
    ),
    GoRoute(
      name: 'verify-email',
      path: '/verify-email',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        final email = extra?['email'] ?? '';
        final password = extra?['password'] ?? '';
        final deliveryFailed = extra?['deliveryFailed'] == 'true';
        return BlocProvider(
          create: (_) => GetIt.I<AuthBloc>()..add(const AuthStarted()),
          child: VerifyEmailPage(
            email: email,
            password: password,
            deliveryFailed: deliveryFailed,
          ),
        );
      },
    ),
    GoRoute(
      name: 'reset-password',
      path: '/reset-password',
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.I<AuthBloc>()..add(const AuthStarted()),
        child: const ResetPasswordPage(),
      ),
    ),
  ];
}
