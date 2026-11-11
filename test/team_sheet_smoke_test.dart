import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/domain/app_user.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/league/domain/league_settings.dart';
import 'package:gedfa_connect/features/players/data/division_juveniles_repository.dart';
import 'package:gedfa_connect/features/players/domain/division_juveniles.dart';
import 'package:gedfa_connect/features/players/data/player_profile_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/player_profile.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/suspensions/data/player_suspension_repository.dart';
import 'package:gedfa_connect/features/suspensions/domain/player_suspension.dart';
import 'package:gedfa_connect/features/team_sheets/data/team_sheet_repository.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/team_sheet_screen.dart';
import 'package:gedfa_connect/features/teams/data/team_profile_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The team sheet (3.1a2, 3.1b) on a small phone and a laptop, light and
/// dark: no overflow; picking 11 opens step 2; with a goalkeeper picked
/// it is ready to save; the shirt numbers page.

const _kitColours = Kit(
  primary: Colors.red,
  shorts: Colors.white,
  socks: Colors.red,
);

// Team profile: the team manager is listed after the head coach on
// purpose (the sheet puts the manager first).
const _details = TeamRequest(
  uid: 'req',
  teamName: 'Royal Unique Football Club of Apam',
  shortName: 'RUF',
  town: 'Apam',
  homeGround: 'Apam Park',
  homeKit: _kitColours,
  awayKit: _kitColours,
  goalkeeperKit: _kitColours,
  officials: [
    Official(
      role: OfficialRole.headCoach,
      name: 'Kofi Mensah',
      phone: '0240000001',
      licence: 'CAF D',
    ),
    Official(
      role: OfficialRole.teamManager,
      name: 'Kojo Antwi',
      phone: '0240000002',
    ),
    Official(
      role: OfficialRole.kitManager,
      name: 'Ama Serwaa',
      phone: '0240000003',
    ),
  ],
  status: ApprovalStatus.approved,
  categories: {Competition.division, Competition.juvenile},
);

const _team = Team(
  id: 'ruf',
  name: 'Royal Unique Football Club of Apam',
  shortName: 'RUF',
  town: 'Apam',
  categories: {Competition.division, Competition.juvenile},
  adminUids: ['u'],
  requestUid: 'req',
);

KitChoice _kit(KitSlot slot) => KitChoice(
  slot: slot,
  kit: const Kit(primary: Colors.red, shorts: Colors.white, socks: Colors.red),
  raw: const {},
);

Fixture _match({
  AgeGroup? ageGroup,
  Map<String, List<String>> banned = const {},
}) => Fixture(
  id: 'm1',
  season: '2026-27',
  competitionId: ageGroup == null
      ? '2026-27_division-league'
      : '2026-27_juvenile-league',
  category: ageGroup == null ? Competition.division : Competition.juvenile,
  ageGroup: ageGroup,
  round: 3,
  home: const FixtureSide(
    id: 'ruf',
    name: 'Royal Unique Football Club of Apam',
    shortName: 'RUF',
    colour: Colors.red,
  ),
  away: const FixtureSide(
    id: 'ast',
    name: 'Asebu Stars Sporting Club',
    shortName: 'AST',
    colour: Colors.green,
  ),
  kits: MatchKits(
    home: _kit(KitSlot.home),
    away: _kit(KitSlot.away),
    homeGk: _kit(KitSlot.goalkeeper),
    awayGk: _kit(KitSlot.goalkeeper),
  ),
  kickoffAt: DateTime.now().add(const Duration(days: 4)),
  venue: 'Apam Park',
  status: FixtureStatus.scheduled,
  banned: banned,
);

const _positions = [
  Position.gk,
  Position.rb,
  Position.lb,
  Position.cb,
  Position.cb,
  Position.dm,
  Position.cm,
  Position.amf,
  Position.rw,
  Position.st,
  Position.lw,
  Position.gk,
  Position.cb,
  Position.cm,
  Position.cf,
  Position.st,
  Position.rwb,
  Position.rm,
];

List<Player> _players({AgeGroup? group}) => [
  for (var i = 0; i < _positions.length; i++)
    Player(
      id: 'p$i',
      teamId: 'ruf',
      teamName: 'Royal Unique FC',
      category: group == null ? Competition.division : Competition.juvenile,
      ageGroup: group == null
          ? null
          : (i == 5 || (group == AgeGroup.u17 && i == 6)
                ? AgeGroup.u13
                : group),
      fullName: 'Kwabena Mensah-Bonsu Asamoah $i',
      dob: DateTime(2000),
      position: _positions[i],
      jerseyNo: i + 1,
      playerCode: 'GE26-00${i + 10}',
      status: ApprovalStatus.approved,
    ),
  Player(
    id: 'waiting',
    teamId: 'ruf',
    teamName: 'Royal Unique FC',
    category: group == null ? Competition.division : Competition.juvenile,
    ageGroup: group,
    fullName: 'Yaw Pending',
    dob: DateTime(2000),
    position: Position.st,
    jerseyNo: 40,
    status: ApprovalStatus.pending,
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Brightness b, {
  AgeGroup? group,
  Map<String, TeamSheet> sheets = const {},
  List<Player> extraPlayers = const [],
  DivisionJuveniles named = const DivisionJuveniles(),
  Map<String, List<String>> banned = const {},
  List<PlayerSuspension> suspensions = const [],
  List<Fixture> otherMatches = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        myTeamProvider.overrideWith((ref) => Stream.value(_team)),
        myTeamDetailsProvider.overrideWith((ref) => Stream.value(_details)),
        appUserProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(uid: 'u', role: null, displayName: 'Isaac Otabil'),
          ),
        ),
        leagueSettingsProvider.overrideWith(
          (ref) => Stream.value(const LeagueSettings()),
        ),
        fixtureProvider.overrideWith(
          (ref, id) => Stream.value(_match(ageGroup: group, banned: banned)),
        ),
        // Player suspensions (3.1e2)
        mySuspensionsProvider.overrideWith((ref) => Stream.value(suspensions)),
        myFixturesProvider.overrideWith(
          (ref) => Stream.value([
            _match(ageGroup: group, banned: banned),
            ...otherMatches,
          ]),
        ),
        teamPlayersProvider.overrideWith(
          (ref) => Stream.value([..._players(group: group), ...extraPlayers]),
        ),
        myDivisionJuvenilesProvider.overrideWith((ref) => Stream.value(named)),
        teamSheetProvider.overrideWith((ref, key) => Stream.value(null)),
        myTeamSheetsProvider.overrideWith((ref) => Stream.value(sheets)),
        teamProfilesProvider.overrideWith(
          (ref) => Stream.value({
            'p3': const PlayerProfile(
              playerId: 'p3',
              teamId: 'ruf',
              availability: Availability.injured,
            ),
          }),
        ),
        armbandsProvider.overrideWith(
          (ref, category) => Stream.value(
            const Armbands(captainId: 'p3', viceCaptainId: 'p5'),
          ),
        ),
      ],
      child: MaterialApp.router(
        // The app's own theme: its full-width buttons once broke a row
        theme: b == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
        // AppBackButton needs go_router
        routerConfig: GoRouter(
          initialLocation: '/sheet',
          routes: [
            GoRoute(
              path: '/sheet',
              builder: (_, _) => const TeamSheetScreen(fixtureId: 'm1'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _noError(WidgetTester tester) {
  final error = tester.takeException();
  expect(
    error,
    isNull,
    reason: error is FlutterError ? error.toStringDeep() : '$error',
  );
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('small phone, ${b.name}: the list fits', (tester) async {
      await _pump(tester, const Size(360, 740), b);
      _noError(tester);
      expect(find.text('GOALKEEPERS'), findsOneWidget);
      expect(
        find.text('Pick your starting players (7 at least).'),
        findsOneWidget,
      );
    });
  }

  testWidgets('3.1e2 (SP4): a suspended player is locked, and a tap says why', (
    tester,
  ) async {
    await _pump(
      tester,
      const Size(360, 1600),
      Brightness.dark,
      banned: {
        'ruf': ['p1'],
      },
      suspensions: const [
        PlayerSuspension(
          id: 'b1',
          playerId: 'p1',
          playerName: 'Kwabena Mensah-Bonsu Asamoah 1',
          teamId: 'ruf',
          teamName: 'Royal Unique FC',
          season: '2026-27',
          competition: BanCompetition.division(),
          reason: BanReason.redCard,
          matches: 2,
          fixtureIds: ['m1'],
        ),
      ],
    );
    _noError(tester);
    expect(find.text('Suspended · 2 matches left'), findsOneWidget);
    expect(find.text('Suspended'), findsOneWidget);
    await tester.tap(find.text('Suspended · 2 matches left'));
    await tester.pump();
    expect(find.textContaining('is suspended (red card)'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('3.1e3 (SB3): a U15 playing up, blocked by a Division ban', (
    tester,
  ) async {
    // Division matches on days 2 and 6 count; the U17 match (day 4) is
    // between them, so the player can't play it (no mark on it yet)
    Fixture division(String id, int days) => Fixture(
      id: id,
      season: '2026-27',
      competitionId: '2026-27_division-league',
      category: Competition.division,
      round: days,
      home: _match().home,
      away: _match().away,
      kits: _match().kits,
      kickoffAt: DateTime.now().add(Duration(days: days)),
      venue: 'Apam Park',
      status: FixtureStatus.scheduled,
    );
    await _pump(
      tester,
      const Size(360, 1800),
      Brightness.light,
      group: AgeGroup.u17,
      extraPlayers: [
        Player(
          id: 'k15',
          teamId: 'ruf',
          teamName: 'Royal Unique FC',
          category: Competition.juvenile,
          ageGroup: AgeGroup.u15,
          fullName: 'Kojo Brew',
          dob: DateTime(2012),
          position: Position.dm,
          jerseyNo: 60,
          playerCode: 'GJ26-0012',
          status: ApprovalStatus.approved,
        ),
      ],
      otherMatches: [division('d1', 2), division('d2', 6)],
      suspensions: const [
        PlayerSuspension(
          id: 'b1',
          playerId: 'k15',
          playerName: 'Kojo Brew',
          teamId: 'ruf',
          teamName: 'Royal Unique FC',
          season: '2026-27',
          competition: BanCompetition.division(),
          reason: BanReason.redCard,
          matches: 2,
          fixtureIds: ['d1', 'd2'],
        ),
      ],
    );
    _noError(tester);
    expect(find.text('Suspended · Division ban'), findsOneWidget);
    await tester.tap(find.text('Suspended · Division ban'));
    await tester.pump();
    expect(
      find.textContaining("(red card, Division) and can't play any match"),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('laptop: the list fits', (tester) async {
    await _pump(tester, const Size(1280, 800), Brightness.light);
    _noError(tester);
  });

  Future<void> pickEleven(WidgetTester tester) async {
    // The first 11 on screen: both goalkeepers (p0, p11), six defenders
    // (p3 is the captain in Profiles) and three midfielders (p5 is VC)
    final elevens = find.text('11');
    for (var i = 0; i < 11; i++) {
      await tester.tap(elevens.at(i));
      await tester.pump();
    }
  }

  FilledButton button(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );

  testWidgets('phone: Players, Roles & numbers, then Check and Save', (
    tester,
  ) async {
    // Phone width, tall enough for every row to be tapped
    await _pump(tester, const Size(400, 2600), Brightness.light);
    await pickEleven(tester);
    _noError(tester);
    // p3 is injured: picked with a warning, still fine
    expect(find.textContaining('injured or unavailable'), findsOneWidget);
    // Two goalkeepers start: the team picks one in step 2
    expect(find.text('Goalkeeper: pick one in step 2'), findsOneWidget);

    await tester.tap(find.text('Next: Roles & numbers'));
    await tester.pumpAndSettle();
    _noError(tester);
    expect(find.text('ARMBANDS AND GOALKEEPER'), findsOneWidget);
    // Captain and vice-captain from Profiles; the manager and coach ticked
    expect(find.text('#4 Kwabena Mensah-Bonsu Asamoah 3'), findsOneWidget);
    expect(find.text('#6 Kwabena Mensah-Bonsu Asamoah 5'), findsOneWidget);
    expect(find.text('3 of 7'), findsOneWidget);
    expect(
      find.text('Pick a goalkeeper from the starting 11.'),
      findsOneWidget,
    );
    expect(button(tester, 'Next: Check').onPressed, isNull);

    // Goalkeeper: Change, then the second goalkeeper (p11, number 12)
    await tester.tap(find.text('Change').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kwabena Mensah-Bonsu Asamoah 11').last);
    await tester.pumpAndSettle();
    _noError(tester);
    expect(find.text('#12 Kwabena Mensah-Bonsu Asamoah 11'), findsOneWidget);

    // Step 3, Check (MS5): the sheet as it will look, the checks, Save
    await tester.tap(find.text('Next: Check'));
    await tester.pumpAndSettle();
    _noError(tester);
    expect(find.text('STARTING 11'), findsOneWidget);
    expect(
      find.text('Team manager and head coach on the sheet'),
      findsOneWidget,
    );
    expect(
      find.text('Captain starts · vice-captain on the sheet'),
      findsOneWidget,
    );
    // Officials on the sheet: the manager first, then the head coach
    expect(
      find.textContaining('Kojo Antwi (Team manager) · Kofi Mensah'),
      findsOneWidget,
    );
    expect(button(tester, 'Save team sheet').onPressed, isNotNull);
  });

  testWidgets('laptop (MS7): players left, the sheet filling in on the right', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 2400), Brightness.dark);
    await pickEleven(tester);
    _noError(tester);
    // No steps: the sheet, roles and checks sit beside the players
    expect(find.text('Next: Roles & numbers'), findsNothing);
    expect(find.text('The sheet'), findsOneWidget);
    expect(find.text('STARTING 11'), findsOneWidget);
    expect(find.text('ARMBANDS AND GOALKEEPER'), findsOneWidget);
    expect(button(tester, 'Save team sheet').onPressed, isNull);

    await tester.tap(find.text('Change').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kwabena Mensah-Bonsu Asamoah 0').last);
    await tester.pumpAndSettle();
    _noError(tester);
    expect(button(tester, 'Save team sheet').onPressed, isNotNull);
  });

  testWidgets('Use last sheet copies the picks, armbands and numbers', (
    tester,
  ) async {
    await _pump(
      tester,
      const Size(400, 2600),
      Brightness.light,
      sheets: {
        'm0': TeamSheet(
          fixtureId: 'm0',
          teamId: 'ruf',
          category: Competition.division,
          starters: [for (var i = 0; i <= 10; i++) 'p$i'],
          captainId: 'p4',
          goalkeeperId: 'p0',
          numbers: {for (var i = 0; i <= 10; i++) 'p$i': i == 1 ? 33 : i + 1},
          savedAt: DateTime(2026, 11, 1),
        ),
      },
    );
    await tester.tap(find.text('Use last sheet'));
    await tester.pumpAndSettle();
    _noError(tester);
    expect(find.textContaining('Goalkeeper starts'), findsOneWidget);

    await tester.tap(find.text('Next: Roles & numbers'));
    await tester.pumpAndSettle();
    expect(find.text('#5 Kwabena Mensah-Bonsu Asamoah 4'), findsOneWidget);
    expect(find.text('#1 Kwabena Mensah-Bonsu Asamoah 0'), findsOneWidget);
    expect(find.text('11 numbers · 1 changed'), findsOneWidget);
  });

  testWidgets('shirt numbers: the page and the picker fit a small phone', (
    tester,
  ) async {
    // Phone width, tall enough for every row to be tapped
    await _pump(tester, const Size(360, 2600), Brightness.dark);
    await pickEleven(tester);
    await tester.tap(find.text('Next: Roles & numbers'));
    await tester.pumpAndSettle();
    _noError(tester);
    expect(find.text('11 numbers · 0 changed'), findsOneWidget);

    await tester.tap(find.text('11 numbers · 0 changed'));
    await tester.pumpAndSettle();
    _noError(tester);
    expect(find.text('Shirt numbers'), findsOneWidget);
    expect(find.text('STARTING 11'), findsOneWidget);

    await tester.tap(find.text('Kwabena Mensah-Bonsu Asamoah 0'));
    await tester.pumpAndSettle();
    _noError(tester);
    expect(
      find.text('Shirt for Kwabena Mensah-Bonsu Asamoah 0'),
      findsOneWidget,
    );
    // Wear 30, then Done goes back to step 2 with 1 changed
    await tester.tap(find.text('30'));
    await tester.pump();
    await tester.tap(find.text('Wear 30'));
    await tester.pumpAndSettle();
    expect(find.text('usual 1'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('11 numbers · 1 changed'), findsOneWidget);
  });

  testWidgets('Division sheet: the club\'s juveniles with their pills (DJ3)', (
    tester,
  ) async {
    Player child(String id, AgeGroup g) => Player(
      id: id,
      teamId: 'ruf',
      teamName: 'Royal Unique FC',
      category: Competition.juvenile,
      ageGroup: g,
      fullName: 'Kojo Brew $id',
      dob: DateTime(2011),
      position: Position.amf,
      jerseyNo: 60,
      playerCode: 'GJ26-0$id',
      status: ApprovalStatus.approved,
    );
    await _pump(
      tester,
      const Size(400, 2800),
      Brightness.light,
      extraPlayers: [child('j1', AgeGroup.u15), child('j2', AgeGroup.u17)],
      named: const DivisionJuveniles({'j1': AgeGroup.u15}),
    );
    _noError(tester);
    expect(find.text('JUVENILES (DIVISION LIST)'), findsOneWidget);
    // j1 is named: shown with "U15"; j2 is not named: not on the sheet
    expect(find.text('Kojo Brew j1'), findsOneWidget);
    expect(find.text('U15'), findsOneWidget);
    expect(find.text('Kojo Brew j2'), findsNothing);
  });

  testWidgets('U17 match: 1 U13 at most; the other is locked (MS6)', (
    tester,
  ) async {
    await _pump(
      tester,
      const Size(400, 2800),
      Brightness.light,
      group: AgeGroup.u17,
    );
    _noError(tester);
    expect(find.text('U13 0 / 1'), findsOneWidget);
    // Pick the first U13 (in "Playing up from U13")
    final firstU13 = find.ancestor(
      of: find.text('Kwabena Mensah-Bonsu Asamoah 5'),
      matching: find.byType(Row),
    );
    await tester.tap(
      // (the nearest Row is the name line; the next one is the player row)
      find.descendant(of: firstU13.at(1), matching: find.text('11')),
    );
    await tester.pump();
    expect(find.text('U13 1 / 1'), findsOneWidget);
    expect(find.text('U13 limit reached'), findsOneWidget);
  });

  testWidgets('juvenile U15: the squad, then playing up from U13', (
    tester,
  ) async {
    await _pump(
      tester,
      const Size(360, 740),
      Brightness.dark,
      group: AgeGroup.u15,
    );
    _noError(tester);
    expect(find.text('U15 SQUAD'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('PLAYING UP FROM U13'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('U13 ↑'), findsOneWidget);
  });
}
