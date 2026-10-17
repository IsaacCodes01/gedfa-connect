import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/startup_screen.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/presentation/login_screen.dart';
import 'package:gedfa_connect/features/home/presentation/placeholder_home.dart';
import 'package:gedfa_connect/features/auth/presentation/verify_email_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/forgot_password_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/sign_up_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/welcome_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/register_team_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(appUserProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: Routes.startup,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(
        path: Routes.startup,
        builder: (_, _) => const StartupScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'signup',
            builder: (_, _) => const SignUpScreen(),
          ),
          GoRoute(
            path: 'forgot',
            builder: (_, state) => ForgotPasswordScreen(
              initialEmail: state.extra as String? ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (_, _) => const VerifyEmailScreen(),
      ),
            GoRoute(
        path: Routes.welcome,
        builder: (_, _) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: 'register',
            builder: (_, _) => const RegisterTeamScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.admin,
        builder: (_, _) => const PlaceholderHome(
          title: 'FA Admin',
          message: 'FA Admin home. (Coming soon)',
        ),
      ),
      GoRoute(
        path: Routes.team,
        builder: (_, _) => const PlaceholderHome(
          title: 'My Team',
          message: 'Team Admin home. (Coming soon)',
        ),
      ),
      GoRoute(
        path: Routes.referee,
        builder: (_, _) => const PlaceholderHome(
          title: 'Referee',
          message: 'Referee home. (Coming soon)',
        ),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });

  return router;
});

String? _redirect(Ref ref, String location) {
  String? goTo(String target) => location == target ? null : target;

  final auth = ref.read(authStateProvider);
  final appUser = ref.read(appUserProvider);

  // 1. Still finding out who is signed in
  if (!auth.hasValue) return goTo(Routes.startup);

  // 2. Nobody signed in
  final authUser = auth.value;
  if (authUser == null) {
    return location.startsWith(Routes.login) ? null : Routes.login;
  }

  // 3. Email account not confirmed yet
  if (!authUser.emailVerified) return goTo(Routes.verifyEmail);

  // 4. Role still loading (or belongs to a previous user)
  final profile = appUser.value;
  if (appUser.isLoading || profile == null || profile.uid != authUser.uid) {
    return goTo(Routes.startup);
  }

  // 5. Pick the home for this role
  final home = switch (profile.role) {
    UserRole.faAdmin => Routes.admin,
    UserRole.teamAdmin => Routes.team,
    UserRole.referee => Routes.referee,
    null => Routes.welcome,
  };

  // 6. Stay inside your home area, or go there
  return location.startsWith(home) ? null : home;
}