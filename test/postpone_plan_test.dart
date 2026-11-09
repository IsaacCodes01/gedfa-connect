import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/domain/postpone_job.dart';
import 'package:gedfa_connect/features/fixtures/domain/postpone_plan.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';

KitChoice _kit(KitSlot slot) => KitChoice(
      slot: slot,
      kit: const Kit(primary: Colors.red, shorts: Colors.white, socks: Colors.red),
      raw: const {},
    );

const _side = FixtureSide(id: 'aps', name: 'Apam Stars', shortName: 'APS', colour: Colors.red);
const _other = FixtureSide(id: 'gry', name: 'Gomoa Royals', shortName: 'GRY', colour: Colors.blue);

Fixture _match(
  String id,
  DateTime? kickoff, {
  int round = 1,
  FixtureStatus status = FixtureStatus.scheduled,
}) =>
    Fixture(
      id: id,
      season: '2026-27',
      competitionId: '2026-27_division-league',
      category: Competition.division,
      round: round,
      home: _side,
      away: _other,
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
  // Sun 8 Nov 2026, noon
  final now = DateTime(2026, 11, 8, 12);

  group('PostponePlan (3.0c1c)', () {
    test('only matches not kicked off yet move; postponed without a date and cancelled stay', () {
      final plan = PostponePlan.of([
        _match('later', DateTime(2026, 12, 12, 15), round: 2),
        _match('played', DateTime(2026, 11, 7, 15)),
        _match('first', DateTime(2026, 12, 5, 15)),
        _match('waiting', null, status: FixtureStatus.postponed),
        _match('off', DateTime(2026, 12, 6, 15), status: FixtureStatus.cancelled),
      ], now)!;
      expect(plan.moving.map((f) => f.id), ['first', 'later']);
      expect(plan.first.round, 1);
      expect(plan.days, 0);
    });

    test('nothing left to move gives no plan', () {
      expect(PostponePlan.of([_match('played', DateTime(2026, 11, 7, 15))], now), isNull);
      expect(PostponePlan.of(const [], now), isNull);
    });

    test('every match moves by the same days, at the same time, weeks off kept', () {
      final plan = PostponePlan.of([
        _match('md1', DateTime(2026, 12, 5, 15)),
        _match('md2', DateTime(2026, 12, 13, 16), round: 2),
        // A week off, then matchday 3
        _match('md3', DateTime(2026, 12, 26, 15), round: 3),
      ], now)!.movedTo(DateTime(2026, 12, 19));
      expect(plan.days, 14);
      expect(plan.moving.map(plan.newKickoff), [
        DateTime(2026, 12, 19, 15),
        DateTime(2026, 12, 27, 16),
        DateTime(2027, 1, 9, 15),
      ]);
    });

    test('days and labels', () {
      expect(daysBetween(DateTime(2026, 12, 5, 23), DateTime(2026, 12, 6, 1)), 1);
      expect(daysBetween(DateTime(2026, 12, 12), DateTime(2027, 1, 9)), 28);
      expect(shiftDays(DateTime(2027, 2, 28, 15, 30), 1), DateTime(2027, 3, 1, 15, 30));
      expect(laterLabel(14), '2 weeks later');
      expect(laterLabel(7), '1 week later');
      expect(laterLabel(10), '10 days later');
      expect(laterLabel(1), '1 day later');
    });
  });

  group('PostponeJob (3.0c1d)', () {
    final plan = PostponePlan.of([
      _match('md1', DateTime(2026, 12, 5, 15)),
      _match('md2', DateTime(2026, 12, 13, 16), round: 2),
    ], now)!.movedTo(DateTime(2026, 12, 19));

    test('a job holds every match with its old and new kick-off, none moved yet', () {
      final job = PostponeJob.fromPlan(plan, name: 'Division League', reason: " The FA's congress ", byName: 'Kofi Mensah');
      expect(job.competitionId, '2026-27_division-league');
      expect(job.days, 14);
      expect(job.reason, "The FA's congress");
      expect(job.moves.map((m) => (m.id, m.from, m.to)), [
        ('md1', DateTime(2026, 12, 5, 15), DateTime(2026, 12, 19, 15)),
        ('md2', DateTime(2026, 12, 13, 16), DateTime(2026, 12, 27, 16)),
      ]);
      expect(job.movedCount, 0);
      expect(job.allMoved, isFalse);
    });

    test('as saved and read back: what is ticked off and what is left', () {
      final saved = {
        ...PostponeJob.fromPlan(plan, name: 'Division League', reason: 'Congress', byName: 'Kofi Mensah').toMap(),
        'done': ['md1', 'gone'],
      };
      final job = PostponeJob.fromMap('2026-27_division-league', saved)!;
      expect(job.category, Competition.division);
      expect(job.movedCount, 1);
      expect(job.left.map((m) => m.id), ['md2']);
      expect(job.moves.last.to, DateTime(2026, 12, 27, 16));
    });
  });
}
