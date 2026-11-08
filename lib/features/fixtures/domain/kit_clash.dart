import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';

/// Two colours clash when their colour difference (CIEDE2000, the
/// standard measure of how different two colours look) is below this.
/// On the app's 16 kit colours that is: yellow–gold, black–navy,
/// maroon–brown, navy–purple, red–orange and red–maroon (8 Nov 2026).
/// The one number GEDFA can tune.
const kitClashThreshold = 20.5;

/// True when [a] and [b] are too alike to tell apart on a pitch.
bool coloursClash(Color a, Color b) => colourDifference(a, b) < kitClashThreshold;

/// CIEDE2000 colour difference: 0 = the same colour, about 2 = barely
/// visible, 50+ = very different.
double colourDifference(Color a, Color b) {
  final (l1, a1, b1) = _lab(a);
  final (l2, a2, b2) = _lab(b);
  double rad(double deg) => deg * math.pi / 180;
  double deg(double r) => r * 180 / math.pi;

  final c1 = math.sqrt(a1 * a1 + b1 * b1);
  final c2 = math.sqrt(a2 * a2 + b2 * b2);
  final cBar = (c1 + c2) / 2;
  final g = 0.5 *
      (1 - math.sqrt(math.pow(cBar, 7) / (math.pow(cBar, 7) + math.pow(25, 7))));
  final a1p = (1 + g) * a1, a2p = (1 + g) * a2;
  final c1p = math.sqrt(a1p * a1p + b1 * b1);
  final c2p = math.sqrt(a2p * a2p + b2 * b2);
  double hue(double b, double a) => (deg(math.atan2(b, a)) + 360) % 360;
  final h1p = hue(b1, a1p), h2p = hue(b2, a2p);

  final dL = l2 - l1;
  final dC = c2p - c1p;
  var dh = h2p - h1p;
  if (c1p * c2p == 0) {
    dh = 0;
  } else if (dh > 180) {
    dh -= 360;
  } else if (dh < -180) {
    dh += 360;
  }
  final dH = 2 * math.sqrt(c1p * c2p) * math.sin(rad(dh / 2));

  final lBar = (l1 + l2) / 2;
  final cBarP = (c1p + c2p) / 2;
  double hBar;
  if (c1p * c2p == 0) {
    hBar = h1p + h2p;
  } else if ((h1p - h2p).abs() > 180) {
    hBar = (h1p + h2p + 360) / 2;
  } else {
    hBar = (h1p + h2p) / 2;
  }
  final t = 1 -
      0.17 * math.cos(rad(hBar - 30)) +
      0.24 * math.cos(rad(2 * hBar)) +
      0.32 * math.cos(rad(3 * hBar + 6)) -
      0.20 * math.cos(rad(4 * hBar - 63));
  final sl = 1 +
      0.015 * math.pow(lBar - 50, 2) / math.sqrt(20 + math.pow(lBar - 50, 2));
  final sc = 1 + 0.045 * cBarP;
  final sh = 1 + 0.015 * cBarP * t;
  final rt = -2 *
      math.sqrt(math.pow(cBarP, 7) / (math.pow(cBarP, 7) + math.pow(25, 7))) *
      math.sin(rad(60 * math.exp(-math.pow((hBar - 275) / 25, 2))));
  return math.sqrt(
    math.pow(dL / sl, 2) +
        math.pow(dC / sc, 2) +
        math.pow(dH / sh, 2) +
        rt * (dC / sc) * (dH / sh),
  );
}

/// A screen colour as CIE L*a*b* (how people see colour).
(double, double, double) _lab(Color c) {
  double lin(double v) =>
      v > 0.04045 ? math.pow((v + 0.055) / 1.055, 2.4).toDouble() : v / 12.92;
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  final y = r * 0.2126 + g * 0.7152 + b * 0.0722;
  final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;
  double f(double v) =>
      v > 0.008856 ? math.pow(v, 1 / 3).toDouble() : 7.787 * v + 16 / 116;
  return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)));
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

  /// Shorts and socks both too alike (a smaller problem: a warning).
  bool bottomsClash(KitLook other) {
    final s1 = shorts, s2 = other.shorts, k1 = socks, k2 = other.socks;
    if (s1 == null || s2 == null || k1 == null || k2 == null) return false;
    return coloursClash(s1, s2) && coloursClash(k1, k2);
  }
}

/// One team's kits for one competition, and its team colours (for photo
/// kits: the home kit reads as the home colours, the away kit as the away
/// ones; third and goalkeeper photo kits have no colours yet).
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

  /// Outfield shirts that clash whatever the away team wears: the FA must
  /// choose.
  final List<String> problems;

  /// Smaller things: goalkeepers, shorts and socks, kits the app can't
  /// read (photos without colours).
  final List<String> notes;

  bool get isClear => problems.isEmpty;
}

/// GEDFA's rule (8 Nov 2026): the home team keeps its home kit; the away
/// team wears the first of home, away, third that doesn't clash.
///
/// Goalkeepers follow Law 4 of the Laws of the Game: each must look
/// different from both teams' outfield players. The two goalkeepers may
/// wear the same colour. The referee's colour is not known until referees
/// are appointed (Phase 4), so it is not checked here.
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
    notes.add("$homeName's home kit is photos with no team colours: check "
        'it by eye.');
  }

  // The away team: no shirt clash and no shorts-and-socks clash first,
  // then no shirt clash.
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
    // Nothing could be checked (photo kits) or every shirt clashes
    final checkable = homeLook != null &&
        outfield.any((s) => away.look(s) != null);
    awaySlot = away.kits[KitSlot.away] != null ? KitSlot.away : KitSlot.home;
    if (checkable) {
      problems.add("Every $awayName kit clashes with $homeName's home kit. "
          'Choose the kits.');
    } else if (homeLook != null) {
      notes.add("$awayName's kits are photos with no team colours: check "
          'them by eye.');
    }
  } else if (homeLook != null && away.look(awaySlot)!.bottomsClash(homeLook)) {
    notes.add('Shorts and socks are alike; the shirts are different.');
  }
  final awayLook = away.look(awaySlot);

  // Goalkeepers: the first kit that differs from both outfield shirts
  const keepers = [KitSlot.goalkeeper, KitSlot.goalkeeper2];
  bool fits(KitLook gk) => [homeLook, awayLook]
      .every((outfield) => outfield == null || !gk.shirtClashes(outfield));

  KitSlot pickGk(TeamKits team, String name) {
    for (final slot in keepers) {
      if (team.kits[slot] == null) continue;
      final gk = team.look(slot);
      // Photos with no colours: can't tell, so keep it
      if (gk == null || fits(gk)) return slot;
    }
    notes.add("$name's goalkeeper kit looks like an outfield kit: ask the "
        'goalkeeper to bring another shirt.');
    return KitSlot.goalkeeper;
  }

  return KitPlan(
    home: KitSlot.home,
    away: awaySlot,
    homeGk: pickGk(home, homeName),
    awayGk: pickGk(away, awayName),
    problems: problems,
    notes: notes,
  );
}
