import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/notifications/presentation/widgets/note_look.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';

/// Match officials (3.5a): places, busy elsewhere, referee colours, the
/// clubs' 24 hours, and the appointment notes.
void main() {
  KitChoice kit(KitSlot slot, Color c) => KitChoice(
    slot: slot,
    kit: Kit(primary: c, shorts: Colors.white, socks: c),
    raw: const {},
  );

  final kickoff = DateTime(2026, 11, 14, 15);
  Fixture match(String id, DateTime when, {Color home = Colors.red}) => Fixture(
    id: id,
    season: '2026-27',
    competitionId: '2026-27_division-league',
    category: Competition.division,
    round: 4,
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
      home: kit(KitSlot.home, home),
      away: kit(KitSlot.away, const Color(0xFF006B3F)),
      homeGk: kit(KitSlot.goalkeeper, const Color(0xFF7B1FA2)),
      awayGk: kit(KitSlot.goalkeeper, const Color(0xFFFF9800)),
    ),
    kickoffAt: when,
    venue: 'Apam Park',
    status: FixtureStatus.scheduled,
  );

  const addo = AppointedOfficial(uid: 'r1', name: 'Kwame Addo');
  const owusu = AppointedOfficial(uid: 'r2', name: 'Esi Owusu');

  test(
    'one place each: appointing someone already in the match moves them',
    () {
      final o = const MatchOfficials(fixtureId: 'm1')
          .withPlace(OfficialPlace.referee, addo)
          .withPlace(OfficialPlace.assistant1, owusu);
      expect(o.count, 2);
      final moved = o.withPlace(OfficialPlace.assistant2, addo);
      expect(moved[OfficialPlace.referee], isNull);
      expect(moved.placeOf('r1'), OfficialPlace.assistant2);
      expect(moved.withPlace(OfficialPlace.assistant1, null).count, 1);
    },
  );

  test('saved and read back the same', () {
    final o = const MatchOfficials(
      fixtureId: 'm1',
    ).withPlace(OfficialPlace.commissioner, owusu);
    final map = o.toMap(season: '2026-27', by: 'fa1');
    expect(map['officialIds'], ['r2']);
    final back = MatchOfficials.fromMap('m1', map);
    expect(back[OfficialPlace.commissioner]?.name, 'Esi Owusu');
  });

  test('busy elsewhere the same day; gold when less than 3 hours apart', () {
    final here = match('m1', kickoff);
    final near = match('m2', kickoff.add(const Duration(hours: 2)));
    final later = match('m3', kickoff.add(const Duration(hours: 4)));
    final other = {
      'm2': const MatchOfficials(
        fixtureId: 'm2',
      ).withPlace(OfficialPlace.assistant2, addo),
      'm3': const MatchOfficials(
        fixtureId: 'm3',
      ).withPlace(OfficialPlace.fourth, owusu),
    };
    final a = busyElsewhere('r1', here, other, [here, near, later])!;
    expect(
      (a.match.id, a.place, a.near),
      ('m2', OfficialPlace.assistant2, true),
    );
    final b = busyElsewhere('r2', here, other, [here, near, later])!;
    expect(b.near, isFalse);
    expect(busyElsewhere('r9', here, other, [here, near, later]), isNull);
  });

  test('referee colours that clash with none of the four kits', () {
    // Red v green: never red or green; black is free
    final names = [
      for (final c in refereeColoursFor(match('m1', kickoff))) c.$1,
    ];
    expect(names, contains('black'));
    expect(names, isNot(contains('red')));
    expect(names, isNot(contains('green')));
  });

  test('the clubs see the officials from 24 hours before kick-off', () {
    final f = match('m1', kickoff);
    expect(
      MatchOfficials.clubsMaySee(
        f,
        kickoff.subtract(const Duration(hours: 25)),
      ),
      isFalse,
    );
    expect(
      MatchOfficials.clubsMaySee(
        f,
        kickoff.subtract(const Duration(hours: 24)),
      ),
      isTrue,
    );
  });

  test('the appointed person\'s note', () {
    final n = AppNotification(
      id: 'n',
      audience: 'person:r1',
      kind: NotificationKind.appointed,
      teamId: '',
      teamName: '',
      names: [
        'You are the referee — ${appointmentLine(match('m1', kickoff))}.',
      ],
      count: 1,
    );
    expect(n.title, 'You are the referee');
    expect(
      n.body,
      'Royal Unique FC v Asebu Stars, Sat 14 Nov, 3:00 pm, Apam Park.',
    );
    expect(n.sender, 'GEDFA');
    // Their own icons (unique, see player_suspension_test)
    expect(
      noteKindIcon(NotificationKind.appointed),
      isNot(noteKindIcon(NotificationKind.appointmentRemoved)),
    );
  });
}
