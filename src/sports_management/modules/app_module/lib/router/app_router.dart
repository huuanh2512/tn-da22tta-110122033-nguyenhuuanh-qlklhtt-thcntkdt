import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_module/presentation/splash_page.dart';
import 'package:app_module/router/route_paths.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:home_module/home_module.dart';
import 'package:booking_module/booking_module.dart';
import 'package:payment_module/payment_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:matching_module/matching_module.dart';

final class AppModuleRouter {
  const AppModuleRouter._();

  /// Global navigator key — dùng để điều hướng từ SessionManager
  /// mà không cần BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        name: RoutePaths.splashName,
        path: RoutePaths.splash,
        builder: (context, state) => const SplashPage(),
      ),
      ...AuthRoutes.routes,
      ...BookingRoutes.routes,
      ...PaymentRoutes.routes,
      ...FacilityRoutes.routes,
      ...HomeRoutes.routes,
      ...MatchingRoutes.routes,
    ],
  );
}
