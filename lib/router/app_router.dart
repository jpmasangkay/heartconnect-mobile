import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/landing_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/job_board_screen.dart';
import '../screens/job_detail_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/post_job_screen.dart';
import '../screens/edit_job_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/main_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/saved_jobs_screen.dart';
import '../screens/verification_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/two_factor_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/blocked_users_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/reviews_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<bool>(
      authProvider.select((state) => state.isAuthenticated),
      (_, __) => notifyListeners(),
    );
    _ref.listen<bool>(
      authProvider.select((state) => state.isLoading),
      (_, __) => notifyListeners(),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);

      final isAuth = auth.isAuthenticated;
      final path = state.uri.path;
      final publicPaths = ['/', '/login', '/register', '/forgot-password', '/reset-password', '/terms', '/privacy'];

      if (auth.isLoading) return null;

      if (!isAuth && !publicPaths.contains(path)) return '/login';
      if (isAuth && (path == '/' || path == '/login' || path == '/register')) {
        // Redirect to onboarding if not completed
        if (auth.needsOnboarding) return '/onboarding';
        return '/dashboard';
      }
      // Role-based guardrails
      final role = auth.user?.role;
      if (role == 'client' && path == '/saved-jobs') return '/profile';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      // StatefulShellRoute preserves each tab's state across navigation,
      // preventing socket disconnect/reconnect loops in ChatScreen.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/jobs', builder: (_, __) => const JobBoardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),

      // Other routes (without bottom nav bar)
      GoRoute(
        path: '/jobs/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          final rev = state.extra;
          return JobDetailScreen(
            key: ValueKey<String>('job-detail-$id-$rev'),
            jobId: id,
          );
        },
      ),
      GoRoute(
        path: '/jobs/:id/edit',
        builder: (_, state) => EditJobScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/post-job', builder: (_, __) => const PostJobScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) =>
            ChatScreen(conversationId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/users/:id',
        builder: (_, state) =>
            UserProfileScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/saved-jobs', builder: (_, __) => const SavedJobsScreen()),
      GoRoute(path: '/reviews', builder: (_, __) => const ReviewsScreen()),
      GoRoute(path: '/verification', builder: (_, __) => const VerificationScreen()),
      GoRoute(path: '/two-factor', builder: (_, __) => const TwoFactorScreen()),
      GoRoute(path: '/blocked-users', builder: (_, __) => const BlockedUsersScreen()),
    ],
  );
});
