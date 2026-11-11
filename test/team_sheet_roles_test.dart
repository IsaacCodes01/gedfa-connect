import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_picks.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_roles.dart';

/// Team sheet step 2, Roles & numbers (3.1b): captain, vice-captain,
/// goalkeeper and shirt numbers for one match. The same rules are in
/// firestore.rules (tests in test/rules).
void main() {
  const limits = SheetLimits();
  final eleven = [for (var i = 1; i <= 11; i++) 'p$i'];
  final picks = SheetPicks(starters: eleven, bench: const ['p12', 'p13']);
  final usual = {for (var i = 1; i <= 13; i++) 'p$i': i};

  group('fitting to the picks', () {
    test("Profiles' captain starts: they keep the armband", () {
      final r = const SheetRoles(captainId: 'p4').fitTo(picks, keepers: {});
      expect(r.captainId, 'p4');
    });

    test('a captain on the bench loses it, and gets it back in the 11', () {
      const chosen = SheetRoles(captainId: 'p4');
      final benched = picks.tapBench('p4', limits).picks;
      expect(chosen.fitTo(benched, keepers: {}).captainId, isNull);
      final back = benched.tapStart('p4').picks;
      expect(chosen.fitTo(back, keepers: {}).captainId, 'p4');
    });

    test('the vice-captain may be on the bench, but not off the sheet', () {
      expect(
        const SheetRoles(
          viceCaptainId: 'p12',
        ).fitTo(picks, keepers: {}).viceCaptainId,
        'p12',
      );
      expect(
        const SheetRoles(
          viceCaptainId: 'p20',
        ).fitTo(picks, keepers: {}).viceCaptainId,
        isNull,
      );
    });

    test('the only registered goalkeeper starting is picked for you', () {
      const chosen = SheetRoles();
      final r = chosen.fitTo(picks, keepers: {'p1', 'p12'});
      expect(r.goalkeeperId, 'p1');
      expect(r.keeperPickedFor(chosen), isTrue);
    });

    test('two goalkeepers starting: the team picks one', () {
      final r = const SheetRoles().fitTo(picks, keepers: {'p1', 'p2'});
      expect(r.goalkeeperId, isNull);
    });

    test('any starter may keep goal, even a defender', () {
      const chosen = SheetRoles(goalkeeperId: 'p5');
      final r = chosen.fitTo(picks, keepers: {'p1'});
      expect(r.goalkeeperId, 'p5');
      expect(r.keeperPickedFor(chosen), isFalse);
    });
  });

  group('armbands', () {
    test('giving the captaincy to the vice-captain clears the vice', () {
      final r = const SheetRoles(
        captainId: 'p4',
        viceCaptainId: 'p6',
      ).withCaptain('p6');
      expect(r.captainId, 'p6');
      expect(r.viceCaptainId, isNull);
    });

    test('no vice-captain is allowed', () {
      final r = const SheetRoles(viceCaptainId: 'p6').withVice(null);
      expect(r.viceCaptainId, isNull);
    });
  });

  group('shirt numbers', () {
    test('everyone wears their usual number unless changed', () {
      final n = const SheetRoles().numbersFor(picks, usual);
      expect(n.length, 13);
      expect(n['p12'], 12);
    });

    test('a changed number for this match; back to the usual removes it', () {
      final changed = const SheetRoles().withNumber('p12', 30, usual: 12);
      expect(changed.numbersFor(picks, usual)['p12'], 30);
      final reset = changed.withNumber('p12', 12, usual: 12);
      expect(reset.numbers, isEmpty);
    });

    test('a player taken off the sheet loses their changed number', () {
      final r = const SheetRoles(
        numbers: {'p20': 30},
      ).fitTo(picks, keepers: {});
      expect(r.numbers, isEmpty);
    });

    test('two players with the same number are a clash', () {
      final numbers = const SheetRoles(
        numbers: {'p13': 12},
      ).numbersFor(picks, usual);
      expect(SheetRoles.clashesIn(numbers), {
        12: ['p12', 'p13'],
      });
    });

    test('1 to 99', () {
      expect(SheetRoles.isValidNumber(1), isTrue);
      expect(SheetRoles.isValidNumber(99), isTrue);
      expect(SheetRoles.isValidNumber(0), isFalse);
      expect(SheetRoles.isValidNumber(100), isFalse);
    });
  });

  group('the check for step 2', () {
    SheetCheck check(SheetRoles roles, {bool officials = true}) =>
        SheetCheck.of(
          picks,
          limits,
          roles: roles.fitTo(picks, keepers: {'p1'}),
          numbers: roles.numbersFor(picks, usual),
          officialsReady: officials,
        );

    test('captain, goalkeeper, numbers and officials: ready to save', () {
      final c = check(const SheetRoles(captainId: 'p4'));
      expect(c.canGoOn, isTrue);
      expect(c.canSave, isTrue);
    });

    test('no captain: step 1 is fine, but it cannot be saved', () {
      final c = check(const SheetRoles());
      expect(c.canGoOn, isTrue);
      expect(c.canSave, isFalse);
      expect(c.roleProblems, contains('Pick a captain from the starting 11.'));
    });

    test('a clash stops the save', () {
      final c = check(const SheetRoles(captainId: 'p4', numbers: {'p13': 12}));
      expect(
        c.roleProblems.single,
        'Two players wear 12. '
        'Give one of them another number.',
      );
    });

    test('without the team manager and head coach it cannot be saved', () {
      final c = check(const SheetRoles(captainId: 'p4'), officials: false);
      expect(c.roleProblems.single, contains('team manager and head coach'));
    });
  });
}
