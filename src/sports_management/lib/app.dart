import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:sports_management/core/theme/app_theme.dart';
import 'package:sports_management/router/app_router.dart';
import 'package:home_module/home_module.dart';
import 'package:notification_module/notification_module.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:app_module/router/app_router.dart' show AppModuleRouter;
import 'package:matching_module/matching_module.dart';
import 'package:sports_management/core/services/fcm_service.dart';
import 'package:sports_management/core/services/socket_service.dart';

class App extends StatefulWidget {
  final ThemeMode initialThemeMode;
  final String initialLanguageCode;

  const App({
    super.key,
    this.initialThemeMode = ThemeMode.system,
    this.initialLanguageCode = 'vi',
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  StreamSubscription? _eventBusSubscription;
  bool _isSessionExpiredDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _eventBusSubscription = GetIt.I<AppNotificationEventBus>().stream.listen((
      event,
    ) {
      if (event.type == AppNotificationEventType.fcmTokenRegisterRequested) {
        FcmService.registerDeviceToken();
      } else if (event.type ==
          AppNotificationEventType.fcmTokenRemoveRequested) {
        FcmService.removeDeviceToken();
      }
    });
  }

  @override
  void dispose() {
    _eventBusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(
          create: (_) => ThemeCubit(initialMode: widget.initialThemeMode),
        ),
        BlocProvider<LanguageCubit>(
          create: (_) =>
              LanguageCubit(initialLanguage: widget.initialLanguageCode),
        ),
        BlocProvider<NotificationCubit>(
          create: (_) => GetIt.I<NotificationCubit>()..loadNotifications(),
        ),
        BlocProvider<AuthBloc>(create: (_) => GetIt.I<AuthBloc>()),
        BlocProvider<MatchingBloc>(create: (_) => GetIt.I<MatchingBloc>()),
        BlocProvider<MatchQueueBloc>(create: (_) => GetIt.I<MatchQueueBloc>()),
        RepositoryProvider<GetLocalUserUseCase>(
          create: (_) => GetIt.I<GetLocalUserUseCase>(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocListener<AuthBloc, AuthState>(
            listenWhen: (prev, curr) =>
                (curr is AuthAuthenticated) ||
                (curr is AuthUnauthenticated && prev is! AuthInitial),
            listener: (context, state) {
              if (state is AuthAuthenticated) {
                FcmService.registerDeviceToken();
                NotificationSocketService.connect();
              } else if (state is AuthUnauthenticated) {
                NotificationSocketService.disconnect();
                // Khi phiên hết hạn, hiển thị thông báo và điều hướng về đăng nhập
                final navigatorContext =
                    AppModuleRouter.navigatorKey.currentContext;
                if (navigatorContext != null) {
                  _showSessionExpiredDialog(navigatorContext);
                }
              }
            },
            child: MaterialApp.router(
              title: 'Sport Energy',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              routerConfig: AppRouter.router,
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSessionExpiredDialog(BuildContext context) async {
    if (_isSessionExpiredDialogVisible || !context.mounted) {
      return;
    }

    // Kiểm tra xem có đang ở màn hình sign-in không, nếu có thì bỏ qua
    final currentPath = AppRouter.router.state.uri.toString();
    if (currentPath.contains('sign-in') || currentPath.contains('splash')) {
      return;
    }

    _isSessionExpiredDialogVisible = true;
    try {
      // Let the dialog route unmount completely before replacing the app route.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.lock_clock, size: 48, color: Colors.orange),
          title: const Text(
            'Phiên đăng nhập hết hạn',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Phiên đăng nhập của bạn đã hết hạn.\nVui lòng đăng nhập lại để tiếp tục sử dụng.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('Đăng nhập lại'),
              ),
            ),
          ],
        ),
      );

      if (mounted) {
        AppRouter.router.goNamed('sign-in');
      }
    } finally {
      _isSessionExpiredDialogVisible = false;
    }
  }
}
