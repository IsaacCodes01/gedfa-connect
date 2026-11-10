import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/domain/match_calendar.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/match_calendar_card.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';

/// The month calendar of matches (TDc).

KitChoice _kit(KitSlot slot) => KitChoice(
  slot: slot,
  kit: const Kit(primary: Colors.red, shorts: Colors.white, socks: Colors.red),
  raw: const {},
);

Fixture _match(
  String id,
  DateTime? kickoff, {
  String competitionId = '2026-27_division-league',
  FixtureStatus status = FixtureStatus.scheduled,
}) => Fixture(
  id: id,
  season: '2026-27',
  competitionId: competitionId,
  category: Competition.division,
  round: 1,
  home: const FixtureSide(
    id: 'ruf',
    name: 'Royal Unique FC',
    shortName: 'RUF',
    colour: Colors.red,
  ),
  away: const FixtureSide(
    id: 'ast',
    name: 'Asebu Stars',
    shortName: 'AST',
    colour: Colors.green,
  ),
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

void main() {
  group('monthGrid (weeks start on Monday)', () {
    test('November 2026 starts on a Sunday: 6 blanks, 30 days', () {
      final grid = monthGrid(DateTime(2026, 11));
      expect(grid.take(6), everyElement(isNull));
      expect(grid[6], 1);
      expect(grid.last, 30);
      expect(grid.length, 36);
    });
    test('June 2026 starts on a Monday: no blank', () {
      expect(monthGrid(DateTime(2026, 6)).first, 1);
    });
    test('February 2028 has 29 days', () {
      expect(monthGrid(DateTime(2028, 2)).last, 29);
    });
  });

  test('matchesByDay: this month only, no cancelled, earliest first', () {
    final byDay = matchesByDay([
      _match('late', DateTime(2026, 11, 14, 15)),
      _match('early', DateTime(2026, 11, 14, 9)),
      _match('dec', DateTime(2026, 12, 5)),
      _match('off', DateTime(2026, 11, 21), status: FixtureStatus.cancelled),
      _match('tbc', null, status: FixtureStatus.postponed),
    ], DateTime(2026, 11));
    expect(byDay.keys, [14]);
    expect(byDay[14]!.map((f) => f.id), ['early', 'late']);
  });

  test('League from the competition ID, Cup otherwise', () {
    expect(MatchKind.of(_match('a', null), const {}), MatchKind.league);
    expect(
      MatchKind.of(_match('b', null, competitionId: 'cup1'), const {}),
      MatchKind.cup,
    );
  });

  test('startMonth: the next match, or this month', () {
    expect(
      startMonth(_match('a', DateTime(2027, 1, 9)), DateTime(2026, 11, 10)),
      DateTime(2027, 1),
    );
    expect(startMonth(null, DateTime(2026, 11, 10)), DateTime(2026, 11));
  });

  testWidgets('‹ › move a month; a day with one match opens it', (
    tester,
  ) async {
    Fixture? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MatchCalendarCard(
              fixtures: [_match('m', DateTime(2026, 11, 14, 15))],
              teamId: 'ruf',
              cups: const {},
              startMonth: DateTime(2026, 11),
              now: DateTime(2026, 11, 10),
              onOpen: (f) => opened = f,
            ),
          ),
        ),
      ),
    );
    expect(find.text('November 2026'), findsOneWidget);
    await tester.tap(find.text('14'));
    expect(opened?.id, 'm');

    await tester.tap(find.byTooltip('Next month'));
    await tester.pump();
    expect(find.text('December 2026'), findsOneWidget);
    expect(find.text('No matches this month'), findsOneWidget);
    await tester.tap(find.byTooltip('Month before'));
    await tester.tap(find.byTooltip('Month before'));
    await tester.pump();
    expect(find.text('October 2026'), findsOneWidget);
  });
}
