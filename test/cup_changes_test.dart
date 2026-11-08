import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup_changes.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

// What goes in a cup's history when the FA changes it (3.0c1b, C7).

CupEntry _side(String id, [Competition c = Competition.division]) =>
    CupEntry(teamId: id, category: c);

Cup _cup({
  String name = 'GEDFA Cup 2026/27',
  CupKind kind = CupKind.cup,
  CupWho who = CupWho.division,
  AgeGroup? ageGroup,
  List<CupEntry>? entries,
  CupFormat format = CupFormat.knockout,
  int legs = 2,
  LevelRule level = LevelRule.penalties,
  int bracketFrom = 8,
  bool seeded = false,
  GalaSettings? gala,
}) => Cup(
  id: 'c1',
  season: '2026-27',
  kind: kind,
  name: name,
  who: who,
  ageGroup: ageGroup,
  entries: entries ?? [for (var i = 0; i < 18; i++) _side('t$i')],
  format: format,
  legs: legs,
  level: level,
  bracketFrom: bracketFrom,
  seeded: seeded,
  stage: CupStage.notDrawn,
  gala: gala,
);

GalaSettings _gala({String ground = 'Apam Park', int gap = 90, int hour = 9}) =>
    GalaSettings(
      ground: ground,
      firstDay: DateTime(2026, 8, 29),
      lastDay: DateTime(2026, 8, 30),
      kickoffHour: hour,
      kickoffMinute: 0,
      gapMinutes: gap,
    );

String _name(CupEntry e) =>
    {'t3': 'Ojobi Stars', 't4': 'Potsin United'}[e.key.split(':').first] ??
    e.teamId;

void main() {
  test('nothing changed: no lines', () {
    expect(cupChanges(_cup(), _cup(), nameOf: _name), isEmpty);
  });

  test('one line per change, from → to', () {
    final lines = cupChanges(
      _cup(),
      _cup(
        name: 'GEDFA FA Cup',
        legs: 1,
        level: LevelRule.replay,
        bracketFrom: 0,
        seeded: true,
      ),
      nameOf: _name,
    );
    expect(lines, [
      'Name: GEDFA Cup 2026/27 → GEDFA FA Cup',
      'Each round: home and away → one match',
      'Level at the end: Penalties → Replay',
      'Bracket fixed from: quarter-finals → the start',
      'Seeding: off → on',
    ]);
  });

  test('teams left out and back in, by name', () {
    final all = [for (var i = 0; i < 18; i++) _side('t$i')];
    final without = [
      for (final e in all)
        if (e.teamId != 't3' && e.teamId != 't4') e,
    ];
    expect(
      cupChanges(
        _cup(entries: all),
        _cup(entries: without),
        nameOf: _name,
      ),
      [
        'Teams: Ojobi Stars, Potsin United left out',
        // 16 teams: no first round any more
        'Format: Knockout with a first round → Straight knockout',
      ],
    );
    expect(
      cupChanges(
        _cup(entries: without),
        _cup(entries: all),
        nameOf: _name,
      ),
      [
        'Teams: Ojobi Stars, Potsin United in',
        'Format: Straight knockout → Knockout with a first round',
      ],
    );
  });

  test('who plays changed: the number of teams, not every name', () {
    final lines = cupChanges(
      _cup(),
      _cup(
        who: CupWho.juvenile,
        ageGroup: AgeGroup.u17,
        entries: [
          for (var i = 0; i < 8; i++) _side('t$i', Competition.juvenile),
        ],
      ),
      nameOf: _name,
    );
    expect(lines.take(2), ['Who plays: Division → U17', 'Teams: 18 → 8']);
  });

  test('groups: the bracket line is left out', () {
    expect(
      cupChanges(
        _cup(),
        _cup(format: CupFormat.groups, bracketFrom: 0),
        nameOf: _name,
      ),
      ['Format: Knockout with a first round → Groups, then knockout'],
    );
  });

  test('a Gala: ground, days, kick-off and minutes', () {
    final before = _cup(
      kind: CupKind.gala,
      legs: 1,
      bracketFrom: 0,
      gala: _gala(),
    );
    final after = _cup(
      kind: CupKind.gala,
      legs: 1,
      bracketFrom: 0,
      gala: _gala(ground: 'Mumford Park', gap: 75, hour: 10),
    );
    expect(cupChanges(before, after, nameOf: _name), [
      'Ground: Apam Park → Mumford Park',
      'First kick-off: 9:00 am → 10:00 am',
      'Between kick-offs: 90 min → 75 min',
    ]);
    expect(galaDays(_gala()), 'Sat 29 Aug – Sun 30 Aug');
    expect(cupMadeLine(before), 'Gala made');
  });
}
