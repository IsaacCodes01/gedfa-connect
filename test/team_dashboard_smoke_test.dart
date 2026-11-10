import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/domain/app_user.dart';
import 'package:gedfa_connect/features/dashboard/presentation/team_dashboard_screen.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/league/domain/league_settings.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/screening/data/screening_repository.dart';
import 'package:gedfa_connect/features/teams/data/correction_request_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The team's Home (TDa) on a small phone, light and dark: no overflow,
/// and the Division | Juvenile switch changes the next match.

const _team = Team(
  id: 'ruf',
  name: 'Royal Unique Football Club of Apam',
  shortName: 'RUF',
  town: 'Apam',
  categories: {Competition.division, Competition.juvenile},
  adminUids: ['u'],
);

KitChoice _kit(KitSlot slot) => KitChoice(
  slot: slot,
  kit: const Kit(primary: Colors.red, shorts: Colors.white, socks: Colors.red),
  raw: const {},
);

Fixture _match(
  String id,
  DateTime kickoff, {
  Competition category = Competition.division,
  AgeGroup? ageGroup,
  FixtureStatus status = FixtureStatus.scheduled,
}) => Fixture(
  id: id,
  season: '2026-27',
  competitionId: '2026-27_${category.name}-league',
  category: category,
  ageGroup: ageGroup,
  round: 3,
  home: const FixtureSide(
    id: 'ruf',
    name: 'Royal Unique Football Club of Apam',
    shortName: 'RUF',
    colour: Colors.red,
  ),
  away: FixtureSide(
    id: 'ast',
    name: category == Competition.juvenile
        ? 'Asebu Stars B'
        : 'Asebu Stars Sporting Club',
    shortName: category == Competition.juvenile ? 'AST B' : 'AST',
    colour: Colors.green,
  ),
  kits: MatchKits(
    home: _kit(KitSlot.home),
    away: _kit(KitSlot.away),
    homeGk: _kit(KitSlot.goalkeeper),
    awayGk: _kit(KitSlot.goalkeeper),
  ),
  kickoffAt: kickoff,
  venue: 'Apam Park, near the District Assembly',
  status: status,
);

var _n = 0;
Player _player({ApprovalStatus status = ApprovalStatus.approved}) => Player(
  id: 'p${_n++}',
  teamId: 'ruf',
  teamName: 'Royal Unique FC',
  category: Competition.division,
  fullName: 'Kwabena Mensah-Bonsu $_n',
  dob: DateTime(2000),
  position: Position.gk,
  jerseyNo: _n % 99 + 1,
  status: status,
);

Future<void> _pump(WidgetTester tester, Size size, Brightness b) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final soon = DateTime.now().add(const Duration(days: 4));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        myTeamProvider.overrideWith((ref) => Stream.value(_team)),
        appUserProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(uid: 'u', role: null, displayName: 'Isaac Otabil'),
          ),
        ),
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
        leagueSettingsProvider.overrideWith(
          (ref) => Stream.value(const LeagueSettings()),
        ),
        myFixturesProvider.overrideWith(
          (ref) => Stream.value([
            _match('div1', soon),
            _match('div2', soon.add(const Duration(days: 7))),
            _match(
              'div3',
              soon.add(const Duration(days: 14)),
              status: FixtureStatus.postponed,
            ),
            _match(
              'u15',
              soon.add(const Duration(days: 1)),
              category: Competition.juvenile,
              ageGroup: AgeGroup.u15,
            ),
          ]),
        ),
        teamPlayersProvider.overrideWith(
          (ref) => Stream.value([
            for (var i = 0; i < 16; i++) _player(),
            _player(status: ApprovalStatus.rejected),
          ]),
        ),
        myCorrectionRequestProvider.overrideWith((ref) => Stream.value(null)),
        upcomingScreeningsProvider.overrideWith((ref) => Stream.value([])),
        unreadCountProvider.overrideWithValue(3),
        myAudienceProvider.overrideWithValue('team'),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: b),
        home: const TeamDashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final b in Brightness.values) {
    for (final width in [320.0, 360.0]) {
      testWidgets('phone $width wide, $b', (tester) async {
        await _pump(tester, Size(width, 2400), b);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Good'), findsOneWidget);
        expect(find.text('Needs you'), findsOneWidget);
        expect(find.text('1 player sent back'), findsOneWidget);
        expect(find.text('Add 2 more for a full squad'), findsOneWidget);
        expect(find.text('NEXT MATCH · DIVISION · ROUND 3'), findsOneWidget);
        expect(find.text('Postponed'), findsOneWidget);
      });
    }
  }

  testWidgets('Juvenile on the switch shows the U15 match', (tester) async {
    await _pump(tester, const Size(360, 2400), Brightness.light);
    await tester.tap(find.bySemanticsLabel(RegExp('^Juvenile matches')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('NEXT MATCH · JUVENILE U15 · ROUND 3'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });
}
