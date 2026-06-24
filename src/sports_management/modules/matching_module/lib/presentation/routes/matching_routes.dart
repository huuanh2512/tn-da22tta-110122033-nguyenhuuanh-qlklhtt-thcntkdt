import 'package:go_router/go_router.dart';
import '../pages/matching_explorer_page.dart';
import '../pages/matching_detail_page.dart';
import '../pages/create_matching_session_page.dart';
import '../pages/auto_matching_lobby_page.dart';

class MatchingRoutes {
  MatchingRoutes._();

  static List<GoRoute> get routes => [
        GoRoute(
          path: '/matching',
          builder: (context, state) => const MatchingExplorerPage(),
        ),
        GoRoute(
          path: '/matching/create',
          builder: (context, state) => const CreateMatchingSessionPage(),
        ),
        GoRoute(
          path: '/matching/detail/:sessionId',
          builder: (context, state) {
            final sessionId = state.pathParameters['sessionId']!;
            return MatchingDetailPage(sessionId: sessionId);
          },
        ),
        GoRoute(
          path: '/matching/auto-lobby',
          builder: (context, state) => const AutoMatchingLobbyPage(),
        ),
      ];
}
