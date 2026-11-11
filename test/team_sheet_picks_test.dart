import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_picks.dart';

/// Team sheet picks (3.1a2): the 11 | Bench taps and the checks. The same
/// limits are in firestore.rules (tests in test/rules).
void main() {
  const limits = SheetLimits(); // 18 = 11 + 7, at least 7 starting
  final eleven = [for (var i = 1; i <= 11; i++) 'p$i'];
  SheetPicks full({List<String> bench = const []}) =>
      SheetPicks(starters: eleven, bench: bench);

  group('tapping', () {
    test(
      '11 puts a player in the starting 11, and tapping again takes them out',
      () {
        final once = const SheetPicks().tapStart('a');
        expect(once.picks.starters, ['a']);
        expect(once.picks.tapStart('a').picks.starters, isEmpty);
      },
    );

    test('a 12th starter is refused', () {
      final r = full().tapStart('p12');
      expect(r.refused, contains('starting 11 is full'));
      expect(r.picks.starters.length, 11);
    });

    test('the bench opens only when 11 start', () {
      final r = const SheetPicks(starters: ['a']).tapBench('b', limits);
      expect(r.refused, 'The bench opens when 11 start.');
    });

    test('7 on the bench at most', () {
      final seven = full(bench: [for (var i = 12; i <= 18; i++) 'p$i']);
      final r = seven.tapBench('p19', limits);
      expect(r.refused, contains('Bench full: 7'));
    });

    test('a smaller matchday squad makes a smaller bench', () {
      const small = SheetLimits(matchdaySquad: 16);
      expect(small.maxBench, 5);
      final five = full(bench: ['a', 'b', 'c', 'd', 'e']);
      expect(five.tapBench('f', small).refused, contains('5 at most'));
    });

    test('a starter can move to the bench, and back', () {
      final moved = full().tapBench('p3', limits).picks;
      expect(moved.pickOf('p3'), Pick.bench);
      expect(moved.starters.length, 10);
      final back = moved.tapStart('p3').picks;
      expect(back.pickOf('p3'), Pick.start);
      expect(back.bench, isEmpty);
    });

    test('keepOnly drops players who are no longer approved', () {
      final kept = full(bench: ['x']).keepOnly({...eleven}..remove('p1'));
      expect(kept.starters, isNot(contains('p1')));
      expect(kept.bench, isEmpty);
    });
  });

  group('checks', () {
    test('11 and a bench: step 1 is done', () {
      final c = SheetCheck.of(full(bench: ['p12']), limits);
      expect(c.canGoOn, isTrue);
      expect(c.warnings, isEmpty);
    });

    test('no goalkeeper yet: step 1 is done, the save waits for step 2', () {
      final c = SheetCheck.of(full(), limits);
      expect(c.problems, isEmpty);
      expect(
        c.roleProblems,
        contains('Pick a goalkeeper from the starting 11.'),
      );
      expect(c.canSave, isFalse);
    });

    test('fewer than 7 starting cannot be saved', () {
      final c = SheetCheck.of(
        SheetPicks(starters: eleven.take(6).toList()),
        limits,
      );
      expect(c.canGoOn, isFalse);
      expect(c.problems.first, contains('1 more'));
    });

    test('7 to 10 starting can be saved, with a warning', () {
      final c = SheetCheck.of(
        SheetPicks(starters: eleven.take(9).toList()),
        limits,
      );
      expect(c.canGoOn, isTrue);
      expect(c.warnings.first, contains('9 starting'));
    });

    test('a bench left behind with fewer than 11 starting is a problem', () {
      final picks = full(bench: ['p12']).tapStart('p11').picks;
      final c = SheetCheck.of(picks, limits);
      expect(c.problems.single, contains('bench needs 11'));
    });

    test('play-up limits (MS6): 1 U13 and 5 U15 in a U17 match only', () {
      expect(playUpLimit(AgeGroup.u17, AgeGroup.u13), 1);
      expect(playUpLimit(AgeGroup.u17, AgeGroup.u15), 5);
      expect(playUpLimit(AgeGroup.u17, AgeGroup.u17), isNull);
      expect(playUpLimit(AgeGroup.u15, AgeGroup.u13), isNull);
      expect(playUpLimit(null, AgeGroup.u13), isNull);
    });

    test('two U13 in a U17 match cannot be saved', () {
      final c = SheetCheck.of(
        full(),
        limits,
        matchGroup: AgeGroup.u17,
        groupOf: {'p2': AgeGroup.u13, 'p3': AgeGroup.u13},
      );
      expect(c.canGoOn, isFalse);
      expect(c.problems.single, contains('At most 1 U13'));
    });

    test('injured or unavailable players can be picked, with a warning', () {
      final c = SheetCheck.of(
        full(),
        limits,
        notAvailable: {'p4': 'Kofi Boateng', 'x': 'Not picked'},
      );
      expect(c.canGoOn, isTrue);
      expect(
        c.warnings.single,
        'Kofi Boateng is marked injured or unavailable.',
      );
    });
  });
}
