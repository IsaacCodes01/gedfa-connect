import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_status.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';

/// Where a team sheet stands (3.1c): the lines on Home and Fixtures, Needs
/// you, and "Use last sheet".
void main() {
  final now = DateTime(2026, 11, 11, 10);

  KitChoice kit(KitSlot slot) => KitChoice(
    slot: slot,
    kit: const Kit(
      primary: Colors.red,
      shorts: Colors.white,
      socks: Colors.red,
    ),
    raw: const {},
  );

  Fixture match(
    String id,
    DateTime? kickoff, {
    FixtureStatus status = FixtureStatus.scheduled,
    AgeGroup? ageGroup,
  }) => Fixture(
    id: id,
    season: '2026-27',
    competitionId: '2026-27_division-league',
    category: ageGroup == null ? Competition.division : Competition.juvenile,
    ageGroup: ageGroup,
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
      home: kit(KitSlot.home),
      away: kit(KitSlot.away),
      homeGk: kit(KitSlot.goalkeeper),
      awayGk: kit(KitSlot.goalkeeper),
    ),
    kickoffAt: kickoff,
    venue: 'Apam Park',
    status: status,
  );

  TeamSheet sheet(String fixtureId, DateTime savedAt, {AgeGroup? ageGroup}) =>
      TeamSheet(
        fixtureId: fixtureId,
        teamId: 'ruf',
        category: ageGroup == null
            ? Competition.division
            : Competition.juvenile,
        ageGroup: ageGroup,
        starters: const ['a'],
        savedAt: savedAt,
      );

  group('the state', () {
    final inFourDays = match('m1', now.add(const Duration(days: 4)));

    test('open and nothing saved: not started', () {
      expect(
        SheetStatus.of(inFourDays, null, now).state,
        SheetState.notStarted,
      );
    });

    test('open and saved: saved, can still change', () {
      final s = SheetStatus.of(inFourDays, sheet('m1', now), now);
      expect(s.state, SheetState.saved);
      expect(s.isOpen, isTrue);
    });

    test('from 1 hour before kick-off: locked, or missed if nothing saved', () {
      final soon = match('m2', now.add(const Duration(minutes: 50)));
      expect(
        SheetStatus.of(soon, sheet('m2', now), now).state,
        SheetState.locked,
      );
      expect(SheetStatus.of(soon, null, now).state, SheetState.missed);
    });

    test('a postponed match is not open', () {
      final off = match('m3', null, status: FixtureStatus.postponed);
      expect(SheetStatus.of(off, null, now).isOpen, isFalse);
    });
  });

  group('Needs you', () {
    test('from 2 days before the sheet is due, if not started', () {
      final in3Days = match('a', now.add(const Duration(days: 3)));
      final in2Days = match('b', now.add(const Duration(days: 2)));
      expect(SheetStatus.of(in3Days, null, now).needsYou(now), isFalse);
      expect(SheetStatus.of(in2Days, null, now).needsYou(now), isTrue);
      expect(
        SheetStatus.of(in2Days, sheet('b', now), now).needsYou(now),
        isFalse,
      );
    });

    test('red on the day it is due', () {
      final today = match('c', now.add(const Duration(hours: 6)));
      final s = SheetStatus.of(today, null, now);
      expect(s.needsYou(now), isTrue);
      expect(s.isDueToday(now), isTrue);
    });
  });

  group('Use last sheet', () {
    final next = match('next', now.add(const Duration(days: 4)));

    test('the latest saved sheet of another match', () {
      final older = sheet('m1', now.subtract(const Duration(days: 14)));
      final newer = sheet('m2', now.subtract(const Duration(days: 7)));
      expect(lastSheetFor(next, [older, newer]), newer);
    });

    test("never this match's own sheet", () {
      expect(lastSheetFor(next, [sheet('next', now)]), isNull);
    });

    test('only the same competition and age group', () {
      final u15 = match(
        'j',
        now.add(const Duration(days: 4)),
        ageGroup: AgeGroup.u15,
      );
      final division = sheet('m1', now);
      final u13 = sheet('m2', now, ageGroup: AgeGroup.u13);
      final otherU15 = sheet(
        'm3',
        now.subtract(const Duration(days: 1)),
        ageGroup: AgeGroup.u15,
      );
      expect(lastSheetFor(u15, [division, u13, otherU15]), otherU15);
    });
  });
}
