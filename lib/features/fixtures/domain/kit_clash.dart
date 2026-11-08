import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/constants/kit_colors.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';

/// Pairs of the app's 16 kit colours that look too alike on a pitch.
/// A colour always clashes with itself. DRAFT for Isaac and GEDFA to check
/// (8 Nov 2026): add or remove pairs here, nowhere else.
const clashingColourPairs = [
  ('Red', 'Maroon'),
  ('Red', 'Orange'),
  ('Red', 'Pink'),
  ('Maroon', 'Brown'),
  ('Maroon', 'Purple'),
  ('Orange', 'Yellow'),
  ('Orange', 'Gold'),
  ('Yellow', 'Gold'),
  ('Gold', 'Brown'),
  ('Green', 'Dark green'),
  ('Blue', 'Navy'),
  ('Blue', 'Purple'),
  ('Navy', 'Black'),
  ('Navy', 'Purple'),
  ('Navy', 'Dark green'),
  ('Black', 'Dark green'),
  ('Black', 'Brown'),
];

/// Referees wear black unless the FA says otherwise.
const refereeColour = Color(0xFF111111);

/// True when [a] and [b] are too alike to tell apart on a pitch.
bool coloursClash(Color a, Color b) {
  if (a.toARGB32() == b.toARGB32()) return true;
  final nameA = _paletteName(a);
  final nameB = _paletteName(b);
  if (nameA != null && nameB != null) {
    return clashingColourPairs.any(
      (p) => (p.$1 == nameA && p.$2 == nameB) || (p.$1 == nameB && p.$2 == nameA),
    );
  }
  // A colour from outside the list (older kits): close enough in RGB
  double d(double x, double y) => (x - y) * 255;
  final r = d(a.r, b.r), g = d(a.g, b.g), bl = d(a.b, b.b);
  return r * r + g * g + bl * bl < 90 * 90;
}

String? _paletteName(Color c) {
  for (final k in kitColors) {
    if (k.color.toARGB32() == c.toARGB32()) return k.name;
  }
  return null;
}

/// The colours of one kit as seen on the pitch. Null parts are unknown
/// (a photo kit without team colours).
class KitLook {
  const KitLook({required this.shirt, this.shorts, this.socks});

  /// The main colour first; a second colour for stripes, hoops, halves
  /// and sashes.
  final List<Color> shirt;
  final Color? shorts;
  final Color? socks;

  /// A designed kit, or a photo kit read from the team's colours:
  /// [photoColours] is the home or away pair that kit stands for.
  static KitLook? of(Kit kit, {ColourPair? photoColours}) {
    if (kit.isPhotos) {
      if (photoColours == null) return null;
      return KitLook(shirt: [photoColours.main]);
    }
    return KitLook(
      shirt: [
        kit.primary,
        if (kit.pattern != KitPattern.plain && kit.secondary != null)
          kit.secondary!,
      ],
      shorts: kit.shorts,
      socks: kit.socks,
    );
  }

  /// Shirts clash when their main colours clash, or when both are two
  /// colours and every colour of one clashes with the other.
  bool shirtClashes(KitLook other) {
    if (coloursClash(shirt.first, other.shirt.first)) return true;
    if (shirt.length < 2 || other.shirt.length < 2) return false;
    return shirt.every((a) => other.shirt.any((b) => coloursClash(a, b)));
  }

  /// The main shirt colour against one colour (a goalkeeper against the
  /// referee's black).
  bool mainClashes(Color colour) => coloursClash(shirt.first, colour);

  /// Shorts or socks too alike (a smaller problem: shown as a warning).
  bool bottomsClash(KitLook other) {
    final s1 = shorts, s2 = other.shorts, k1 = socks, k2 = other.socks;
    if (s1 == null || s2 == null || k1 == null || k2 == null) return false;
    return coloursClash(s1, s2) && coloursClash(k1, k2);
  }
}

/// One team's kits for one competition, and its team colours (for photo
/// kits: home and third read as the home colours, away as the away ones).
class TeamKits {
  const TeamKits({required this.kits, this.colours});

  final Map<KitSlot, Kit> kits;
  final TeamColours? colours;

  KitLook? look(KitSlot slot) {
    final kit = kits[slot];
    if (kit == null) return null;
    final pair = switch (slot) {
      KitSlot.away => colours?.away,
      KitSlot.home => colours?.home,
      _ => null,
    };
    return KitLook.of(kit, photoColours: pair);
  }
}

/// What the app picked for a match, and anything the FA should look at.
class KitPlan {
  const KitPlan({
    required this.home,
    required this.away,
    required this.homeGk,
    required this.awayGk,
    this.problems = const [],
    this.notes = const [],
  });

  final KitSlot home;
  final KitSlot away;
  final KitSlot homeGk;
  final KitSlot awayGk;

  /// Clashes the app could not solve: the FA must choose.
  final List<String> problems;

  /// Things the app couldn't check (photo kits) or small warnings.
  final List<String> notes;

  bool get isClear => problems.isEmpty;
}

/// GEDFA's rule (8 Nov 2026): the home team keeps its home kit; the away
/// team wears the first of home, away, third that doesn't clash.
/// Goalkeepers differ from both teams, the referee and each other.
KitPlan planKits({
  required TeamKits home,
  required TeamKits away,
  required String homeName,
  required String awayName,
}) {
  final problems = <String>[];
  final notes = <String>[];
  final homeLook = home.look(KitSlot.home);
  if (homeLook == null) {
    notes.add("$homeName's home kit is photos: check the colours by eye.");
  }

  // The away team: no shirt clash and no shorts-and-socks clash first,
  // then no shirt clash, then the away kit with a problem.
  const outfield = [KitSlot.home, KitSlot.away, KitSlot.third];
  KitSlot? awaySlot;
  if (homeLook != null) {
    for (final strict in [true, false]) {
      for (final slot in outfield) {
        // Missing, or photos with no team colours to read: can't check
        final look = away.look(slot);
        if (look == null) continue;
        if (look.shirtClashes(homeLook)) continue;
        if (strict && look.bottomsClash(homeLook)) continue;
        awaySlot = slot;
        break;
      }
      if (awaySlot != null) break;
    }
  }
  if (awaySlot == null) {
    // Nothing could be checked (photo kits) or everything clashes
    final checkable = homeLook != null &&
        outfield.any((s) => away.kits[s] != null && away.look(s) != null);
    awaySlot = away.kits[KitSlot.away] != null ? KitSlot.away : KitSlot.home;
    if (checkable) {
      problems.add('Every $awayName kit clashes with $homeName\'s home kit. '
          'Choose the kits.');
    } else {
      notes.add("$awayName's kits are photos: check the colours by eye.");
    }
  } else if (homeLook != null &&
      away.look(awaySlot)!.bottomsClash(homeLook)) {
    notes.add('Shorts and socks are alike; the shirts are different.');
  }
  final awayLook = away.look(awaySlot);

  // Goalkeepers
  const gkSlots = [KitSlot.goalkeeper, KitSlot.goalkeeper2];
  bool gkFits(KitLook? gk, List<KitLook?> against) {
    if (gk == null) return true; // photos: can't tell
    if (gk.mainClashes(refereeColour)) return false;
    return against.every((o) => o == null || !gk.shirtClashes(o));
  }

  KitSlot pickGk(TeamKits team, List<KitLook?> against, String name) {
    for (final slot in gkSlots) {
      if (team.kits[slot] == null) continue;
      if (gkFits(team.look(slot), against)) return slot;
    }
    problems.add("$name's goalkeeper kit clashes. Choose the kits.");
    return KitSlot.goalkeeper;
  }

  final homeGk = pickGk(home, [homeLook, awayLook], homeName);
  final awayGk =
      pickGk(away, [homeLook, awayLook, home.look(homeGk)], awayName);

  return KitPlan(
    home: KitSlot.home,
    away: awaySlot,
    homeGk: homeGk,
    awayGk: awayGk,
    problems: problems,
    notes: notes,
  );
}
