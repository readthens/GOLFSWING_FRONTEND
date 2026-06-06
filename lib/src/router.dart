import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screens.dart';
import 'screens/onboarding_screens.dart';
import 'screens/upload_screens.dart';

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
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/capture/review',
        builder: (context, state) => const UploadScreen(),
      ),
      GoRoute(
        path: '/swings',
        builder: (context, state) => const SwingLibraryScreen(),
      ),
      GoRoute(
        path: '/swings/:sessionId',
        builder: (context, state) =>
            SwingDetailScreen(sessionId: state.pathParameters['sessionId']!),
      ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Route unavailable'))),
  );
  ref.onDispose(router.dispose);
  return router;
});
