import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/staff_court_slot_config_page.dart';
import '../pages/staff_court_slot_config_detail_page.dart';
import '../pages/staff_court_report_page.dart';
import '../pages/staff_personal_information_page.dart';
import '../pages/system_settings_page.dart';

final class HomeRoutes {
  const HomeRoutes._();

  static List<GoRoute> get routes => [
    GoRoute(
      name: 'home',
      path: '/home',
      builder: (context, state) =>
          HomePage(initialTab: state.uri.queryParameters['tab']),
    ),
    GoRoute(
      name: 'settings',
      path: '/settings',
      builder: (context, state) => const SystemSettingsPage(),
    ),
    GoRoute(
      path: '/staff/court-slot-config',
      builder: (context, state) => const StaffCourtSlotConfigPage(),
    ),
    GoRoute(
      path: '/staff/court-slot-config/:courtId',
      builder: (context, state) {
        final courtId = state.pathParameters['courtId']!;
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final courtName = extra['courtName'] as String? ?? 'Sân đấu';
        return StaffCourtSlotConfigDetailPage(
          courtId: courtId,
          courtName: courtName,
          sportName: extra['sportName'] as String?,
          courtStatus: extra['courtStatus'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/staff/report',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final facilityId = extra['facilityId'] as String?;
        return StaffCourtReportPage(facilityId: facilityId);
      },
    ),
    GoRoute(
      path: '/staff/personal-information',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return StaffPersonalInformationPage(
          facilityId: extra['facilityId'] as String?,
        );
      },
    ),
  ];
}
