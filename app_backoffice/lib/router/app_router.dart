import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/main_layout.dart';
import '../screens/dashboard_screen.dart';
import '../screens/trails/trails_screen.dart';
import '../screens/trails/trail_form_screen.dart';
import '../screens/pois/pois_screen.dart';
import '../screens/pois/poi_form_screen.dart';
import '../screens/users/users_screen.dart';
import '../screens/quizzes/quizzes_screen.dart';
import '../screens/quizzes/quiz_form_screen.dart';
import '../screens/local_services/local_services_screen.dart';
import '../screens/local_services/local_service_form_screen.dart';
import '../screens/sos/sos_alerts_screen.dart';
import '../screens/settings/admin_settings_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isLoggedIn = authProvider.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/trails',
            builder: (context, state) => const TrailsScreen(),
          ),
          GoRoute(
            path: '/trails/create',
            builder: (context, state) => const TrailFormScreen(),
          ),
          GoRoute(
            path: '/trails/edit/:id',
            builder: (context, state) => TrailFormScreen(
              trailId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/pois',
            builder: (context, state) => const PoisScreen(),
          ),
          GoRoute(
            path: '/pois/create',
            builder: (context, state) => const PoiFormScreen(),
          ),
          GoRoute(
            path: '/pois/edit/:id',
            builder: (context, state) => PoiFormScreen(
              poiId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/quizzes',
            builder: (context, state) => const QuizzesScreen(),
          ),
          GoRoute(
            path: '/quizzes/create',
            builder: (context, state) => const QuizFormScreen(),
          ),
          GoRoute(
            path: '/quizzes/edit/:id',
            builder: (context, state) => QuizFormScreen(
              quizId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/local-services',
            builder: (context, state) => const LocalServicesScreen(),
          ),
          GoRoute(
            path: '/local-services/create',
            builder: (context, state) => const LocalServiceFormScreen(),
          ),
          GoRoute(
            path: '/local-services/edit/:id',
            builder: (context, state) => LocalServiceFormScreen(
              serviceId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/sos-alerts',
            builder: (context, state) => const SosAlertsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const AdminSettingsScreen(),
          ),
        ],
      ),
    ],
  );
}
