import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/notifications/presentation/widgets/note_look.dart';
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

  group('3.1e2: a postponed or cancelled match', () {
    test("the ban moves to the club's next match it doesn't list yet", () {
      final moves = BanPlan.movesFor(fixtures[2], [ban()], fixtures, now);
      expect(moves.single.to?.id, 'm6');
      expect(moves.single.fixtureIds, ['m5', 'm6']);
    });

    test('with no next match the list gets shorter (still owed)', () {
      final moves = BanPlan.movesFor(
        fixtures[2],
        [
          ban(matches: 3, fixtureIds: ['m4', 'm5', 'm6']),
        ],
        fixtures,
        now,
      );
      expect(moves.single.to, isNull);
      expect(moves.single.fixtureIds, ['m5', 'm6']);
      final status = BanStatus.of(
        ban(matches: 3, fixtureIds: moves.single.fixtureIds),
        fixtures,
        now,
      )!;
      expect(status.left, 3);
      expect(status.notInCalendar, 1);
    });

    test('lifted suspensions and other matches are left alone', () {
      expect(
        BanPlan.movesFor(fixtures[2], [ban(liftedAt: now)], fixtures, now),
        isEmpty,
      );
      expect(BanPlan.movesFor(fixtures[1], [ban()], fixtures, now), isEmpty);
    });
  });

  group('3.1e3: blocked in every competition until served', () {
    // Royal's juvenile matches around the Division ones (m4 day 6, m5 day 13)
    final u17Soon = match('u17a', 10, 'Gomoa Stars B', ageGroup: AgeGroup.u17);
    final u17Late = match('u17b', 25, 'Asebu Stars B', ageGroup: AgeGroup.u17);
    final u13 = match('u13', 9, 'Ojobi Rangers B', ageGroup: AgeGroup.u13);
    final all = [...fixtures, u17Soon, u17Late, u13];
    const kojo = BanPlayer(
      category: Competition.juvenile,
      ageGroup: AgeGroup.u15,
      namedForDivision: true,
    );

    test('where a player can be picked', () {
      expect(kojo.canBePickedFor(fixtures[2]), isTrue); // Division, named
      expect(kojo.canBePickedFor(u17Soon), isTrue); // playing up
      expect(kojo.canBePickedFor(u13), isFalse); // never down
      const notNamed = BanPlayer(
        category: Competition.juvenile,
        ageGroup: AgeGroup.u15,
      );
      expect(notNamed.canBePickedFor(fixtures[2]), isFalse);
      const senior = BanPlayer(category: Competition.division);
      expect(senior.canBePickedFor(u17Soon), isFalse);
    });

    test('a Division ban blocks the U15 and U17 matches until the last '
        'counted one, and only the Division ones count', () {
      final status = BanStatus.of(ban(), all, now)!;
      expect(status.blockedUntil, fixtures[4].kickoffAt); // m5, day 13
      expect(status.blocks(fixtures[5], kojo, now), isTrue); // U15 day 8
      expect(status.blocks(u17Soon, kojo, now), isTrue); // U17 day 10
      expect(status.blocks(u17Late, kojo, now), isFalse); // after the ban
      expect(status.blocks(u13, kojo, now), isFalse);
      expect(status.counts(u17Soon), isFalse);
      expect(status.left, 2);
    });

    test('the sync plan marks them, and takes marks off a lifted ban', () {
      final plan = BanSyncPlan.of(
        teamIds: {'ruf'},
        suspensions: [ban()],
        players: {'p2': kojo},
        fixtures: all,
        now: now,
      );
      expect(plan.marks.keys.toSet(), {'m4', 'm5', 'u15', 'u17a'});
      expect(plan.marks['u17a'], {
        'ruf': ['p2'],
      });

      // The marks are there; the ban is lifted: they all go
      final marked = [
        for (final f in all)
          plan.marks.containsKey(f.id)
              ? Fixture(
                  id: f.id,
                  season: f.season,
                  competitionId: f.competitionId,
                  category: f.category,
                  ageGroup: f.ageGroup,
                  round: f.round,
                  home: f.home,
                  away: f.away,
                  kits: f.kits,
                  kickoffAt: f.kickoffAt,
                  venue: f.venue,
                  status: f.status,
                  banned: plan.marks[f.id]!,
                )
              : f,
      ];
      final again = BanSyncPlan.of(
        teamIds: {'ruf'},
        suspensions: [ban()],
        players: {'p2': kojo},
        fixtures: marked,
        now: now,
      );
      expect(again.isEmpty, isTrue);
      final lifted = BanSyncPlan.of(
        teamIds: {'ruf'},
        suspensions: [ban(liftedAt: now)],
        players: {'p2': kojo},
        fixtures: marked,
        now: now,
      );
      expect(lifted.marks.length, 4);
      expect(lifted.marks.values.every((t) => t['ruf']!.isEmpty), isTrue);
    });

    test('a ban short of matches takes new ones in its competition', () {
      final plan = BanSyncPlan.of(
        teamIds: {'ruf'},
        suspensions: [
          ban(matches: 3, fixtureIds: ['m4']),
        ],
        players: const {},
        fixtures: all,
        now: now,
      );
      expect(plan.lists['b1'], ['m4', 'm5', 'm6']);
    });
  });

  test('every kind of note has its own icon (Isaac, 11 Nov 2026)', () {
    final icons = [for (final k in NotificationKind.values) noteKindIcon(k)];
    expect(icons.toSet().length, NotificationKind.values.length);
    expect(icons, isNot(contains(announcementIcon)));
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
