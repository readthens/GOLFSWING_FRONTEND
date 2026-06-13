import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screens.dart';
import 'screens/onboarding_screens.dart';
import 'screens/settings_screens.dart';
import 'screens/upload_screens.dart';
import 'widgets/app_chrome.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authState = auth.state;
      final publicPath =
          location == '/splash' ||
          location == '/welcome' ||
          location == '/auth/sign-in' ||
          location == '/auth/sign-up';

      if (authState.isRestoring) {
        return location == '/splash' ? null : '/splash';
      }
      if (location == '/splash') {
        return authState.isAuthenticated ? '/home' : '/welcome';
      }
      if (!authState.isAuthenticated) {
        return publicPath ? null : '/welcome';
      }
      if (publicPath) {
        return authState.isOnboarded ? '/home' : '/onboarding/profile';
      }
      if (!authState.isOnboarded && !location.startsWith('/onboarding')) {
        return '/onboarding/profile';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/onboarding/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/onboarding/handedness',
        builder: (context, state) => const HandednessScreen(),
      ),
      GoRoute(
        path: '/onboarding/goals',
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: '/onboarding/privacy-consent',
        builder: (context, state) => const PrivacyConsentScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppTabScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rounds',
                builder: (context, state) => const RoundsScreen(),
                routes: [
                  GoRoute(
                    path: 'start',
                    builder: (context, state) => const RoundStartScreen(),
                  ),
                  GoRoute(
                    path: ':roundId',
                    builder: (context, state) => RoundDetailScreen(
                      roundId: state.pathParameters['roundId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/swing',
                builder: (context, state) => const SwingLibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'record',
                    redirect: (context, state) => '/capture/review',
                  ),
                ],
              ),
              GoRoute(path: '/swings', redirect: (context, state) => '/swing'),
              GoRoute(
                path: '/swings/:sessionId/report',
                builder: (context, state) => SwingReportScreen(
                  sessionId: state.pathParameters['sessionId']!,
                ),
              ),
              GoRoute(
                path: '/swings/:sessionId',
                builder: (context, state) => SwingDetailScreen(
                  sessionId: state.pathParameters['sessionId']!,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsOverviewScreen(),
                routes: [
                  GoRoute(
                    path: 'swings',
                    builder: (context, state) =>
                        const StatsDetailScreen(kind: 'swings'),
                  ),
                  GoRoute(
                    path: 'tracer',
                    builder: (context, state) =>
                        const StatsDetailScreen(kind: 'tracer'),
                  ),
                  GoRoute(
                    path: 'rounds',
                    builder: (context, state) =>
                        const StatsDetailScreen(kind: 'rounds'),
                  ),
                  GoRoute(
                    path: 'clubs',
                    builder: (context, state) =>
                        const StatsDetailScreen(kind: 'clubs'),
                  ),
                  GoRoute(
                    path: 'faults',
                    builder: (context, state) =>
                        const StatsDetailScreen(kind: 'faults'),
                  ),
                ],
              ),
              GoRoute(
                path: '/performance-snapshot',
                builder: (context, state) => const PerformanceSnapshotScreen(),
              ),
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tracer',
                builder: (context, state) => const TracerHubScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    redirect: (context, state) => '/capture/tracer?camera=1',
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileHubScreen(),
                routes: [
                  GoRoute(
                    path: 'preferences',
                    builder: (context, state) =>
                        const ProfilePreferencesScreen(),
                  ),
                  GoRoute(
                    path: 'club-bag',
                    builder: (context, state) => const ClubBagScreen(),
                  ),
                  GoRoute(
                    path: 'sync',
                    builder: (context, state) => const SyncCenterScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    redirect: (context, state) => '/settings',
                  ),
                  GoRoute(
                    path: 'subscription',
                    redirect: (context, state) => '/settings/subscription',
                  ),
                  GoRoute(
                    path: 'privacy',
                    redirect: (context, state) => '/settings/privacy',
                  ),
                  GoRoute(
                    path: 'favorites',
                    redirect: (context, state) => '/favorites',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivacyDataScreen(),
      ),
      GoRoute(
        path: '/settings/delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/capture/review',
        builder: (context, state) => const UploadScreen(),
      ),
      GoRoute(
        path: '/capture/tracer',
        builder: (context, state) => UploadScreen(
          mode: UploadMode.tracer,
          cameraFirst: state.uri.queryParameters['camera'] == '1',
        ),
      ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Route unavailable'))),
  );
  ref.onDispose(router.dispose);
  return router;
});
