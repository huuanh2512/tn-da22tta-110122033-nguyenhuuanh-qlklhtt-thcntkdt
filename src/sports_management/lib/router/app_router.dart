import 'package:go_router/go_router.dart';
import 'package:app_module/router/app_router.dart' as module_router;

final class AppRouter {
  const AppRouter._();

  static final GoRouter router = module_router.AppModuleRouter.router;
}