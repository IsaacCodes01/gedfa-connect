import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/dashboard/domain/team_home.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';

/// The team's Home (TDa): which matches show, "in 4 days", Needs you.

KitChoice _kit(KitSlot slot) => KitChoice(
  slot: slot,
  kit: const Kit(primary: Colors.red, shorts: Colors.white, socks: Colors.red),
  raw: const {},
);

const _us = FixtureSide(
  id: 'ruf',
  name: 'Royal Unique FC',
  shortName: 'RUF',
  colour: Colors.red,
);
const _them = FixtureSide(
  id: 'ast',
  name: 'Asebu Stars',
  shortName: 'AST',
  colour: Colors.green,
);

Fixture _match(
  String id,
  DateTime? kickoff, {
  Competition category = Competition.division,
  AgeGroup? ageGroup,
  FixtureStatus status = FixtureStatus.scheduled,
}) => Fixture(
  id: id,
  season: '2026-27',
  competitionId: '2026-27_${category.name}-league',
  category: category,
  ageGroup: ageGroup,
  round: 1,
  home: _us,
  away: _them,
  kits: MatchKits(
    home: _kit(KitSlot.home),
    away: _kit(KitSlot.away),
    homeGk: _kit(KitSlot.goalkeeper),
    awayGk: _kit(KitSlot.goalkeeper),
  ),
  kickoffAt: kickoff,
  venue: 'Apam Park',
  status: status,
);

var _n = 0;
Player _player({
  Competition category = Competition.division,
  AgeGroup? ageGroup,
  ApprovalStatus status = ApprovalStatus.approved,
  bool notEligible = false,
}) => Player(
  id: 'p${_n++}',
  teamId: 'ruf',
  teamName: 'Royal Unique FC',
  category: category,
  fullName: 'Player $_n',
  dob: DateTime(2000),
  position: Position.gk,
  jerseyNo: _n % 99 + 1,
  status: status,
  ageGroup: ageGroup,
  notEligible: notEligible,
);

List<TeamNeed> _needs({
  Set<Competition> categories = const {Competition.division},
  List<Player> players = const [],
  bool correctionAsked = false,
  bool screeningPlanned = false,
  int feeLeft = 0,
  bool feeStarted = true,
}) => teamNeeds(
  categories: categories,
  players: players,
  juvenileGroups: AgeGroup.values,
  correctionAsked: correctionAsked,
  screeningPlanned: screeningPlanned,
  feeLeft: feeLeft,
  feeStarted: feeStarted,
  matchdaySquad: 18,
  minPlayers: 7,
);

void main() {
  // Tue 10 Nov 2026, 9 pm
  final now = DateTime(2026, 11, 10, 21);

  group('countdownLabel counts calendar days', () {
    test('Saturday seen on Tuesday night is in 4 days', () {
      expect(countdownLabel(DateTime(2026, 11, 14, 15), now), 'in 4 days');
    });
    test('today, tomorrow and on now', () {
      expect(countdownLabel(DateTime(2026, 11, 10, 22), now), 'Today');
      expect(countdownLabel(DateTime(2026, 11, 11, 9), now), 'Tomorrow');
      expect(countdownLabel(DateTime(2026, 11, 10, 20), now), 'On now');
    });
  });

  group('UpcomingMatches', () {
    test('next is the first scheduled match not played, then 2 more', () {
      final all = [
        _match('played', DateTime(2026, 11, 7, 15)),
        _match('c', DateTime(2026, 11, 28, 15)),
        _match('a', DateTime(2026, 11, 14, 15)),
        _match('b', DateTime(2026, 11, 21, 15)),
        _match('d', DateTime(2026, 12, 5, 15)),
        _match('off', DateTime(2026, 11, 15), status: FixtureStatus.cancelled),
      ];
      final up = UpcomingMatches.of(all, now);
      expect(up.next?.id, 'a');
      expect(up.comingUp.map((f) => f.id), ['b', 'c']);
    });

    test('a match still on (under 2 hours) stays the next match', () {
      final up = UpcomingMatches.of([
        _match('on', DateTime(2026, 11, 10, 20)),
      ], now);
      expect(up.next?.id, 'on');
    });

    test('postponed ones come after the scheduled ones, no date last', () {
      final up = UpcomingMatches.of([
        _match('a', DateTime(2026, 11, 14, 15)),
        _match('later', null, status: FixtureStatus.postponed),
        _match('moved', DateTime(2026, 12, 1), status: FixtureStatus.postponed),
      ], now);
      expect(up.comingUp.map((f) => f.id), ['moved', 'later']);
    });

    test('nothing scheduled: no next match', () {
      expect(UpcomingMatches.of(const [], now).next, isNull);
    });
  });

  group('MatchView: the Division | Juvenile switch', () {
    final both = {Competition.division, Competition.juvenile};
    final all = [
      _match('div', DateTime(2026, 11, 14)),
      _match(
        'u15',
        DateTime(2026, 11, 11),
        category: Competition.juvenile,
        ageGroup: AgeGroup.u15,
      ),
      _match(
        'u17',
        DateTime(2026, 11, 18),
        category: Competition.juvenile,
        ageGroup: AgeGroup.u17,
      ),
    ];

    test('not chosen yet: the first competition (Division)', () {
      expect(const MatchView().filter(all, both).map((f) => f.id), ['div']);
    });

    test('Juvenile, all age groups, or one', () {
      const juvenile = MatchView(competition: Competition.juvenile);
      expect(juvenile.filter(all, both).map((f) => f.id), ['u15', 'u17']);
      const u17 = MatchView(
        competition: Competition.juvenile,
        ageGroup: AgeGroup.u17,
      );
      expect(u17.filter(all, both).map((f) => f.id), ['u17']);
    });

    test('a club only in Juvenile ignores a saved Division choice', () {
      const saved = MatchView(competition: Competition.division);
      expect(saved.shownFor({Competition.juvenile}), Competition.juvenile);
    });

    test('age groups come from the matches, or all three', () {
      expect(juvenileGroupsOf(all), [AgeGroup.u15, AgeGroup.u17]);
      expect(juvenileGroupsOf(const []), AgeGroup.values);
    });
  });

  group('teamNeeds', () {
    List<Player> approved(int n) => [for (var i = 0; i < n; i++) _player()];

    test('a full squad, nothing owed: all caught up', () {
      expect(_needs(players: approved(18)), isEmpty);
    });

    test('16 approved: can play, 2 more for a full squad (not red)', () {
      final need = _needs(players: approved(16)).single;
      expect(need.kind, TeamNeedKind.squadShort);
      expect(need.readiness!.canPlay, isTrue);
      expect(need.readiness!.missing, 2);
      expect(need.urgent, isFalse);
    });

    test("6 approved: can't play yet (red), 1 more to play", () {
      final need = _needs(players: approved(6)).single;
      expect(need.readiness!.canPlay, isFalse);
      expect(need.readiness!.missingToPlay, 1);
      expect(need.urgent, isTrue);
    });

    test('7 approved is enough to play', () {
      expect(_needs(players: approved(7)).single.readiness!.canPlay, isTrue);
    });

    test(
      'players sent back come first; not eligible children are left out',
      () {
        final needs = _needs(
          categories: {Competition.division, Competition.juvenile},
          players: [
            ...approved(18),
            for (final g in AgeGroup.values)
              for (var i = 0; i < 18; i++)
                _player(category: Competition.juvenile, ageGroup: g),
            _player(status: ApprovalStatus.rejected),
            _player(
              category: Competition.juvenile,
              ageGroup: AgeGroup.u13,
              status: ApprovalStatus.rejected,
              notEligible: true,
            ),
          ],
        );
        expect(needs.single.kind, TeamNeedKind.playersSentBack);
        expect(needs.single.count, 1);
      },
    );

    test(
      'in the mockup order: sent back, correction, screening, fee, squad',
      () {
        final needs = _needs(
          players: [
            ...approved(16),
            _player(status: ApprovalStatus.rejected),
            _player(
              category: Competition.juvenile,
              ageGroup: AgeGroup.u15,
              status: ApprovalStatus.pending,
            ),
          ],
          correctionAsked: true,
          screeningPlanned: true,
          feeLeft: 200,
        );
        expect(needs.map((n) => n.kind), [
          TeamNeedKind.playersSentBack,
          TeamNeedKind.correctionAsked,
          TeamNeedKind.screening,
          TeamNeedKind.feeOwed,
          TeamNeedKind.squadShort,
        ]);
      },
    );

    test('no screening day planned: waiting children are not a to-do', () {
      final needs = _needs(
        players: [
          ...approved(18),
          _player(
            category: Competition.juvenile,
            ageGroup: AgeGroup.u15,
            status: ApprovalStatus.pending,
          ),
        ],
      );
      expect(needs, isEmpty);
    });

    test('nothing paid yet is red; part paid is not', () {
      expect(
        _needs(
          players: approved(18),
          feeLeft: 500,
          feeStarted: false,
        ).single.urgent,
        isTrue,
      );
      expect(
        _needs(players: approved(18), feeLeft: 200).single.urgent,
        isFalse,
      );
    });

    test('juvenile: one squad row per age group short of 18', () {
      final needs = _needs(
        categories: {Competition.juvenile},
        players: [
          for (var i = 0; i < 18; i++)
            _player(category: Competition.juvenile, ageGroup: AgeGroup.u13),
          for (var i = 0; i < 9; i++)
            _player(category: Competition.juvenile, ageGroup: AgeGroup.u15),
        ],
      );
      expect(needs.map((n) => n.ageGroup), [AgeGroup.u15, AgeGroup.u17]);
      expect(needs.first.urgent, isFalse);
      expect(needs.last.urgent, isTrue);
    });
  });

  group('Squad at a glance (TDb)', () {
    test('counts the Division by status, juvenile by age group, matches', () {
      final glance = SquadGlance.of(
        [
          _player(),
          _player(),
          _player(status: ApprovalStatus.pending),
          _player(status: ApprovalStatus.rejected),
          _player(category: Competition.juvenile, ageGroup: AgeGroup.u15),
        ],
        [
          _match('played', DateTime(2026, 11, 7, 15)),
          _match('next', DateTime(2026, 11, 14, 15)),
          _match(
            'off',
            DateTime(2026, 11, 21),
            status: FixtureStatus.cancelled,
          ),
        ],
        now,
      );
      expect(glance.division, 4);
      expect(glance.divisionApproved, 2);
      expect(glance.divisionWaiting, 1);
      expect(glance.divisionSentBack, 1);
      expect(glance.juvenileByGroup[AgeGroup.u15], 1);
      expect(glance.juvenile, 1);
      expect(glance.matches, 2);
      expect(glance.played, 1);
    });

    test('Match-ready: the Division, or the weakest juvenile age group', () {
      final players = [
        for (var i = 0; i < 12; i++)
          _player(category: Competition.juvenile, ageGroup: AgeGroup.u13),
        for (var i = 0; i < 5; i++)
          _player(category: Competition.juvenile, ageGroup: AgeGroup.u17),
      ];
      final juvenileOnly = matchReadyTile(
        categories: {Competition.juvenile},
        players: players,
        juvenileGroups: const [AgeGroup.u13, AgeGroup.u17],
        matchdaySquad: 18,
        minPlayers: 7,
      );
      expect(juvenileOnly.group, AgeGroup.u17);
      expect(juvenileOnly.readiness.canPlay, isFalse);
      final both = matchReadyTile(
        categories: {Competition.division, Competition.juvenile},
        players: players,
        juvenileGroups: AgeGroup.values,
        matchdaySquad: 18,
        minPlayers: 7,
      );
      expect(both.group, isNull);
      expect(both.readiness.approved, 0);
    });
  });
}
