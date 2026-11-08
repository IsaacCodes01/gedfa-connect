import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/domain/round_robin.dart';
import 'package:gedfa_connect/features/fixtures/domain/season_plan.dart';

void main() {
  group('round robin', () {
    for (var n = 2; n <= 20; n++) {
      test('$n teams, once: everyone meets everyone once, nobody twice a round', () {
        final rounds = roundRobin(n, homeAndAway: false);
        expect(rounds.length, n.isEven ? n - 1 : n);

        final met = <String>{};
        for (final round in rounds) {
          final playing = <int>{};
          for (final p in round) {
            expect(playing.add(p.home), isTrue, reason: 'twice in a round');
            expect(playing.add(p.away), isTrue, reason: 'twice in a round');
            final a = p.home < p.away ? p.home : p.away;
            final b = p.home < p.away ? p.away : p.home;
            expect(met.add('$a-$b'), isTrue, reason: '$a and $b met twice');
          }
        }
        expect(met.length, n * (n - 1) ~/ 2);
      });

      test('$n teams, home and away: each pair once at each ground, fair', () {
        final rounds = roundRobin(n);
        expect(rounds.length, 2 * (n.isEven ? n - 1 : n));
        final ordered = <String>{};
        final home = List.filled(n, 0);
        final away = List.filled(n, 0);
        for (final round in rounds) {
          for (final p in round) {
            expect(ordered.add('${p.home}-${p.away}'), isTrue);
            home[p.home]++;
            away[p.away]++;
          }
        }
        expect(ordered.length, n * (n - 1));
        for (var t = 0; t < n; t++) {
          expect(home[t], n - 1, reason: 'team $t at home');
          expect(away[t], n - 1, reason: 'team $t away');
        }
      });
    }

    test('in one half, no team is at home far more than away', () {
      for (var n = 3; n <= 20; n++) {
        final rounds = roundRobin(n, homeAndAway: false);
        final home = List.filled(n, 0);
        for (final round in rounds) {
          for (final p in round) {
            home[p.home]++;
          }
        }
        final most = home.reduce((a, b) => a > b ? a : b);
        final least = home.reduce((a, b) => a < b ? a : b);
        expect(most - least, lessThanOrEqualTo(2), reason: '$n teams: $home');
      }
    });

    test('two teams never meet again within 2 matchdays', () {
      for (var n = 3; n <= 20; n++) {
        final lastMet = <String, int>{};
        final rounds = roundRobin(n);
        for (var r = 0; r < rounds.length; r++) {
          for (final p in rounds[r]) {
            final key = p.home < p.away ? '${p.home}-${p.away}' : '${p.away}-${p.home}';
            if (lastMet[key] case final before?) {
              expect(r - before, greaterThanOrEqualTo(2), reason: '$n teams');
            }
            lastMet[key] = r;
          }
        }
      }
    });

    test('nobody is home (or away) more than 3 matchdays in a row', () {
      for (var n = 3; n <= 20; n++) {
        final last = <int, bool>{};
        final run = <int, int>{};
        for (final round in roundRobin(n)) {
          for (final p in round) {
            for (final (team, atHome) in [(p.home, true), (p.away, false)]) {
              run[team] = last[team] == atHome ? (run[team] ?? 1) + 1 : 1;
              last[team] = atHome;
              expect(run[team], lessThanOrEqualTo(3), reason: '$n teams');
            }
          }
        }
      }
    });
  });

  group('the calendar', () {
    PlanTeam team(String id, [String? ground]) =>
        PlanTeam(id: id, name: id, ground: ground ?? '$id Park');
    final saturday = DateTime(2026, 11, 14);

    test('one matchday a weekend, at the kick-off time, on the home ground', () {
      final draft = planSeason(
        teams: [team('a'), team('b'), team('c'), team('d')],
        settings: SeasonSettings(
          firstDay: saturday,
          homeAndAway: true,
          sundayToo: false,
          kickoffHour: 15,
          kickoffMinute: 0,
        ),
      );
      expect(draft.rounds, 6);
      expect(draft.matches.length, 12);
      final second = draft.matches.where((m) => m.round == 2).first;
      expect(second.kickoffAt, DateTime(2026, 11, 21, 15));
      expect(second.venue, '${second.homeId} Park');
    });

    test('weeks off are skipped', () {
      final draft = planSeason(
        teams: [team('a'), team('b')],
        settings: SeasonSettings(
          firstDay: saturday,
          homeAndAway: true,
          sundayToo: false,
          kickoffHour: 15,
          kickoffMinute: 0,
          weeksOff: [WeekOff(DateTime(2026, 11, 20), DateTime(2026, 11, 29))],
        ),
      );
      expect(draft.matches.last.kickoffAt, DateTime(2026, 12, 5, 15));
    });

    test('two teams on one ground: one match moves to Sunday', () {
      final draft = planSeason(
        teams: [team('a', 'Apam Park'), team('b'), team('c', 'Apam Park'), team('d')],
        settings: SeasonSettings(
          firstDay: saturday,
          homeAndAway: false,
          sundayToo: true,
          kickoffHour: 15,
          kickoffMinute: 0,
        ),
      );
      // On no day does Apam Park have two matches
      final byDay = <String, int>{};
      for (final m in draft.matches.where((m) => m.venue == 'Apam Park')) {
        final key = '${m.kickoffAt.year}-${m.kickoffAt.month}-${m.kickoffAt.day}';
        byDay[key] = (byDay[key] ?? 0) + 1;
      }
      expect(byDay.values.every((n) => n == 1), isTrue);
    });

    test('an odd number of teams: one rests each matchday, and the FA is told', () {
      final draft = planSeason(
        teams: [team('a'), team('b'), team('c')],
        settings: SeasonSettings(
          firstDay: saturday,
          homeAndAway: false,
          sundayToo: false,
          kickoffHour: 15,
          kickoffMinute: 0,
        ),
      );
      expect(draft.rounds, 3);
      expect(draft.matches.length, 3);
      expect(draft.warnings.first, contains('one team rests'));
    });

    test('matchdays continue after existing ones', () {
      final draft = planSeason(
        teams: [team('a'), team('b')],
        settings: SeasonSettings(
          firstDay: saturday,
          homeAndAway: false,
          sundayToo: false,
          kickoffHour: 15,
          kickoffMinute: 0,
        ),
        firstRound: 5,
      );
      expect(draft.matches.single.round, 5);
    });
  });
}
