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
import 'package:gedfa_connect/features/dashboard/presentation/fa_dashboard_screen.dart';
import 'package:gedfa_connect/features/home/presentation/placeholder_home.dart';
import 'package:gedfa_connect/features/notifications/presentation/announcement_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/compose_announcement_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/fa_announcement_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/fa_announcements_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/notifications_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_ask_correction_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_correct_details_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_team_changes_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_player_review_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_player_teams_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_request_review_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_requests_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_juvenile_child_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/fa_fixtures_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/fixture_form_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/fixture_kits_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/season_draft_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/season_setup_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/team_fixtures_screen.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_team_juvenile_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_team_players_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/verify_email_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/forgot_password_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/sign_up_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/welcome_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/register_team_screen.dart';
import 'package:gedfa_connect/features/teams/data/team_profile_repository.dart';
import 'package:gedfa_connect/features/teams/domain/correction_request.dart';
import 'package:gedfa_connect/features/teams/domain/team_change.dart';
import 'package:gedfa_connect/features/teams/presentation/ask_change_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/team_edit_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/team_home_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/team_profile_screen.dart';
import 'package:gedfa_connect/features/league/presentation/league_settings_screen.dart';
import 'package:gedfa_connect/features/payments/presentation/add_payment_screen.dart';
import 'package:gedfa_connect/features/payments/presentation/fa_fees_screen.dart';
import 'package:gedfa_connect/features/payments/presentation/fa_team_fee_screen.dart';
import 'package:gedfa_connect/features/payments/presentation/season_fee_screen.dart';
import 'package:gedfa_connect/features/people/presentation/invite_person_screen.dart';
import 'package:gedfa_connect/features/people/presentation/invite_ready_screen.dart';
import 'package:gedfa_connect/features/people/presentation/member_screen.dart';
import 'package:gedfa_connect/features/people/presentation/people_screen.dart';
import 'package:gedfa_connect/features/players/presentation/player_details_screen.dart';
import 'package:gedfa_connect/features/players/presentation/player_form_screen.dart';
import 'package:gedfa_connect/features/players/presentation/player_profile_edit_screen.dart';
import 'package:gedfa_connect/features/players/presentation/player_profile_screen.dart';
import 'package:gedfa_connect/features/players/presentation/team_positions_screen.dart';
import 'package:gedfa_connect/features/screening/presentation/fa_screening_days_screen.dart';
import 'package:gedfa_connect/features/screening/presentation/fa_screening_decision_screen.dart';
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
      // FA admin area: a shell with tabs (Home, Teams, Players, Fixtures,
      // More).
      StatefulShellRoute.indexedStack(
        builder: (_, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          destinations: adminDestinations,
          openedFromHome: Routes.isFromHome(state.uri),
        ),
        branches: [
          // Tab 0: Home (the dashboard, 2.12)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminHome,
                builder: (_, _) => const FaDashboardScreen(),
              ),
            ],
          ),
          // Tab 1: Teams (team registration requests)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.admin,
                // ?view=changes opens the Changes side (2.10b)
                builder: (_, state) => FaRequestsScreen(
                  changes: state.uri.queryParameters['view'] == 'changes',
                  fromHome: Routes.isFromHome(state.uri),
                ),
                routes: [
                  // One team's change requests to decide. Full-screen (2.10c).
                  GoRoute(
                    path: 'changes/:teamId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => FaTeamChangesScreen(
                      teamId: state.pathParameters['teamId']!,
                    ),
                  ),
                  // The FA corrects club details (2.11a). Full-screen.
                  GoRoute(
                    path: 'correct/:teamId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => FaCorrectDetailsScreen(
                      teamId: state.pathParameters['teamId']!,
                    ),
                  ),
                  // The FA asks a team to correct (2.11b). Full-screen.
                  GoRoute(
                    path: 'ask/:teamId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => FaAskCorrectionScreen(
                      teamId: state.pathParameters['teamId']!,
                      item: CorrectionItem.values
                          .where((i) =>
                              i.name == state.uri.queryParameters['item'])
                          .firstOrNull,
                    ),
                  ),
                  // Notifications (bell). Full-screen, above the tabs.
                  GoRoute(
                    path: 'notifications',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const NotificationsScreen(),
                  ),
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
          // Tab 2: Players (by team, then by position)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminPlayers,
                // ?view=juvenile opens the Juvenile side (2.14b)
                builder: (_, state) => FaPlayerTeamsScreen(
                  juvenile: state.uri.queryParameters['view'] == 'juvenile',
                  fromHome: Routes.isFromHome(state.uri),
                ),
                routes: [
                  // One team's players. Inside the tab (bottom bar stays).
                  GoRoute(
                    path: 'team/:teamId',
                    builder: (_, state) => FaTeamPlayersScreen(
                      teamId: state.pathParameters['teamId']!,
                    ),
                    routes: [
                      // Its juvenile players by age group (2.14b)
                      GoRoute(
                        path: 'juvenile',
                        builder: (_, state) => FaTeamJuvenileScreen(
                          teamId: state.pathParameters['teamId']!,
                        ),
                      ),
                    ],
                  ),
                  // One juvenile child, read only. Full-screen (2.14c).
                  GoRoute(
                    path: 'child/:playerId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => FaJuvenileChildScreen(
                      playerId: state.pathParameters['playerId']!,
                    ),
                  ),
                  // Review one player. Full-screen, above the tabs.
                  GoRoute(
                    path: 'player/:playerId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => FaPlayerReviewScreen(
                      playerId: state.pathParameters['playerId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: Fixtures (3.0a)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminFixtures,
                builder: (_, _) => const FaFixturesScreen(),
                routes: [
                  // Make the season (3.0b): G1, then the draft (G2)
                  GoRoute(
                    path: 'season',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => SeasonSetupScreen(
                      category: Competition.fromString(
                            state.uri.queryParameters['category'],
                          ) ??
                          Competition.division,
                    ),
                    routes: [
                      GoRoute(
                        path: 'draft',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, _) => const SeasonDraftScreen(),
                      ),
                    ],
                  ),
                  // Add one match (?category=juvenile&group=U15). Full screen.
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => FixtureFormScreen(
                      category: Competition.fromString(
                            state.uri.queryParameters['category'],
                          ) ??
                          Competition.division,
                      group: AgeGroup.fromString(
                        state.uri.queryParameters['group'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => FixtureFormScreen(
                      fixtureId: state.pathParameters['id'],
                    ),
                  ),
                  GoRoute(
                    path: 'kits/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => FixtureKitsScreen(
                      fixtureId: state.pathParameters['id']!,
                      canEdit: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 4: More
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminMore,
                builder: (_, _) => const MoreScreen(),
                routes: [
                  ..._moreChildren(),
                  // FA only: Announcements (2.7). Inside the More tab.
                  GoRoute(
                    path: 'announcements',
                    builder: (_, _) => const FaAnnouncementsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, _) => const ComposeAnnouncementScreen(),
                      ),
                      GoRoute(
                        path: 'view/:id',
                        builder: (_, state) => FaAnnouncementScreen(
                          id: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  // FA only: Juvenile screening days (2.14b). More tab.
                  GoRoute(
                    path: 'screening',
                    builder: (_, state) => FaScreeningDaysScreen(
                      fromHome: Routes.isFromHome(state.uri),
                    ),
                    routes: [
                      // One child after another (2.14c). Full screen.
                      GoRoute(
                        path: 'day/:dayId',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => FaScreeningDecisionScreen(
                          dayId: state.pathParameters['dayId']!,
                          childId: state.uri.queryParameters['child'],
                        ),
                      ),
                    ],
                  ),
                  // FA only: League settings (2.13d). Inside the More tab.
                  GoRoute(
                    path: 'league',
                    builder: (_, _) => const LeagueSettingsScreen(),
                  ),
                  // FA only: Season fees (2.13c). Inside the More tab.
                  GoRoute(
                    path: 'fees',
                    builder: (_, state) => FaFeesScreen(
                      fromHome: Routes.isFromHome(state.uri),
                    ),
                    routes: [
                      GoRoute(
                        path: 'team/:teamId',
                        builder: (_, state) => FaTeamFeeScreen(
                          teamId: state.pathParameters['teamId']!,
                        ),
                      ),
                    ],
                  ),
                  // FA only: People and roles (2.6). Inside the More tab.
                  GoRoute(
                    path: 'people',
                    builder: (_, _) => const PeopleScreen(),
                    routes: [
                      GoRoute(
                        path: 'invite',
                        builder: (_, _) => const InvitePersonScreen(),
                      ),
                      GoRoute(
                        path: 'invited/:email',
                        builder: (_, state) => InviteReadyScreen(
                          email: state.pathParameters['email']!,
                        ),
                      ),
                      GoRoute(
                        path: 'member/:uid',
                        builder: (_, state) => MemberScreen(
                          uid: state.pathParameters['uid']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Team admin area: a shell with tabs (Squad, Positions, More).
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
                  // Notifications (bell) and one announcement.
                  GoRoute(
                    path: 'notifications',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const NotificationsScreen(),
                    routes: [
                      GoRoute(
                        path: 'announcement/:id',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => AnnouncementScreen(
                          id: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  // Player screens open full-screen, above the tabs.
                  GoRoute(
                    path: 'add',
                    parentNavigatorKey: rootNavigatorKey,
                    // ?group=U13 adds a juvenile player (2.14)
                    builder: (_, state) => PlayerFormScreen(
                      juvenileGroup: state.uri.queryParameters['group'],
                    ),
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
          // Tab 1: Fixtures (3.0a)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.teamFixtures,
                builder: (_, _) => const TeamFixturesScreen(),
                routes: [
                  GoRoute(
                    path: 'kits/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => FixtureKitsScreen(
                      fixtureId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 2: Positions (who can play where)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.teamPositions,
                builder: (_, _) => const TeamPositionsScreen(),
                routes: [
                  // Profile screens open full-screen, above the tabs.
                  GoRoute(
                    path: 'profile/:playerId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => PlayerProfileScreen(
                      playerId: state.pathParameters['playerId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => PlayerProfileEditScreen(
                          playerId: state.pathParameters['playerId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: More (Settings)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.teamMore,
                builder: (_, _) => const MoreScreen(),
                routes: [
                  ..._moreChildren(),
                  // Team only: Team profile (2.10a). Editing a section
                  // opens full-screen.
                  GoRoute(
                    path: 'club',
                    builder: (_, _) => const TeamProfileScreen(),
                    routes: [
                      // Ask the FA to change (2.10b), e.g. ask?kind=name
                      GoRoute(
                        path: 'ask',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => AskChangeScreen(
                          kind: TeamChangeKind.fromString(
                            state.uri.queryParameters['kind'],
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'edit/:section',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => TeamEditScreen(
                          section: TeamSection.fromString(
                                state.pathParameters['section'],
                              ) ??
                              TeamSection.details,
                        ),
                      ),
                    ],
                  ),
                  // Team only: Season fee (2.13c). Inside the More tab;
                  // adding a payment opens full-screen.
                  GoRoute(
                    path: 'fee',
                    builder: (_, _) => const SeasonFeeScreen(),
                    routes: [
                      GoRoute(
                        path: 'add',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, _) => const AddPaymentScreen(),
                      ),
                    ],
                  ),
                ],
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

  // 5. Pick the area for this role, and the screen you land on there.
  //    The FA lands on Home (the dashboard, 2.12a), not on Teams.
  final (area, landing) = switch (profile.role) {
    UserRole.faAdmin => (Routes.admin, Routes.adminHome),
    UserRole.teamAdmin => (Routes.team, Routes.team),
    UserRole.referee => (Routes.referee, Routes.referee),
    null => (Routes.welcome, Routes.welcome),
  };

  // 6. Stay inside your area, or go to its landing screen
  return location.startsWith(area) ? null : landing;
}