import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/domain/app_user.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/match_details_screen.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/official_sheet_screen.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/league/domain/league_settings.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/officials/data/officials_repository.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';
import 'package:gedfa_connect/features/officials/presentation/referee_home_screen.dart';
import 'package:gedfa_connect/features/officials/presentation/referee_matches_screen.dart';
import 'package:gedfa_connect/features/team_sheets/data/team_sheet_repository.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/player_checks/data/player_check_repository.dart';
import 'package:gedfa_connect/features/player_checks/domain/player_check.dart';
import 'package:gedfa_connect/features/player_checks/presentation/check_players_screen.dart';
import 'package:gedfa_connect/features/players/data/player_photos.dart';
import 'package:go_router/go_router.dart';

/// Records the commissioner's saves instead of writing (3.6b).
class _FakeChecks implements PlayerCheckRepository {
  final saved = <(String, CheckResult, String?)>[];

  @override
  Future<void> record({
    required String fixtureId,
    required CheckLine line,
    required CheckResult result,
    String? note,
    required String by,
    required String byName,
  }) async => saved.add((line.playerId, result, note));

  @override
  Stream<MatchPlayerChecks> watch(String fixtureId) =>
      Stream.value(MatchPlayerChecks(fixtureId: fixtureId));
}

/// The referee's area (3.5b): Home (RD1), Matches (RD2), a match with
/// Can't make it (RD3); and the pieces behind them.
void main() {
  KitChoice kit(KitSlot slot, Color c) => KitChoice(
    slot: slot,
    kit: Kit(primary: c, shorts: Colors.white, socks: c),
    raw: const {},
  );

  final now = DateTime.now();
  Fixture match(String id, Duration from, String home, String away) => Fixture(
    id: id,
    season: '2026-27',
    competitionId: '2026-27_division-league',
    category: Competition.division,
    round: 4,
    home: FixtureSide(
      id: home.toLowerCase(),
      name: '$home Football Club of Gomoa',
      shortName: home,
      colour: Colors.red,
    ),
    away: FixtureSide(
      id: away.toLowerCase(),
      name: '$away Sporting Club',
      shortName: away,
      colour: Colors.green,
    ),
    kits: MatchKits(
      home: kit(KitSlot.home, const Color(0xFFB3122A)),
      away: kit(KitSlot.away, const Color(0xFF00703F)),
      homeGk: kit(KitSlot.goalkeeper, const Color(0xFF7B1FA2)),
      awayGk: kit(KitSlot.goalkeeper, const Color(0xFFFF9800)),
    ),
    kickoffAt: now.add(from),
    venue: 'Apam Park, Apam',
    status: FixtureStatus.scheduled,
  );

  final fixtures = [
    match('m1', const Duration(days: 2), 'RUF', 'AST'),
    match('m2', const Duration(days: 9), 'NYA', 'OJO'),
    match('m0', const Duration(days: -7), 'KWA', 'GST'),
    match('x', const Duration(days: 3), 'APC', 'AFY'),
    // In 30 minutes: the sheets are locked (3.5c)
    match('live', const Duration(minutes: 30), 'RUF', 'AST'),
  ];

  TeamSheet sheet(String teamId, String prefix) => TeamSheet(
    fixtureId: 'live',
    teamId: teamId,
    category: Competition.division,
    starters: [for (var i = 1; i <= 11; i++) '$prefix$i'],
    bench: ['${prefix}12'],
    captainId: '${prefix}4',
    goalkeeperId: '${prefix}1',
    numbers: {for (var i = 1; i <= 12; i++) '$prefix$i': i},
    players: {
      for (var i = 1; i <= 12; i++)
        '$prefix$i': SheetPlayer(
          id: '$prefix$i',
          name: '$teamId player $i',
          position: 'CB',
          usual: i,
          code:
              'GE26-${prefix == 'h' ? '00' : '01'}${i.toString().padLeft(2, '0')}',
        ),
    },
    savedAt: DateTime(2026, 11, 12, 10),
  );
  const me = AppointedOfficial(uid: 'r1', name: 'Kwame Addo');
  final mine = {
    'm1': const MatchOfficials(
      fixtureId: 'm1',
      places: {
        OfficialPlace.referee: me,
        OfficialPlace.assistant1: AppointedOfficial(
          uid: 'r2',
          name: 'Esi Owusu',
        ),
        OfficialPlace.commissioner: AppointedOfficial(
          uid: 'f1',
          name: 'Kwesi Arthur',
        ),
      },
    ),
    'm2': const MatchOfficials(
      fixtureId: 'm2',
      places: {OfficialPlace.assistant1: me},
    ),
    'm0': const MatchOfficials(
      fixtureId: 'm0',
      places: {OfficialPlace.fourth: me},
    ),
  };

  group('appointments', () {
    test('coming up in order, played newest first, only mine', () {
      final list = appointmentsOf('r1', mine, fixtures, now);
      expect([for (final a in list.upcoming) a.match.id], ['m1', 'm2']);
      expect(list.upcoming.first.place, OfficialPlace.referee);
      expect([for (final a in list.played) a.match.id], ['m0']);
    });

    test('the others in the match, short', () {
      expect(othersLine(mine['m1']!, 'r1'), 'E. Owusu (A1), K. Arthur (Com.)');
      expect(shortName('Kwame'), 'Kwame');
    });

    test("Can't make it goes when the person is taken off or replaced", () {
      final o = MatchOfficials(
        fixtureId: 'm1',
        places: mine['m1']!.places,
        cantMake: const {'r2': 'Family funeral'},
      );
      expect(o.withPlace(OfficialPlace.referee, null).cantMake, {
        'r2': 'Family funeral',
      });
      final replaced = o.withPlace(
        OfficialPlace.assistant1,
        const AppointedOfficial(uid: 'r3', name: 'Yaw Boadu'),
      );
      expect(replaced.cantMake, isEmpty);
      final back = MatchOfficials.fromMap(
        'm1',
        o.toMap(season: '2026-27', by: 'fa1'),
      );
      expect(back.cantMake, {'r2': 'Family funeral'});
    });
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen,
    Size size,
    Brightness b, {
    Map<String, MatchOfficials>? officials,
    _FakeChecks? checks,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appUserProvider.overrideWith(
            (ref) => Stream.value(
              const AppUser(
                uid: 'r1',
                role: UserRole.referee,
                displayName: 'Kwame Addo',
              ),
            ),
          ),
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
          leagueSettingsProvider.overrideWith(
            (ref) => Stream.value(const LeagueSettings()),
          ),
          seasonFixturesProvider.overrideWith((ref) => Stream.value(fixtures)),
          myAppointmentsProvider.overrideWith(
            (ref) => Stream.value(officials ?? mine),
          ),
          fixtureProvider.overrideWith(
            (ref, id) => Stream.value(fixtures.firstWhere((f) => f.id == id)),
          ),
          fixtureHistoryProvider.overrideWith((ref, id) => Stream.value([])),
          matchOfficialsProvider.overrideWith(
            (ref, id) => Stream.value(
              (officials ?? mine)[id] ?? MatchOfficials(fixtureId: id),
            ),
          ),
          unreadCountProvider.overrideWithValue(1),
          teamSheetProvider.overrideWith(
            (ref, key) => Stream.value(
              key.$1 != 'live'
                  ? null
                  : key.$2 == 'ruf'
                  ? sheet('ruf', 'h')
                  : sheet('ast', 'a'),
            ),
          ),
          myNotificationsProvider.overrideWith((ref) => Stream.value([])),
          readMarkProvider.overrideWith(
            (ref) => Stream.value(const ReadMark()),
          ),
          pinnedAnnouncementProvider.overrideWithValue(null),
          myAudienceProvider.overrideWithValue('person:r1'),
          // 3.6b: the check so far (none) and no registered photos
          playerChecksProvider.overrideWith(
            (ref, id) => Stream.value(MatchPlayerChecks(fixtureId: id)),
          ),
          playerPhotoProvider.overrideWith((ref, id) async => null),
          playerCheckRepositoryProvider.overrideWithValue(
            checks ?? _FakeChecks(),
          ),
        ],
        child: MaterialApp.router(
          theme: b == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
          routerConfig: GoRouter(
            initialLocation: '/s',
            routes: [GoRoute(path: '/s', builder: (_, _) => screen)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final b in Brightness.values) {
    for (final width in [360.0, 1280.0]) {
      testWidgets('RD1 Home, $width wide, ${b.name}', (tester) async {
        await pump(tester, const RefereeHomeScreen(), Size(width, 1600), b);
        expect(find.text('You: Referee'), findsOneWidget);
        expect(find.textContaining('With: E. Owusu (A1)'), findsOneWidget);
        expect(
          find.textContaining('Team sheets open to you at'),
          findsOneWidget,
        );
        expect(find.text('You: Assistant 1'), findsOneWidget); // coming up
        expect(find.text('2 appointments'), findsOneWidget);
      });

      testWidgets('RD2 Matches, $width wide, ${b.name}', (tester) async {
        await pump(tester, const RefereeMatchesScreen(), Size(width, 1200), b);
        expect(find.text('Coming up'), findsOneWidget);
        expect(find.text('Played'), findsOneWidget);
        expect(find.text('You: 4th official'), findsOneWidget);
      });
    }
  }

  testWidgets("RD3: a match for its official, Can't make it", (tester) async {
    await pump(
      tester,
      const MatchDetailsScreen(fixtureId: 'm1', isOfficial: true),
      const Size(360, 2600),
      Brightness.light,
    );
    expect(find.text('Kwame Addo (you)'), findsOneWidget);
    expect(find.text('Esi Owusu'), findsOneWidget);
    expect(find.textContaining('They open to you at'), findsOneWidget);
    // 3.3: no official sheet before the lock
    expect(find.text('Official team sheet'), findsNothing);
    await tester.tap(find.text("Can't make it"));
    await tester.pumpAndSettle();
    expect(find.text("Can't make it?"), findsOneWidget);
  });

  testWidgets('3.5c (MC1): from the lock, both sheets with player IDs', (
    tester,
  ) async {
    await pump(
      tester,
      const MatchDetailsScreen(fixtureId: 'live', isOfficial: true),
      const Size(360, 3200),
      Brightness.light,
      officials: {
        ...mine,
        'live': const MatchOfficials(
          fixtureId: 'live',
          places: {OfficialPlace.referee: me},
        ),
      },
    );
    // The home sheet open, with IDs; the away one a tap away
    expect(find.text('CB · GE26-0004'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('CB · GE26-0104'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 3.3 (MC4): the official sheet as a PDF, from the lock
    expect(find.text('Official team sheet'), findsOneWidget);
    expect(find.text('Open PDF'), findsOneWidget);

    // The FA too, once a team has saved
    await pump(
      tester,
      const MatchDetailsScreen(fixtureId: 'live', isFa: true),
      const Size(360, 3200),
      Brightness.light,
    );
    expect(find.text('Open PDF'), findsOneWidget);
  });

  testWidgets('3.3: the PDF waits for the lock for an official', (
    tester,
  ) async {
    await pump(
      tester,
      const OfficialSheetScreen(
        fixtureId: 'm1',
        viewer: SheetViewer.official,
      ),
      const Size(360, 800),
      Brightness.light,
    );
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text('Print'), findsNothing);
  });

  testWidgets("RD3 after telling the FA, and the FA's view of it", (
    tester,
  ) async {
    final told = {
      'm1': MatchOfficials(
        fixtureId: 'm1',
        places: mine['m1']!.places,
        cantMake: const {'r1': 'Family funeral'},
      ),
    };
    await pump(
      tester,
      const MatchDetailsScreen(fixtureId: 'm1', isOfficial: true),
      const Size(360, 2600),
      Brightness.dark,
      officials: told,
    );
    expect(
      find.textContaining("You told the FA you can't make it"),
      findsOneWidget,
    );
    expect(find.text("Can't make it"), findsNothing);
    await pump(
      tester,
      const MatchDetailsScreen(fixtureId: 'm1', isFa: true),
      const Size(360, 2600),
      Brightness.light,
      officials: told,
    );
    expect(find.text('Can\'t make it: "Family funeral"'), findsOneWidget);
  });

  group('3.6b players check (MC2)', () {
    final asCommissioner = {
      ...mine,
      'live': const MatchOfficials(
        fixtureId: 'live',
        places: {OfficialPlace.commissioner: me},
      ),
    };

    testWidgets('Match details: the commissioner gets Check players', (
      tester,
    ) async {
      await pump(
        tester,
        const MatchDetailsScreen(fixtureId: 'live', isOfficial: true),
        const Size(360, 3600),
        Brightness.light,
        officials: asCommissioner,
      );
      expect(
        find.text('Players check · you are the commissioner'),
        findsOneWidget,
      );
      expect(find.text('Check players'), findsOneWidget);
    });

    testWidgets('the referee of the match gets no Check players', (
      tester,
    ) async {
      await pump(
        tester,
        const MatchDetailsScreen(fixtureId: 'live', isOfficial: true),
        const Size(360, 3600),
        Brightness.light,
        officials: {
          ...mine,
          'live': const MatchOfficials(
            fixtureId: 'live',
            places: {OfficialPlace.referee: me},
          ),
        },
      );
      expect(find.text('Check players'), findsNothing);
    });

    for (final b in Brightness.values) {
      for (final width in [360.0, 1280.0]) {
        testWidgets('Check players, $width wide, ${b.name}', (tester) async {
          final checks = _FakeChecks();
          await pump(
            tester,
            const CheckPlayersScreen(fixtureId: 'live'),
            Size(width, 900),
            b,
            officials: asCommissioner,
            checks: checks,
          );
          expect(find.textContaining('0 of 12 checked'), findsOneWidget);
          expect(find.text('ruf player 1'), findsOneWidget);
          expect(find.text('No registered photo found'), findsOneWidget);

          await tester.tap(find.text('Matches'));
          await tester.pumpAndSettle();
          expect(checks.saved.single.$1, 'h1');
          expect(checks.saved.single.$2, CheckResult.match);
          // On to the next player
          expect(find.text('ruf player 2'), findsOneWidget);

          await tester.tap(find.text("Doesn't match"));
          await tester.pumpAndSettle();
          expect(find.text("ruf player 2 doesn't match"), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'Looks older');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Record'));
          await tester.pumpAndSettle();
          expect(checks.saved.last, (
            'h2',
            CheckResult.mismatch,
            'Looks older',
          ));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('another official may look; only the commissioner records', (
      tester,
    ) async {
      final checks = _FakeChecks();
      await pump(
        tester,
        const CheckPlayersScreen(fixtureId: 'live'),
        const Size(360, 900),
        Brightness.light,
        officials: {
          ...mine,
          'live': const MatchOfficials(
            fixtureId: 'live',
            places: {
              OfficialPlace.referee: me,
              OfficialPlace.commissioner: AppointedOfficial(
                uid: 'f1',
                name: 'Kwesi Arthur',
              ),
            },
          ),
        },
        checks: checks,
      );
      expect(find.textContaining('Only the commissioner'), findsOneWidget);
      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();
      expect(checks.saved, isEmpty);
    });

    testWidgets('before the lock: not yet', (tester) async {
      await pump(
        tester,
        const CheckPlayersScreen(fixtureId: 'm1'),
        const Size(360, 800),
        Brightness.light,
      );
      expect(find.text('Not yet'), findsOneWidget);
    });
  });
}
