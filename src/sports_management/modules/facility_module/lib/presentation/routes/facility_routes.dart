import 'package:go_router/go_router.dart';
import '../pages/facility_management_page.dart';
import '../pages/court_management_page.dart';
import '../pages/sport_management_page.dart';

class FacilityRoutes {
  FacilityRoutes._();

  static List<GoRoute> get routes => [
        GoRoute(
          path: '/facility',
          builder: (context, state) => const FacilityManagementPage(),
        ),
        GoRoute(
          path: '/sport',
          builder: (context, state) => const SportManagementPage(),
        ),
        GoRoute(
          path: '/facility/:facilityId/courts',
          builder: (context, state) {
            final facilityId = state.pathParameters['facilityId']!;
            final facilityName = state.extra as String?;
            return CourtManagementPage(
              facilityId: facilityId,
              facilityName: facilityName,
            );
          },
        ),
      ];
}
