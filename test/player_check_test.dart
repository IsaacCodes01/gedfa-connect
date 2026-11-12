import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/player_checks/domain/player_check.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';

// 3.6b: the commissioner's players check (MC2)

final _kickoff = DateTime(2026, 11, 14, 15);

KitChoice _kit(KitSlot slot) => KitChoice(
  slot: slot,
  kit: const Kit(primary: Colors.red, shorts: Colors.white, socks: Colors.red),
  raw: const {},
);

final _match = Fixture(
  id: 'm1',
  season: '2026-27',
  competitionId: '2026-27_division-league',
  category: Competition.division,
  round: 4,
  home: const FixtureSide(
    id: 'ruf',
    name: 'Royal',
    shortName: 'RUF',
    colour: Colors.red,
  ),
  away: const FixtureSide(
    id: 'ast',
    name: 'Asebu',
    shortName: 'AST',
    colour: Colors.green,
  ),
  kits: MatchKits(
    home: _kit(KitSlot.home),
    away: _kit(KitSlot.away),
    homeGk: _kit(KitSlot.goalkeeper),
    awayGk: _kit(KitSlot.goalkeeper),
  ),
  kickoffAt: _kickoff,
  venue: 'Apam Park',
  status: FixtureStatus.scheduled,
);

const _sheet = TeamSheet(
  fixtureId: 'm1',
  teamId: 'ruf',
  category: Competition.division,
  starters: ['a', 'b'],
  bench: ['c'],
  numbers: {'a': 9, 'b': 1, 'c': 13},
  players: {
    'a': SheetPlayer(
      id: 'a',
      name: 'Nana Agyei',
      position: 'CF',
      usual: 9,
      code: 'GE26-0009',
    ),
    'b': SheetPlayer(
      id: 'b',
      name: 'Kwame Asante',
      position: 'GK',
      usual: 1,
      code: 'GE26-0001',
    ),
    'c': SheetPlayer(
      id: 'c',
      name: 'Clement Baah',
      position: 'CF',
      usual: 17,
      code: 'GE26-0017',
      ageGroup: AgeGroup.u15,
    ),
  },
);

void main() {
  test('lines in shirt order, bench marked, usual number and age group', () {
    final lines = CheckLine.forSheet(_sheet, _match);
    expect([for (final l in lines) l.number], [1, 9, 13]);
    expect(lines.last.isBench, isTrue);
    expect(lines.first.isBench, isFalse);
    expect(lines.last.detail, 'CF · GE26-0017 · U15 · usual number 17');
    expect(lines.first.detail, 'GK · GE26-0001');
    expect(lines.first.teamId, 'ruf');
  });

  test('checked count and the next one not checked (wrapping)', () {
    final lines = CheckLine.forSheet(_sheet, _match);
    const checks = MatchPlayerChecks(
      fixtureId: 'm1',
      results: {
        'b': PlayerCheck(result: CheckResult.match, teamId: 'ruf'),
        'c': PlayerCheck(result: CheckResult.absent, teamId: 'ruf'),
      },
    );
    expect(CheckLine.checkedCount(lines, checks), 2);
    expect(CheckLine.checkedCount(lines, null), 0);
    expect(CheckLine.nextUnchecked(lines, checks, 2), 1); // wraps to 'a'
    final all = MatchPlayerChecks(
      fixtureId: 'm1',
      results: {
        for (final l in lines)
          l.playerId: const PlayerCheck(
            result: CheckResult.match,
            teamId: 'ruf',
          ),
      },
    );
    expect(CheckLine.nextUnchecked(lines, all, 0), isNull);
  });

  test('the check is open from the lock until 2 hours after kick-off', () {
    bool openAt(Duration d) => CheckWindow.isOpen(_match, _kickoff.add(d));
    expect(openAt(const Duration(minutes: -61)), isFalse);
    expect(openAt(const Duration(hours: -1)), isTrue);
    expect(openAt(const Duration(hours: 2)), isTrue);
    expect(openAt(const Duration(minutes: 121)), isFalse);
  });

  test('reading a saved check; a broken entry is left out', () {
    final c = MatchPlayerChecks.fromMap('m1', {
      'results': {
        'a': {'result': 'mismatch', 'teamId': 'ruf', 'note': 'Looks older'},
        'b': {'result': 'absent', 'teamId': 'ruf'},
        'x': {'result': 'struck', 'teamId': 'ruf'},
      },
      'byName': 'Kwesi Arthur',
    });
    expect(c['a']!.result, CheckResult.mismatch);
    expect(c['a']!.note, 'Looks older');
    expect(c['b']!.note, isNull);
    expect(c['x'], isNull);
    expect(c.byName, 'Kwesi Arthur');
  });

  test('one player per write, named in changed', () {
    final w = MatchPlayerChecks.entryWrite(
      fixtureId: 'm1',
      playerId: 'a',
      teamId: 'ruf',
      result: CheckResult.mismatch,
      note: '  Looks older ',
      by: 'u1',
      byName: 'Kwesi Arthur',
    );
    final results = w['results'] as Map;
    expect(w['changed'], 'a');
    expect(results.keys, ['a']);
    expect((results['a'] as Map)['note'], 'Looks older');
    expect((results['a'] as Map)['result'], 'mismatch');
  });
}
