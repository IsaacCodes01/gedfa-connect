import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/app_shell.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/startup_gate.dart';
import 'package:gedfa_connect/app/startup_screen.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/presentation/login_screen.dart';
import 'package:gedfa_connect/features/dashboard/presentation/fa_dashboard_screen.dart';
import 'package:gedfa_connect/features/dashboard/presentation/team_dashboard_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/announcement_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/compose_announcement_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/fa_announcement_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/fa_announcements_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/notification_details_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/notifications_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_ask_correction_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_correct_details_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_team_changes_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_player_review_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_player_teams_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_request_review_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_requests_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_juvenile_child_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/competitions_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/cup_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/cup_form_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/fa_fixtures_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/fixture_form_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/fixture_kits_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/match_details_screen.dart';
import 'package:gedfa_connect/features/player_checks/presentation/check_players_screen.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/official_sheet_screen.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/team_sheet_view_screen.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/team_sheet_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/season_draft_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/season_setup_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/team_fixtures_screen.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/officials/presentation/referee_home_screen.dart';
import 'package:gedfa_connect/features/officials/presentation/referee_matches_screen.dart';
import 'package:gedfa_connect/features/officials/presentation/appoint_round_screen.dart';
import 'package:gedfa_connect/features/suspensions/presentation/suspend_player_screen.dart';
import 'package:gedfa_connect/features/suspensions/presentation/suspended_players_screen.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_team_juvenile_screen.dart';
import 'package:gedfa_connect/features/fa/presentation/fa_team_players_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/verify_email_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/forgot_password_screen.dart';
import 'package:gedfa_connect/features/auth/presentation/sign_up_screen.dart';
import 'package:gedfa_connect/features/teams/presentation/welcome_screen.dart';
import 'package:gedfa_connect/features/onboarding/data/intro_seen.dart';
import 'package:gedfa_connect/features/onboarding/presentation/intro_screen.dart';
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
  ref.listen(introSeenProvider, (_, _) => refresh.value++);
  ref.listen(startupGateProvider, (_, _) => refresh.value++);
  // Someone signed in on this phone is past the intro: don't show it to
  // them after they log out (people who had the app before R-b).
  ref.listen(authStateProvider, (_, next) {
    if (next.value != null) ref.read(introSeenProvider.notifier).markSeen();
  });

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
        path: Routes.intro,
        pageBuilder: (_, state) => fadeInPage(state, const IntroScreen()),
      ),
      GoRoute(
        path: Routes.login,
        // From the start-up screen the logo glides into Log in's header
        // first (RU1), so Log in itself appears without a transition.
        pageBuilder: (_, state) => fadeInPage(
          state,
          const LoginScreen(),
          duration: ref.read(startupGateProvider.notifier).glideToLogin
              ? Duration.zero
              : const Duration(milliseconds: 300),
        ),
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
        pageBuilder: (_, state, navigationShell) => fadeInPage(
          state,
          AppShell(
            navigationShell: navigationShell,
            destinations: adminDestinations,
            openedFromHome: Routes.isFromHome(state.uri) ||
                Routes.backOf(state.uri) != null,
          ),
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
                    routes: [
                      // One note's details (3.0f)
                      GoRoute(
                        path: 'note/:id',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => NotificationDetailsScreen(
                          id: state.pathParameters['id']!,
                        ),
                      ),
                      // An announcement, opened from the bell
                      GoRoute(
                        path: 'announcement/:id',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => FaAnnouncementScreen(
                          id: state.pathParameters['id']!,
                        ),
                      ),
                    ],
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
                  // Player suspensions (3.1e1): Suspend (SP1), Suspended (SP2)
                  GoRoute(
                    path: 'suspend/:playerId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => SuspendPlayerScreen(
                      playerId: state.pathParameters['playerId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'suspended',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const SuspendedPlayersScreen(),
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
                  // Appoint a matchday's officials (3.5a, MO3)
                  GoRoute(
                    path: 'officials',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => AppointRoundScreen(
                      competitionId: state.uri.queryParameters['c'] ?? '',
                      round:
                          int.tryParse(state.uri.queryParameters['r'] ?? '') ??
                          1,
                      ageGroup: state.uri.queryParameters['g'],
                    ),
                  ),
                  // Competitions (3.0c1, C1), then a new cup or gala (C2)
                  GoRoute(
                    path: 'competitions',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const CompetitionsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, _) => const CupFormScreen(),
                      ),
                      // A cup's page (3.0c1b, C7), then "Change"
                      GoRoute(
                        path: 'cup/:cupId',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) =>
                            CupScreen(cupId: state.pathParameters['cupId']!),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (_, state) => CupFormScreen(
                              cupId: state.pathParameters['cupId'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                  // One team's sheet, read only (3.2)
                  GoRoute(
                    path: 'match/:id/sheet/:teamId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => TeamSheetViewScreen(
                      fixtureId: state.pathParameters['id']!,
                      teamId: state.pathParameters['teamId']!,
                      isFa: true,
                    ),
                  ),
                  // The official team sheet as a PDF (3.3)
                  GoRoute(
                    path: 'match/:id/official-sheet',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => OfficialSheetScreen(
                      fixtureId: state.pathParameters['id']!,
                      viewer: SheetViewer.fa,
                    ),
                  ),
                  // An FA official who is the commissioner (3.6b)
                  GoRoute(
                    path: 'match/:id/check',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => CheckPlayersScreen(
                      fixtureId: state.pathParameters['id']!,
                      isFa: true,
                    ),
                  ),
                  GoRoute(
                    path: 'match/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => MatchDetailsScreen(
                      fixtureId: state.pathParameters['id']!,
                      isFa: true,
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
      // Team admin area: a shell with tabs (Home, Squad, Fixtures,
      // Profiles, More).
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, navigationShell) => fadeInPage(
          state,
          AppShell(
            navigationShell: navigationShell,
            destinations: teamDestinations,
            // Opened from a note with back= (3.0f2)
            openedFromHome: Routes.backOf(state.uri) != null,
          ),
        ),
        branches: [
          // Tab 0: Home (TDa)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.teamHome,
                builder: (_, _) => const TeamDashboardScreen(),
              ),
            ],
          ),
          // Tab 1: Squad
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
                        path: 'note/:id',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => NotificationDetailsScreen(
                          id: state.pathParameters['id']!,
                        ),
                      ),
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
          // Tab 2: Fixtures (3.0a)
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
                  // The other team's sheet, from the lock (3.2)
                  GoRoute(
                    path: 'match/:id/sheet/:teamId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => TeamSheetViewScreen(
                      fixtureId: state.pathParameters['id']!,
                      teamId: state.pathParameters['teamId']!,
                      isFa: false,
                    ),
                  ),
                  // The team prints its own sheet as a PDF (3.3b)
                  GoRoute(
                    path: 'match/:id/official-sheet',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => OfficialSheetScreen(
                      fixtureId: state.pathParameters['id']!,
                      viewer: SheetViewer.team,
                    ),
                  ),
                  GoRoute(
                    path: 'match/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => MatchDetailsScreen(
                      fixtureId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'sheet/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => TeamSheetScreen(
                      fixtureId: state.pathParameters['id']!,
                      startOnCheck:
                          state.uri.queryParameters['view'] == 'check',
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: Positions (who can play where)
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
          // Tab 4: More (Settings)
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
      // Referee area (3.5b, RD1–RD3): Home, Matches, More
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, navigationShell) => fadeInPage(
          state,
          AppShell(
            navigationShell: navigationShell,
            destinations: refereeDestinations,
            openedFromHome: Routes.backOf(state.uri) != null,
          ),
        ),
        branches: [
          // Tab 0: Home (RD1), and the bell
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.referee,
                builder: (_, _) => const RefereeHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const NotificationsScreen(),
                    routes: [
                      GoRoute(
                        path: 'note/:id',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => NotificationDetailsScreen(
                          id: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'announcement/:id',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => AnnouncementScreen(
                          id: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Tab 1: Matches (RD2); a match opens full-screen (RD3)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.refereeMatches,
                builder: (_, _) => const RefereeMatchesScreen(),
                routes: [
                  // The commissioner's players check (3.6b, MC2)
                  GoRoute(
                    path: 'match/:id/check',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => CheckPlayersScreen(
                      fixtureId: state.pathParameters['id']!,
                    ),
                  ),
                  // The official team sheet as a PDF (3.3), from the lock
                  GoRoute(
                    path: 'match/:id/official-sheet',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => OfficialSheetScreen(
                      fixtureId: state.pathParameters['id']!,
                      viewer: SheetViewer.official,
                    ),
                  ),
                  GoRoute(
                    path: 'match/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => MatchDetailsScreen(
                      fixtureId: state.pathParameters['id']!,
                      isOfficial: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 2: More (My profile, Settings)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.refereeMore,
                builder: (_, _) => const MoreScreen(),
                routes: [..._moreChildren()],
              ),
            ],
          ),
        ],
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

/// R-a2: the intro, Log in and each area's tabs fade in (from the start-up
/// screen, Log in or registration) instead of sliding.
Page<void> fadeInPage(
  GoRouterState state,
  Widget child, {
  Duration duration = const Duration(milliseconds: 450),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

/// Where a signed-out user may be: the intro until it has been seen on this
/// phone, then Log in (and its Sign up / Forgot password pages). Null =
/// stay.
String? signedOutRedirect(String location, {required bool introSeen}) {
  if (!introSeen) return location == Routes.intro ? null : Routes.intro;
  return location.startsWith(Routes.login) ? null : Routes.login;
}

String? _redirect(Ref ref, String location) {
  String? goTo(String target) => location == target ? null : target;

  final auth = ref.read(authStateProvider);
  final appUser = ref.read(appUserProvider);

  // 0. The start-up screen until its gate opens (R-a2: at least 2.5 s, and
  //    the next screen's fonts and pictures loaded). A page asked for when
  //    the app opened (web refresh, link) is remembered for step 6.
  final gate = ref.read(startupGateProvider.notifier);
  if (!ref.read(startupGateProvider)) {
    if (location != Routes.startup) gate.rememberWanted(location);
    return goTo(Routes.startup);
  }

  // 1. Still finding out who is signed in
  if (!auth.hasValue) return goTo(Routes.startup);

  // 2. Nobody signed in: the intro the first time on this phone (R-b),
  //    then Log in
  final authUser = auth.value;
  if (authUser == null) {
    return signedOutRedirect(location, introSeen: ref.read(introSeenProvider));
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
    UserRole.teamAdmin => (Routes.team, Routes.teamHome),
    UserRole.referee => (Routes.referee, Routes.referee),
    null => (Routes.welcome, Routes.welcome),
  };

  // 6. Stay inside your area, or go to its landing screen (or to the page
  //    asked for when the app opened, if it is in your area)
  if (location.startsWith(area)) return null;
  final wanted = gate.takeWanted();
  return wanted != null && wanted.startsWith(area) ? wanted : landing;
}