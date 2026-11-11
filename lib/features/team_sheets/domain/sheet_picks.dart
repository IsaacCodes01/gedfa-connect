import 'dart:math' as math;

import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_roles.dart';

/// The GFA play-up limit in a juvenile match (3.1d2, mockup MS6): in a U17
/// match at most 1 U13 and 5 U15 may play up. Null = no limit (the match's
/// own group, a U15 match until GEDFA gives one, or a Division match,
/// whose juveniles have their own limits on the club's list).
int? playUpLimit(AgeGroup? match, AgeGroup? player) => match == AgeGroup.u17
    ? switch (player) {
        AgeGroup.u13 => 1,
        AgeGroup.u15 => 5,
        _ => null,
      }
    : null;

/// Where a player is on the sheet.
enum Pick { out, start, bench }

/// The numbers a sheet must respect (from League settings).
class SheetLimits {
  const SheetLimits({
    this.matchdaySquad = 18,
    this.minPlayers = 7,
    this.matchdaySubs = 5,
  });

  /// Starting 11 + bench, at most (`settings/league.matchdaySquad`, 18).
  final int matchdaySquad;

  /// The fewest players a team may start with (`minPlayers`, 7).
  final int minPlayers;

  /// Substitutes who may come on in a match (`matchdaySubs`, 5); shown on
  /// the Check step.
  final int matchdaySubs;

  static const eleven = 11;

  /// Never more than 7 on the bench (Isaac, 10 Nov 2026), and never more
  /// than the matchday squad leaves after the 11.
  int get maxBench => math.max(0, math.min(7, matchdaySquad - eleven));
}

/// What the team picked: who starts and who sits on the bench, in order.
/// Tapping "11" or "Bench" gives a new [SheetPicks], or a reason why not
/// (shown as a toast). The same limits are in firestore.rules.
class SheetPicks {
  const SheetPicks({this.starters = const [], this.bench = const []});

  final List<String> starters;
  final List<String> bench;

  int get size => starters.length + bench.length;

  Pick pickOf(String id) => starters.contains(id)
      ? Pick.start
      : bench.contains(id)
      ? Pick.bench
      : Pick.out;

  SheetPicks _without(String id) => SheetPicks(
    starters: [
      for (final s in starters)
        if (s != id) s,
    ],
    bench: [
      for (final b in bench)
        if (b != id) b,
    ],
  );

  /// "11" tapped on [id]: in the 11, or out again if already there.
  ({SheetPicks picks, String? refused}) tapStart(String id) {
    if (starters.contains(id)) return (picks: _without(id), refused: null);
    if (starters.length >= SheetLimits.eleven) {
      return (
        picks: this,
        refused: 'The starting 11 is full. Take a player out first.',
      );
    }
    final rest = _without(id);
    return (
      picks: SheetPicks(starters: [...rest.starters, id], bench: rest.bench),
      refused: null,
    );
  }

  /// "Bench" tapped on [id]: on the bench, or off it if already there.
  /// A starter may move to the bench (the 11 then needs filling again).
  ({SheetPicks picks, String? refused}) tapBench(
    String id,
    SheetLimits limits,
  ) {
    if (bench.contains(id)) return (picks: _without(id), refused: null);
    if (!starters.contains(id) && starters.length < SheetLimits.eleven) {
      return (picks: this, refused: 'The bench opens when 11 start.');
    }
    if (bench.length >= limits.maxBench) {
      return (
        picks: this,
        refused:
            'Bench full: ${limits.maxBench} at most. '
            'Take a player off the bench first.',
      );
    }
    final rest = _without(id);
    return (
      picks: SheetPicks(starters: rest.starters, bench: [...rest.bench, id]),
      refused: null,
    );
  }

  /// Only the players still in [allowed] (e.g. a player picked on a saved
  /// sheet and then sent back to pending drops off).
  SheetPicks keepOnly(Set<String> allowed) => SheetPicks(
    starters: [
      for (final s in starters)
        if (allowed.contains(s)) s,
    ],
    bench: [
      for (final b in bench)
        if (allowed.contains(b)) b,
    ],
  );
}

/// What the checks say about a sheet. [problems] stop step 1 (Players),
/// [roleProblems] stop step 2 (Roles & numbers); both stop the save (red).
/// [warnings] never do (gold).
class SheetCheck {
  const SheetCheck({
    this.problems = const [],
    this.roleProblems = const [],
    this.warnings = const [],
  });

  final List<String> problems;
  final List<String> roleProblems;
  final List<String> warnings;

  /// Step 1 is done: on to Roles & numbers.
  bool get canGoOn => problems.isEmpty;

  bool get canSave => problems.isEmpty && roleProblems.isEmpty;

  /// Checks [picks] against [limits], and step 2: [roles] (already fitted
  /// with `SheetRoles.fitTo`), the shirt [numbers] of the picked players
  /// for this match, and whether the team manager and head coach are on
  /// the sheet ([officialsReady]). [notAvailable] maps a picked player's
  /// ID to their name (injured or unavailable in Profiles).
  static SheetCheck of(
    SheetPicks picks,
    SheetLimits limits, {
    SheetRoles roles = const SheetRoles(),
    Map<String, int> numbers = const {},
    bool officialsReady = true,
    Map<String, String> notAvailable = const {},
    AgeGroup? matchGroup,
    Map<String, AgeGroup> groupOf = const {},
  }) {
    final problems = <String>[];
    final roleProblems = <String>[];
    final warnings = <String>[];
    final starting = picks.starters.length;

    if (starting < limits.minPlayers) {
      problems.add(
        starting == 0
            ? 'Pick your starting players (${limits.minPlayers} at least).'
            : 'At least ${limits.minPlayers} must start: '
                  '${limits.minPlayers - starting} more.',
      );
    }
    if (picks.bench.isNotEmpty && starting < SheetLimits.eleven) {
      problems.add(
        'The bench needs 11 starting: pick '
        '${SheetLimits.eleven - starting} more, or empty the bench.',
      );
    }
    if (picks.bench.length > limits.maxBench) {
      problems.add('Bench: ${limits.maxBench} at most.');
    }
    // Playing up (MS6): e.g. "At most 1 U13 may play up in a U17 match"
    for (final g in AgeGroup.values) {
      final limit = playUpLimit(matchGroup, g);
      if (limit == null) continue;
      final count = [
        ...picks.starters,
        ...picks.bench,
      ].where((id) => groupOf[id] == g).length;
      if (count > limit) {
        problems.add(
          'At most $limit ${g.label} may play up in a '
          '${matchGroup!.label} match: take ${count - limit} off.',
        );
      }
    }

    if (roles.captainId == null) {
      roleProblems.add('Pick a captain from the starting 11.');
    }
    if (roles.goalkeeperId == null) {
      roleProblems.add('Pick a goalkeeper from the starting 11.');
    }
    if (numbers.values.any((n) => !SheetRoles.isValidNumber(n))) {
      roleProblems.add('Shirt numbers go from 1 to 99.');
    }
    final clashes = SheetRoles.clashesIn(numbers);
    if (clashes.isNotEmpty) {
      final n = clashes.keys.first;
      final count = clashes[n]!.length;
      roleProblems.add(
        '${count == 2 ? 'Two' : '$count'} players wear $n. '
        'Give one of them another number.',
      );
    }
    if (!officialsReady) {
      roleProblems.add(
        'The team manager and head coach must be on the sheet: '
        'add them in Team profile.',
      );
    }

    if (starting >= limits.minPlayers && starting < SheetLimits.eleven) {
      warnings.add(
        '$starting starting: you can play with '
        '${limits.minPlayers}; 11 is a full team.',
      );
    }
    final unavailable = [
      for (final id in [...picks.starters, ...picks.bench]) ?notAvailable[id],
    ];
    if (unavailable.length == 1) {
      warnings.add('${unavailable.first} is marked injured or unavailable.');
    } else if (unavailable.length > 1) {
      warnings.add(
        '${unavailable.length} picked players are marked injured '
        'or unavailable.',
      );
    }
    return SheetCheck(
      problems: problems,
      roleProblems: roleProblems,
      warnings: warnings,
    );
  }
}
