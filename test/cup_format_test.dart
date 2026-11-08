import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup_format.dart';

void main() {
  group('Knockout (3.0c1)', () {
    test('18 clubs: 2 first-round ties, 14 byes, then a round of 16', () {
      final plan = KnockoutPlan(18);
      expect(plan.bracket, 16);
      expect(plan.firstRoundTies, 2);
      expect(plan.byes, 14);
      expect([for (final r in plan.rounds) r.name], [
        'First round',
        'Round of 16',
        'Quarter-finals',
        'Semi-finals',
        'Final',
      ]);
      expect(plan.rounds.first.teams, 4);
      expect(
        plan.description,
        '4 teams play a first round (2 matches); the 2 winners join the '
        'other 14 in a round of 16. Then quarter-finals, semi-finals, final.',
      );
      expect([for (final c in plan.bracketChoices) c.teamsLeft], [0, 16, 8, 4]);
      expect(plan.defaultBracketFrom, 8);
    });

    test('16 clubs: no first round and no byes', () {
      final plan = KnockoutPlan(16);
      expect(plan.firstRoundTies, 0);
      expect(plan.byes, 0);
      expect(plan.rounds.first.name, 'Round of 16');
      expect([for (final c in plan.bracketChoices) c.teamsLeft], [0, 8, 4]);
    });

    test('12 clubs (the gala): 8 play a first round, 4 byes', () {
      final plan = KnockoutPlan(12);
      expect(plan.firstRoundTies, 4);
      expect(plan.byes, 4);
      expect(plan.rounds[1].name, 'Quarter-finals');
    });

    test('small and big cups', () {
      expect(KnockoutPlan(2).description, '2 teams: just a final.');
      final three = KnockoutPlan(3);
      expect(three.byes, 1);
      expect([for (final r in three.rounds) r.name], ['First round', 'Final']);
      // 4 clubs: semi-finals, then the final; nothing left to fix later
      expect([for (final c in KnockoutPlan(4).bracketChoices) c.teamsLeft], [0]);
      expect(KnockoutPlan(4).defaultBracketFrom, 0);
      expect(KnockoutPlan(64).firstRoundTies, 0);
      expect(KnockoutPlan(63).byes, 1);
    });

    test('every club is in the bracket round once', () {
      for (var n = 2; n <= 64; n++) {
        final plan = KnockoutPlan(n);
        // The first-round winners and the byes fill the bracket exactly
        expect(
          plan.firstRoundTies == 0
              ? n
              : plan.firstRoundTies + plan.byes,
          plan.bracket,
          reason: '$n',
        );
        expect(plan.rounds.last.name, 'Final');
      }
    });
  });

  group('Groups, then knockout (3.0c1)', () {
    test('11 clubs: 2 groups of 6 and 5 (never a group of 2)', () {
      expect(GroupPlan.forTeams(11)!.sizes, [6, 5]);
    });

    test('18 clubs: 4 groups of 5, 5, 4, 4; the top 2 to the quarter-finals', () {
      final plan = GroupPlan.forTeams(18)!;
      expect(plan.sizes, [5, 5, 4, 4]);
      expect(plan.knockoutTeams, 8);
      expect(plan.matches, 32);
      expect(
        plan.description,
        '4 groups (5, 5, 4, 4 teams), everyone plays everyone in the group '
        'once; the top 2 go to the quarter-finals.',
      );
    });

    test('as few groups as possible, 3 to 5 clubs (6 only when needed)', () {
      expect(GroupPlan.forTeams(5), isNull);
      expect(GroupPlan.forTeams(6)!.sizes, [3, 3]);
      expect(GroupPlan.forTeams(8)!.sizes, [4, 4]);
      expect(GroupPlan.forTeams(12)!.sizes, [3, 3, 3, 3]);
      expect(GroupPlan.forTeams(40)!.groups, 8);
      expect(GroupPlan.forTeams(64)!.knockoutTeams, 32);
      for (var n = 6; n <= 64; n++) {
        final plan = GroupPlan.forTeams(n)!;
        expect(plan.sizes.reduce((a, b) => a + b), n, reason: '$n');
        expect(plan.sizes.every((s) => s >= 3 && s <= 6), isTrue, reason: '$n');
      }
    });
  });

  group('Gala timetable (3.0c1)', () {
    GalaPlan gala(int teams, int days, {int gap = 90}) => GalaPlan(
          teams: teams,
          firstDay: DateTime(2026, 8, 29), // a Saturday
          lastDay: DateTime(2026, 8, 29 + days - 1),
          kickoffHour: 9,
          kickoffMinute: 0,
          gapMinutes: gap,
        );

    test('12 clubs over 3 days: every match fits, with a free slot to rest', () {
      final plan = gala(12, 3);
      expect(plan.fits, isTrue);
      final first = plan.rounds[0];
      expect(first.byes, 4);
      expect(first.kickoffs, [
        DateTime(2026, 8, 29, 9),
        DateTime(2026, 8, 29, 10, 30),
        DateTime(2026, 8, 29, 12),
        DateTime(2026, 8, 29, 13, 30),
      ]);
      // Quarter-finals: one slot free after 1:30 pm, so 4:30 pm, then Sunday
      expect(plan.rounds[1].kickoffs.first, DateTime(2026, 8, 29, 16, 30));
      expect(plan.rounds[1].kickoffs.last, DateTime(2026, 8, 30, 12));
      expect(plan.rounds[2].kickoffs, [
        DateTime(2026, 8, 30, 15),
        DateTime(2026, 8, 30, 16, 30),
      ]);
      expect(plan.rounds[3].kickoffs, [DateTime(2026, 8, 31, 9)]);
    });

    test("12 clubs over 2 days: the final doesn't fit", () {
      final plan = gala(12, 2);
      expect(plan.fits, isFalse);
      expect(plan.rounds.last.kickoffs, isEmpty);
    });

    test('never after 4:30 pm', () {
      final plan = gala(16, 1, gap: 60);
      // 9:00 to 4:00 pm: 8 kick-offs, all for the round of 16
      expect(plan.rounds[0].kickoffs.length, 8);
      expect(plan.rounds[0].kickoffs.last, DateTime(2026, 8, 29, 16));
      expect(plan.fits, isFalse);
    });
  });
}
