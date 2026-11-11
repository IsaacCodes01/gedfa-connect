import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/suspensions/data/player_suspension_repository.dart';
import 'package:gedfa_connect/features/suspensions/domain/player_suspension.dart';
import 'package:gedfa_connect/features/suspensions/presentation/suspend_player_screen.dart';
import 'package:gedfa_connect/features/suspensions/presentation/suspended_players_screen.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:go_router/go_router.dart';

/// Player suspensions (3.1e1): the matches a ban covers, what is left,
/// the return match, the club's note, and the FA's two screens (SP1, SP2).
void main() {
  final now = DateTime(2026, 11, 15, 12);

  KitChoice kit(KitSlot slot) => KitChoice(
    slot: slot,
    kit: const Kit(
      primary: Colors.red,
      shorts: Colors.white,
      socks: Colors.red,
    ),
    raw: const {},
  );

  FixtureSide side(String id, String name) => FixtureSide(
    id: id,
    name: name,
    shortName: id.toUpperCase(),
    colour: Colors.blue,
  );

  /// Royal (ruf) v [opponent], [days] after [now].
  Fixture match(
    String id,
    int days,
    String opponent, {
    bool home = true,
    FixtureStatus status = FixtureStatus.scheduled,
    AgeGroup? ageGroup,
    String team = 'ruf',
    DateTime? from,
  }) {
    final us = side(team, 'Royal Unique FC');
    final them = side(opponent.toLowerCase().replaceAll(' ', ''), opponent);
    return Fixture(
      id: id,
      season: '2026-27',
      competitionId: ageGroup == null
          ? '2026-27_division-league'
          : '2026-27_juvenile-league',
      category: ageGroup == null ? Competition.division : Competition.juvenile,
      ageGroup: ageGroup,
      round: days,
      home: home ? us : them,
      away: home ? them : us,
      kits: MatchKits(
        home: kit(KitSlot.home),
        away: kit(KitSlot.away),
        homeGk: kit(KitSlot.goalkeeper),
        awayGk: kit(KitSlot.goalkeeper),
      ),
      kickoffAt: (from ?? now).add(Duration(days: days)),
      venue: 'Apam Park',
      status: status,
    );
  }

  final fixtures = [
    match('played', -7, 'Nyanyano FC'),
    match('m6', 20, 'Ojobi Rangers', home: false),
    match('m4', 6, 'Asebu Stars', home: false),
    match('off', 9, 'Gomoa Royals', status: FixtureStatus.postponed),
    match('m5', 13, 'Gomoa Stars'),
    match('u15', 8, 'Ojobi Rangers', ageGroup: AgeGroup.u15),
    match('other', 7, 'Someone', team: 'other'),
  ];

  PlayerSuspension ban({
    int matches = 2,
    List<String> fixtureIds = const ['m4', 'm5'],
    DateTime? liftedAt,
  }) => PlayerSuspension(
    id: 'b1',
    playerId: 'p2',
    playerName: 'Kofi Boateng',
    teamId: 'ruf',
    teamName: 'Royal Unique FC',
    season: '2026-27',
    competition: const BanCompetition.division(),
    reason: BanReason.redCard,
    matches: matches,
    fixtureIds: fixtureIds,
    at: now,
    liftedAt: liftedAt,
  );

  group('BanPlan', () {
    test("the club's next scheduled matches in that competition, in order", () {
      final miss = BanPlan.matchesToMiss(
        fixtures,
        teamId: 'ruf',
        competition: const BanCompetition.division(),
        count: 2,
        now: now,
      );
      // Not the played one, the postponed one, the U15 one or another club's
      expect([for (final f in miss) f.id], ['m4', 'm5']);
      final back = BanPlan.returnMatch(
        fixtures,
        teamId: 'ruf',
        competition: const BanCompetition.division(),
        missed: {'m4', 'm5'},
        after: miss.last.kickoffAt!,
      );
      expect(back?.id, 'm6');
    });

    test('a juvenile ban counts only that age group', () {
      final miss = BanPlan.matchesToMiss(
        fixtures,
        teamId: 'ruf',
        competition: const BanCompetition.juvenile(AgeGroup.u15),
        count: 3,
        now: now,
      );
      expect([for (final f in miss) f.id], ['u15']);
    });

    test('the texts the club reads', () {
      final miss = [fixtures[2], fixtures[4]];
      expect(
        BanPlan.missesText(miss, teamId: 'ruf'),
        'Misses Sat 21 Nov v Asebu Stars and Sat 28 Nov v Gomoa Stars.',
      );
      expect(
        BanPlan.returnsText(fixtures[1], teamId: 'ruf'),
        'Returns Sat 5 Dec, against Ojobi Rangers.',
      );
      expect(
        BanPlan.missesText([fixtures[2]], teamId: 'ruf', notInCalendar: 2),
        'Misses Sat 21 Nov v Asebu Stars and 2 more matches not in the '
        'calendar yet.',
      );
    });
  });

  group('BanStatus', () {
    test('2 left before the first match, then 1, then over', () {
      final status = BanStatus.of(ban(), fixtures, now)!;
      expect(status.left, 2);
      expect(status.leftText, '2 matches left');
      expect(status.returnMatch?.id, 'm6');
      expect(status.shortText, 'Suspended · 2 left');

      final afterOne = BanStatus.of(
        ban(),
        fixtures,
        now.add(const Duration(days: 7)),
      )!;
      expect(afterOne.left, 1);
      expect([for (final f in afterOne.toMiss) f.id], ['m5']);

      expect(
        BanStatus.of(ban(), fixtures, now.add(const Duration(days: 14))),
        isNull,
      );
    });

    test('lifted: over at once', () {
      expect(BanStatus.of(ban(liftedAt: now), fixtures, now), isNull);
    });

    test(
      'matches not in the calendar yet keep it going, with no return date',
      () {
        final status = BanStatus.of(
          ban(matches: 4, fixtureIds: ['m4', 'm5', 'm6']),
          fixtures,
          now.add(const Duration(days: 30)),
        )!;
        expect(status.left, 1);
        expect(status.notInCalendar, 1);
        expect(status.returnMatch, isNull);
      },
    );

    test('a postponed match on the list is not served', () {
      final status = BanStatus.of(
        ban(fixtureIds: ['m4', 'off']),
        fixtures,
        now.add(const Duration(days: 12)),
      )!;
      expect(status.left, 1);
    });

    test('by player: the one in force', () {
      final bans = bansByPlayer([ban(), ban(liftedAt: now)], fixtures, now);
      expect(bans.keys, ['p2']);
    });
  });

  group("The club's note", () {
    AppNotification note(NotificationKind kind, List<String> names) =>
        AppNotification(
          id: 'n',
          audience: 'team:ruf',
          kind: kind,
          teamId: 'ruf',
          teamName: 'Royal Unique FC',
          names: names,
          count: names.length,
          targetId: 'p2',
        );

    test('one player: the headline and the details', () {
      final n = note(NotificationKind.playerSuspended, [
        'Kofi Boateng suspended for 2 matches — Red card. Misses Sat 21 Nov '
            'v Asebu Stars and Sat 28 Nov v Gomoa Stars. Returns Sat 5 Dec, '
            'against Ojobi Rangers.',
      ]);
      expect(n.title, 'Kofi Boateng suspended for 2 matches');
      expect(n.body, startsWith('Red card. Misses Sat 21 Nov'));
      expect(n.listsNames, isFalse);

      final lifted = note(NotificationKind.playerSuspensionLifted, [
        'Yaw Ofori — Appeal won. Yaw Ofori can be picked again.',
      ]);
      expect(lifted.title, 'Suspension lifted: Yaw Ofori');
      expect(lifted.body, 'Appeal won. Yaw Ofori can be picked again.');
    });

    test('several players: one line each', () {
      final n = note(NotificationKind.playerSuspended, ['A — x', 'B — y']);
      expect(n.title, '2 players suspended');
      expect(n.listsNames, isTrue);
    });
  });

  group('Screens', () {
    final player = Player(
      id: 'p2',
      teamId: 'ruf',
      teamName: 'Royal Unique FC',
      category: Competition.division,
      fullName: 'Kofi Boateng',
      dob: DateTime(2001, 4, 2),
      position: Position.rb,
      jerseyNo: 2,
      status: ApprovalStatus.approved,
      playerCode: 'GE26-0002',
    );
    // The screens use the real clock: the same calendar from today
    final today = DateTime.now();
    final live = [
      for (final f in fixtures)
        match(
          f.id,
          f.kickoffAt!.difference(now).inDays,
          f.opponentOf('ruf').name,
          home: f.isHome('ruf'),
          status: f.status,
          ageGroup: f.ageGroup,
          from: today,
        ),
    ];

    Future<void> pump(
      WidgetTester tester,
      Widget screen,
      Size size,
      Brightness b, {
      List<PlayerSuspension> bans = const [],
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith((ref, id) => Stream.value(player)),
            seasonFixturesProvider.overrideWith((ref) => Stream.value(live)),
            seasonSuspensionsProvider.overrideWith((ref) => Stream.value(bans)),
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
      testWidgets('SP1 on a small phone, ${b.name}', (tester) async {
        await pump(
          tester,
          const SuspendPlayerScreen(playerId: 'p2'),
          const Size(360, 1400),
          b,
        );
        expect(find.text('Suspend Kofi Boateng'), findsOneWidget);
        expect(find.text('Misses'), findsOneWidget);
        expect(find.text('Returns'), findsOneWidget);
        // Nothing is saved before a reason is picked
        final button = find.widgetWithText(FilledButton, 'Suspend for 1 match');
        expect(button, findsOneWidget);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);

        await tester.tap(find.text('Red card'));
        await tester.tap(find.byTooltip('One match more'));
        await tester.pumpAndSettle();
        expect(find.text('Misses'), findsNWidgets(2));
        final two = find.widgetWithText(FilledButton, 'Suspend for 2 matches');
        expect(tester.widget<FilledButton>(two).onPressed, isNotNull);
      });

      testWidgets('SP2 on a small phone, ${b.name}', (tester) async {
        await pump(
          tester,
          const SuspendedPlayersScreen(),
          const Size(360, 800),
          b,
          bans: [
            PlayerSuspension(
              id: 'b1',
              playerId: 'p2',
              playerName: 'Kofi Boateng',
              teamId: 'ruf',
              teamName: 'Royal Unique Football Club of Apam',
              season: '2026-27',
              competition: const BanCompetition.division(),
              reason: BanReason.violentConduct,
              matches: 2,
              fixtureIds: [
                for (final f in live)
                  if (f.id == 'm4' || f.id == 'm5') f.id,
              ],
            ),
          ],
        );
        expect(find.text('Kofi Boateng'), findsOneWidget);
        expect(find.text('Lift'), findsOneWidget);
        expect(find.textContaining('matches left'), findsOneWidget);
      });
    }

    testWidgets('laptop: both fit', (tester) async {
      await pump(
        tester,
        const SuspendPlayerScreen(playerId: 'p2'),
        const Size(1280, 900),
        Brightness.light,
      );
      await pump(
        tester,
        const SuspendedPlayersScreen(),
        const Size(1280, 900),
        Brightness.light,
      );
      expect(find.text('Nobody is suspended'), findsOneWidget);
    });
  });
}
