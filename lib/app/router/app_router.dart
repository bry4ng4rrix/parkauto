import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_controller.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/splash_screen.dart';
import '../../features/fuel/presentation/fuel_create_screen.dart';
import '../../features/fuel/presentation/fuel_list_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/incidents/presentation/incident_create_screen.dart';
import '../../features/incidents/presentation/incident_detail_screen.dart';
import '../../features/incidents/presentation/incident_list_screen.dart';
import '../../features/incidents/presentation/incident_photos_screen.dart';
import '../../features/messaging/presentation/chat_screen.dart';
import '../../features/messaging/presentation/contact_list_screen.dart';
import '../../features/messaging/presentation/conversation_list_screen.dart';
import '../../features/missions/presentation/mission_detail_screen.dart';
import '../../features/missions/presentation/mission_list_screen.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/vehicle/presentation/vehicle_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'not_found_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Observe le navigateur racine (conversation « active » du chat).
final appRouteObserver = RouteObserver<ModalRoute<void>>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    observers: [appRouteObserver],
    redirect: (context, state) => authRedirect(
      ref.read(sessionControllerProvider).status,
      state.matchedLocation,
    ),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.missions,
                builder: (_, _) => const MissionListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                builder: (_, _) => const ConversationListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/mission/:id',
        builder: (_, state) => _withId(
          state,
          (id) => MissionDetailScreen(idMission: id),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => _withId(
          state,
          (id) => ChatScreen(idConversation: id),
        ),
      ),
      GoRoute(
        path: AppRoutes.contacts,
        builder: (_, _) => const ContactListScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: AppRoutes.vehicle,
        builder: (_, _) => const VehicleScreen(),
      ),
      GoRoute(
        path: AppRoutes.fuel,
        builder: (_, _) => const FuelListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const FuelCreateScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.incidents,
        builder: (_, _) => const IncidentListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => const IncidentCreateScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => _withId(
              state,
              (id) => IncidentDetailScreen(idIncident: id),
            ),
            routes: [
              GoRoute(
                path: 'photos',
                builder: (_, state) => _withId(
                  state,
                  (id) => IncidentPhotosScreen(idIncident: id),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Redirection selon l'état de session.
String? authRedirect(AuthStatus status, String location) {
  final atSplash = location == AppRoutes.splash;
  final atLogin = location == AppRoutes.login;
  return switch (status) {
    AuthStatus.unknown => atSplash ? null : AppRoutes.splash,
    AuthStatus.unauthenticated => atLogin ? null : AppRoutes.login,
    AuthStatus.authenticated => atSplash || atLogin ? AppRoutes.home : null,
  };
}

Widget _withId(GoRouterState state, Widget Function(int id) builder) {
  final id = int.tryParse(state.pathParameters['id'] ?? '');
  return id == null ? const NotFoundScreen() : builder(id);
}

/// Relaie les changements d'état de session au routeur, sans que le
/// routeur lui-même ne soit reconstruit.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(
      sessionControllerProvider.select((s) => s.status),
      (_, _) => notifyListeners(),
    );
  }
}
