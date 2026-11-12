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
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/league/domain/league_settings.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/officials/data/officials_repository.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';
import 'package:gedfa_connect/features/officials/presentation/referee_home_screen.dart';
import 'package:gedfa_connect/features/officials/presentation/referee_matches_screen.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:go_router/go_router.dart';

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
  ];
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
          myNotificationsProvider.overrideWith((ref) => Stream.value([])),
          readMarkProvider.overrideWith(
            (ref) => Stream.value(const ReadMark()),
          ),
          pinnedAnnouncementProvider.overrideWithValue(null),
          myAudienceProvider.overrideWithValue('person:r1'),
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
    await tester.tap(find.text("Can't make it"));
    await tester.pumpAndSettle();
    expect(find.text("Can't make it?"), findsOneWidget);
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
}
