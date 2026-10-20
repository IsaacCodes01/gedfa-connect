import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/app_shell.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/startup_screen.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/presentation/login_screen.dart';
import 'package:gedfa_connect/features/home/presentation/placeholder_home.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_request_review_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_requests_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/verify_email_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/forgot_password_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/sign_up_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/welcome_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/register_team_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/team_home_screen.dart';
import 'package:gedfa_connect/features/players/presentation/player_details_screen.dart';
import 'package:gedfa_connect/features/players/presentation/player_form_screen.dart';
import 'package:gedfa_connect/features/settings/presentation/change_email_screen.dart';
import 'package:gedfa_connect/features/settings/presentation/more_screen.dart';
import 'package:gedfa_connect/features/settings/presentation/my_profile_screen.dart';
import 'package:gedfa_connect/features/settings/presentation/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(appUserProvider, (_, _) => refresh.value++);

  // The top-level navigator. Screens given this key open above the tabs.
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
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
      // FA admin area: a shell with tabs (Teams, More).
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => AppShell(
          navigationShell: navigationShell,
          destinations: adminDestinations,
        ),
        branches: [
          // Tab 0: Teams (team registration requests)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.admin,
                builder: (_, _) => const FaRequestsScreen(),
                routes: [
                  // Opens full-screen, above the tabs.
                  GoRoute(
                    path: 'request/:uid',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => FaRequestReviewScreen(
                      uid: state.pathParameters['uid']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 1: More
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminMore,
                builder: (_, _) => const MoreScreen(),
                routes: _moreChildren(),
              ),
            ],
          ),
        ],
      ),
      // Team admin area: a shell with tabs (Squad, More).
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => AppShell(
          navigationShell: navigationShell,
          destinations: teamDestinations,
        ),
        branches: [
          // Tab 0: Squad
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.team,
                builder: (_, _) => const TeamHomeScreen(),
                routes: [
                  // Player screens open full-screen, above the tabs.
                  GoRoute(
                    path: 'add',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const PlayerFormScreen(),
                  ),
                  GoRoute(
                    path: 'player/:playerId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => PlayerDetailsScreen(
                      playerId: state.pathParameters['playerId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => PlayerFormScreen(
                          playerId: state.pathParameters['playerId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Tab 1: More (Settings)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.teamMore,
                builder: (_, _) => const MoreScreen(),
                routes: _moreChildren(),
              ),
            ],
          ),
        ],
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

/// My profile, Change email and Settings: the same screens for every role.
/// They open inside the More tab, so the bottom bar stays.
List<RouteBase> _moreChildren() => [
      GoRoute(
        path: 'profile',
        builder: (_, _) => const MyProfileScreen(),
        routes: [
          GoRoute(
            path: 'email',
            builder: (_, _) => const ChangeEmailScreen(),
          ),
        ],
      ),
      GoRoute(
        path: 'settings',
        builder: (_, _) => const SettingsScreen(),
      ),
    ];

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