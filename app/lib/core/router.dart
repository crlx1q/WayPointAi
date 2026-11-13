import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/auth_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/explore/explore_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/trip/trip_screen.dart';
import '../screens/trips/trips_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier(0);
  ref.listen(authProvider, (_, __) => authListenable.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final authed = ref.read(authProvider).isAuthed;
      final onAuthPages = state.matchedLocation == '/auth' || state.matchedLocation == '/splash';
      if (!authed && !onAuthPages) return '/auth';
      if (authed && onAuthPages) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/trips', builder: (_, __) => const TripsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())]),
        ],
      ),
      GoRoute(
        path: '/chat',
        pageBuilder: (_, state) => _slideUp(state, ChatScreen(initialQuery: state.uri.queryParameters['q'])),
      ),
      GoRoute(
        path: '/trip/:id',
        pageBuilder: (_, state) => _slideUp(state, TripScreen(tripId: state.pathParameters['id']!)),
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    ],
  );
});

CustomTransitionPage _slideUp(GoRouterState state, Widget child) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
