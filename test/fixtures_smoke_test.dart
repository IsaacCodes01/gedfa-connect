import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/domain/app_user.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/season_maker.dart';
import 'package:gedfa_connect/features/fixtures/domain/season_plan.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/fa_fixtures_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/match_details_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/season_draft_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/season_setup_screen.dart';
import 'package:gedfa_connect/features/fixtures/presentation/team_fixtures_screen.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';

KitChoice _kit(KitSlot slot, Color c) => KitChoice(
      slot: slot,
      kit: Kit(primary: c, shorts: Colors.white, socks: c),
      raw: const {},
    );

FixtureSide _side(String id, String name, String short, Color c) =>
    FixtureSide(id: id, name: name, shortName: short, colour: c);

final _aps = _side('aps', 'Apam Stars Football Club', 'APS', const Color(0xFF7A1F2B));
final _gry = _side('gry', 'Gomoa Royals', 'GRY', const Color(0xFF1259A8));

Fixture _match(
  String id, {
  int round = 4,
  Duration from = const Duration(days: 2, hours: 3),
  FixtureStatus status = FixtureStatus.scheduled,
  Competition category = Competition.division,
  AgeGroup? group,
  String? note,
}) =>
    Fixture(
      id: id,
      season: '2026-27',
      competitionId: '2026-27_${category.name}-league',
      category: category,
      ageGroup: group,
      round: round,
      home: _aps,
      away: _gry,
      kits: MatchKits(
        home: _kit(KitSlot.home, const Color(0xFF7A1F2B)),
        away: _kit(KitSlot.away, Colors.white),
        homeGk: _kit(KitSlot.goalkeeper, const Color(0xFFFFD100)),
        awayGk: _kit(KitSlot.goalkeeper, const Color(0xFF009A44)),
      ),
      kickoffAt: status == FixtureStatus.postponed && note != null
          ? null
          : DateTime.now().add(from),
      venue: 'Apam Park, Apam Junction',
      status: status,
      note: note,
    );

/// 18 Division teams for the season screens, two of them sharing a ground.
final _teams = [
  for (var i = 0; i < 18; i++)
    MatchTeam(
      side: _side('t$i', 'Team number $i Football Club', 'T$i', const Color(0xFF1259A8)),
      rawKits: const {},
      kits: {
        KitSlot.home: Kit(primary: i.isEven ? Colors.red : Colors.blue, shorts: Colors.white, socks: Colors.white),
        KitSlot.away: const Kit(primary: Colors.white, shorts: Colors.black, socks: Colors.white),
        KitSlot.goalkeeper: const Kit(primary: Color(0xFFFFD100), shorts: Colors.black, socks: Colors.black),
      },
      homeGround: i < 2 ? 'Apam Park' : 'Ground $i',
    ),
];

/// A real draft of those 18 teams (home and away: 34 matchdays).
class _FakeMaker extends SeasonMaker {
  @override
  SeasonSession? build() => SeasonSession(
        category: Competition.division,
        group: null,
        teams: _teams,
        firstRound: 1,
        settings: SeasonSettings(
          firstDay: DateTime(2026, 11, 14),
          homeAndAway: true,
          sundayToo: true,
          kickoffHour: 15,
          kickoffMinute: 0,
        ),
        draft: planSeason(
          teams: [
            for (final t in _teams)
              PlanTeam(id: t.side.id, name: t.side.name, ground: t.homeGround),
          ],
          settings: SeasonSettings(
            firstDay: DateTime(2026, 11, 14),
            homeAndAway: true,
            sundayToo: true,
            kickoffHour: 15,
            kickoffMinute: 0,
          ),
        ),
      );
}

final _fixtures = [
  _match('m1'),
  _match('m2', from: const Duration(days: 9)),
  _match('m3', round: 3, from: const Duration(days: -7)),
  _match('m4', status: FixtureStatus.postponed, note: 'Pitch waterlogged'),
  _match('m5', status: FixtureStatus.cancelled, note: 'Club withdrew'),
  _match('j1', category: Competition.juvenile, group: AgeGroup.u17),
];

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Size size,
  Brightness brightness, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        seasonFixturesProvider.overrideWith((ref) => Stream.value(_fixtures)),
        myFixturesProvider.overrideWith((ref) => Stream.value(_fixtures)),
        appUserProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(uid: 'u', role: null, teamId: 'aps'),
          ),
        ),
        myTeamProvider.overrideWith(
          (ref) => Stream.value(
            const Team(
              id: 'aps',
              name: 'Apam Stars Football Club',
              shortName: 'APS',
              town: 'Apam',
              categories: {Competition.division, Competition.juvenile},
              adminUids: ['u'],
            ),
          ),
        ),
        unreadCountProvider.overrideWithValue(2),
        seasonMakerProvider.overrideWith(_FakeMaker.new),
        fixtureProvider.overrideWith(
          (ref, id) => Stream.value(_fixtures.firstWhere((f) => f.id == id)),
        ),
        fixtureHistoryProvider.overrideWith(
          (ref, id) => Stream.value([
            (
              what: 'Kick-off: Sat 14 Nov, 3:00 pm → Sun 15 Nov, 4:00 pm',
              reason: 'The home ground is booked for a funeral on Saturday',
              at: DateTime(2026, 11, 8, 10, 30),
            ),
            (what: 'Match added', reason: null, at: DateTime(2026, 11, 1)),
          ]),
        ),
        seasonTeamsProvider.overrideWith((ref, _) async => _teams),
        savedDraftProvider.overrideWith((ref, _) => Stream.value(null)),
        allTeamsProvider.overrideWith((ref) => Stream.value(const <Team>[])),
        myAudienceProvider.overrideWithValue('team:aps'),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final error = tester.takeException();
    expect(error, isNull,
        reason: 'frame $i: ${error is FlutterError ? error.toStringDeep() : error}');
  }
}

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [360.0, 1280.0]) {
      testWidgets('FA Fixtures tab, $width wide, $brightness', (tester) async {
        await _pump(tester, const FaFixturesScreen(), Size(width, 2400), brightness);
        expect(find.text('Matchday 4'), findsOneWidget);
        expect(find.text('Postponed'), findsWidgets);
      });

      testWidgets('team Fixtures tab, $width wide, $brightness', (tester) async {
        await _pump(tester, const TeamFixturesScreen(), Size(width, 2400), brightness);
        expect(find.text('Next match'), findsOneWidget);
        expect(find.textContaining('Team sheet due'), findsOneWidget);
      });
    }
  }

  for (final width in [360.0, 1280.0]) {
    testWidgets('Make the season (G1), $width wide', (tester) async {
      await _pump(tester, const SeasonSetupScreen(), Size(width, 2400), Brightness.light);
      expect(find.text('Make the draft'), findsOneWidget);
      expect(find.text('All 18 Division teams'), findsOneWidget);
    });

    testWidgets('Draft season (G2), 18 teams, $width wide', (tester) async {
      await _pump(tester, const SeasonDraftScreen(), Size(width, 2400), Brightness.dark);
      expect(find.text('34'), findsOneWidget); // matchdays
      expect(find.text('306'), findsOneWidget); // matches
      expect(find.text('Publish and tell all teams'), findsOneWidget);
    });
  }

  for (final (id, what) in [
    ('m1', 'coming up'),
    ('m3', 'played'),
    ('m4', 'postponed'),
    ('j1', 'juvenile'),
  ]) {
    for (final width in [360.0, 1280.0]) {
      testWidgets('Match details, $what, $width wide', (tester) async {
        await _pump(tester, MatchDetailsScreen(fixtureId: id, isFa: true),
            Size(width, 2400), Brightness.light);
        expect(find.text('Match info'), findsOneWidget);
        expect(find.text('Directions'), findsOneWidget);
      });
    }
  }

  testWidgets('Match details with large text (130%) on a small phone', (tester) async {
    await _pump(tester, const MatchDetailsScreen(fixtureId: 'm1'),
        const Size(320, 3000), Brightness.dark, textScale: 1.3);
    expect(find.text('What changed'), findsOneWidget);
  });

  testWidgets('both tabs with large text (130%) on a small phone', (tester) async {
    await _pump(tester, const TeamFixturesScreen(), const Size(320, 3000),
        Brightness.light, textScale: 1.3);
    await _pump(tester, const FaFixturesScreen(), const Size(320, 3000),
        Brightness.light, textScale: 1.3);
  });
}
