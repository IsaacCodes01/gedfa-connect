import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/domain/kit_clash.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_photos.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';

// The app's kit colours (kit_colors.dart)
const white = Color(0xFFFFFFFF);
const black = Color(0xFF111111);
const red = Color(0xFFD71920);
const maroon = Color(0xFF7A1F2B);
const yellow = Color(0xFFFFD100);
const green = Color(0xFF009A44);
const blue = Color(0xFF1E5BC6);
const navy = Color(0xFF14213D);
const skyBlue = Color(0xFF6CB4EE);
const gold = Color(0xFFC9A227);
const purple = Color(0xFF5B2A86);
const darkGreen = Color(0xFF00573F);

Kit kit(Color shirt, {Color? shorts, Color? socks, Color? second, KitPattern pattern = KitPattern.plain}) =>
    Kit(
      primary: shirt,
      secondary: second,
      pattern: pattern,
      shorts: shorts ?? shirt,
      socks: socks ?? shirt,
    );

/// A team's kits. Goalkeepers default to green ([gkColour] changes it).
TeamKits team({
  required Kit home,
  required Kit away,
  Kit? third,
  Kit? gk,
  Kit? gk2,
  TeamColours? colours,
  Color gkColour = green,
}) =>
    TeamKits(
      kits: {
        KitSlot.home: home,
        KitSlot.away: away,
        KitSlot.third: ?third,
        KitSlot.goalkeeper: gk ?? kit(gkColour),
        KitSlot.goalkeeper2: ?gk2,
      },
      colours: colours,
    );

KitPlan plan(TeamKits home, TeamKits away) => planKits(
      home: home,
      away: away,
      homeName: 'Apam Stars',
      awayName: 'Gomoa Royals',
    );

void main() {
  group('colours', () {
    test('a colour clashes with itself, and close colours clash both ways', () {
      expect(coloursClash(red, red), isTrue);
      expect(coloursClash(red, maroon), isTrue);
      expect(coloursClash(maroon, red), isTrue);
      expect(coloursClash(navy, black), isTrue);
      expect(coloursClash(yellow, gold), isTrue);
    });

    test('colours that are easy to tell apart do not clash', () {
      expect(coloursClash(red, white), isFalse);
      expect(coloursClash(blue, yellow), isFalse);
      expect(coloursClash(skyBlue, blue), isFalse);
      // Too strict before (8 Nov 2026): purple goalkeeper v blue shirts
      expect(coloursClash(purple, blue), isFalse);
      expect(coloursClash(black, darkGreen), isFalse);
    });

    test('the difference matches the standard values', () {
      expect(colourDifference(white, white), closeTo(0, 0.01));
      expect(colourDifference(yellow, gold), closeTo(13.3, 0.2));
      expect(colourDifference(red, maroon), closeTo(20.3, 0.2));
    });
  });

  group('the away team', () {
    test('keeps its home kit when nothing clashes', () {
      final p = plan(
        team(home: kit(maroon, shorts: white), away: kit(white)),
        team(home: kit(blue, shorts: white), away: kit(yellow)),
      );
      expect(p.home, KitSlot.home);
      expect(p.away, KitSlot.home);
      expect(p.isClear, isTrue);
    });

    test('changes to its away kit when its home shirt clashes (red v maroon)', () {
      final p = plan(
        team(home: kit(maroon, shorts: white), away: kit(white)),
        team(home: kit(red), away: kit(white, shorts: blue)),
      );
      expect(p.away, KitSlot.away);
      expect(p.isClear, isTrue);
    });

    test('goes on to its third kit when home and away both clash', () {
      final p = plan(
        team(home: kit(white, shorts: black), away: kit(red)),
        team(home: kit(white), away: kit(white, shorts: red), third: kit(navy, shorts: white)),
      );
      expect(p.away, KitSlot.third);
    });

    test('a problem for the FA when every kit clashes', () {
      final p = plan(
        team(home: kit(red), away: kit(white)),
        team(home: kit(maroon), away: kit(red)),
      );
      expect(p.isClear, isFalse);
      expect(p.problems.single, contains('Choose the kits'));
    });

    test('photo kits with no team colours are left to the FA\'s eyes', () {
      const photos = KitPhotos();
      final p = plan(
        team(home: kit(red), away: kit(white)),
        team(home: const Kit.fromPhotos(photos), away: const Kit.fromPhotos(photos)),
      );
      expect(p.isClear, isTrue);
      expect(p.notes.single, contains('check them by eye'));
    });

    test('photo kits are read from the team colours when there are some', () {
      const photos = KitPhotos();
      final p = plan(
        team(home: kit(red), away: kit(white)),
        team(
          home: const Kit.fromPhotos(photos),
          away: const Kit.fromPhotos(photos),
          colours: const TeamColours(
            home: ColourPair(main: maroon, second: white),
            away: ColourPair(main: blue, second: white),
          ),
        ),
      );
      expect(p.away, KitSlot.away);
    });
  });

  group('goalkeepers (Law 4)', () {
    test('a black goalkeeper kit is fine: the referee is not checked yet', () {
      final p = plan(
        team(home: kit(red), away: kit(white), gk: kit(black)),
        team(home: kit(blue), away: kit(white)),
      );
      expect(p.homeGk, KitSlot.goalkeeper);
      expect(p.notes, isEmpty);
    });

    test('both goalkeepers may wear the same colour', () {
      final p = plan(
        team(home: kit(red), away: kit(white), gk: kit(yellow)),
        team(home: kit(blue), away: kit(white), gk: kit(yellow)),
      );
      expect(p.homeGk, KitSlot.goalkeeper);
      expect(p.awayGk, KitSlot.goalkeeper);
      expect(p.isClear, isTrue);
    });

    test('a goalkeeper like the other team shirts wears the second kit', () {
      final p = plan(
        team(home: kit(red), away: kit(white), gk: kit(navy), gk2: kit(yellow)),
        team(home: kit(black), away: kit(white)),
      );
      expect(p.homeGk, KitSlot.goalkeeper2);
    });

    test('with no other kit, it is a warning, not a problem', () {
      final p = plan(
        team(home: kit(red), away: kit(white), gk: kit(navy)),
        team(home: kit(black), away: kit(white)),
      );
      expect(p.isClear, isTrue);
      expect(p.notes.single, contains('another shirt'));
    });
  });
}
