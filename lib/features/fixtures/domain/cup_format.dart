// How a cup is played, worked out from the number of clubs (3.0c1).
// Pure Dart: no Firebase, so the tests can check every number.

/// The name of a knockout round by the clubs still in it:
/// 2 → Final, 4 → Semi-finals, 8 → Quarter-finals, 16 → Round of 16.
String roundName(int teamsLeft) => switch (teamsLeft) {
      2 => 'Final',
      4 => 'Semi-finals',
      8 => 'Quarter-finals',
      _ => 'Round of $teamsLeft',
    };

/// One knockout round: its name, the clubs that play in it and the ties.
/// [teamsLeft] is the size of the bracket at that round (0 for a first
/// round, which only some clubs play).
typedef KnockoutRound = ({String name, int teams, int ties, int teamsLeft});

/// Straight knockout. When the number of clubs isn't 4, 8, 16 or 32, some
/// clubs play a first round and the others go straight to the next round
/// (a bye), like this for 18 clubs:
///
///   bracket = 16 (the biggest of 2, 4, 8, 16, 32, 64 that fits)
///   first round: 18 − 16 = 2 ties, so 4 clubs play and 14 get a bye
///   the 2 winners + the 14 → round of 16 → quarter-finals → … → final
class KnockoutPlan {
  KnockoutPlan(this.teams) : assert(teams >= 2);

  final int teams;

  /// 2, 4, 8, 16, 32 or 64: the round every club reaches (by playing or
  /// by a bye).
  int get bracket {
    var size = 2;
    while (size * 2 <= teams) {
      size *= 2;
    }
    return size;
  }

  /// Ties in the first round; 0 when [teams] is already 4, 8, 16 …
  int get firstRoundTies => teams - bracket;

  /// Clubs that skip the first round.
  int get byes => firstRoundTies == 0 ? 0 : teams - 2 * firstRoundTies;

  List<KnockoutRound> get rounds => [
        if (firstRoundTies > 0)
          (
            name: 'First round',
            teams: 2 * firstRoundTies,
            ties: firstRoundTies,
            teamsLeft: 0,
          ),
        for (var left = bracket; left >= 2; left ~/= 2)
          (name: roundName(left), teams: left, ties: left ~/ 2, teamsLeft: left),
      ];

  /// "4 teams play a first round (2 matches); the 2 winners join the other
  /// 14 in a round of 16. Then quarter-finals, semi-finals, final."
  String get description {
    final later = [
      for (final r in rounds.skip(firstRoundTies > 0 ? 2 : 1)) r.name,
    ];
    final then = later.isEmpty
        ? ''
        : ' Then ${later.join(', ').toLowerCase()}.';
    if (teams == 2) return '2 teams: just a final.';
    if (firstRoundTies == 0) {
      return '$teams teams: ${rounds.first.name.toLowerCase()} first.$then';
    }
    final winners = firstRoundTies == 1 ? 'the winner joins' : 'the '
        '$firstRoundTies winners join';
    return '${2 * firstRoundTies} teams play a first round '
        '($firstRoundTies ${firstRoundTies == 1 ? 'match' : 'matches'}); '
        '$winners the other $byes in ${_inRound(bracket)}.$then';
  }

  static String _inRound(int left) => switch (left) {
        2 => 'the final',
        4 => 'the semi-finals',
        8 => 'the quarter-finals',
        _ => 'a round of $left',
      };

  /// The rounds the FA can fix the bracket from (C2 "The bracket is fixed
  /// from"): 0 = the start (the whole draw at once), then each later round
  /// down to the semi-finals. Until that round, each round is drawn after
  /// the one before it is played (GEDFA, 8 Nov 2026).
  List<({int teamsLeft, String label})> get bracketChoices => [
        (teamsLeft: 0, label: 'The start (whole draw at once)'),
        for (final r in rounds.skip(1))
          if (r.teamsLeft >= 4) (teamsLeft: r.teamsLeft, label: r.name),
      ];

  /// The quarter-finals when the cup has them, otherwise the start.
  int get defaultBracketFrom =>
      bracketChoices.any((c) => c.teamsLeft == 8) ? 8 : 0;
}

/// Groups, then knockout: everyone plays everyone in their group once and
/// the top 2 of each group go into the knockout. 2, 4, 8 or 16 groups (so
/// the knockout has 4, 8, 16 or 32 clubs), as few as possible with 3 to 5
/// clubs in a group (6 only when needed, e.g. 11 clubs: 6 and 5). For 18
/// clubs: 4 groups of 5, 5, 4, 4 and the top 2 go to the quarter-finals.
class GroupPlan {
  const GroupPlan._(this.sizes);

  /// Null when there are too few clubs for groups (under 6).
  static GroupPlan? forTeams(int teams) {
    if (teams < 6) return null;
    // 3 to 5 clubs a group; when that can't be done (e.g. 11), up to 6
    for (final most in const [maxGroupSize, maxGroupSize + 1]) {
      for (final groups in const [2, 4, 8, 16]) {
        if (teams ~/ groups >= minGroupSize &&
            (teams / groups).ceil() <= most) {
          return GroupPlan._([
            for (var g = 0; g < groups; g++)
              teams ~/ groups + (g < teams % groups ? 1 : 0),
          ]);
        }
      }
    }
    return null;
  }

  static const minGroupSize = 3;
  static const maxGroupSize = 5;
  static const qualifiers = 2;

  /// Clubs in each group, biggest first: [5, 5, 4, 4].
  final List<int> sizes;

  int get groups => sizes.length;
  int get knockoutTeams => groups * qualifiers;
  int get matches => sizes.fold(0, (sum, n) => sum + n * (n - 1) ~/ 2);

  /// "4 groups (5, 5, 4, 4 teams), everyone plays everyone in the group
  /// once; the top 2 go to the quarter-finals."
  String get description {
    final into = switch (knockoutTeams) {
      4 => 'the semi-finals',
      8 => 'the quarter-finals',
      _ => 'a round of $knockoutTeams',
    };
    return '$groups groups (${sizes.join(', ')} teams), everyone plays '
        'everyone in the group once; the top $qualifiers go to $into.';
  }
}

/// One round of a gala: when its matches kick off.
typedef GalaRound = ({
  String name,
  int teams,
  int byes,
  List<DateTime> kickoffs,
});

/// A gala's timetable (C2b): straight knockout, one match per tie, all at
/// one ground. Matches kick off every [gapMinutes] from the first kick-off
/// each day, and no later than [lastKickoffHour]:[lastKickoffMinute] (so
/// the last match ends before dark). A round starts only when every club
/// in it has had at least one free slot since its last match, so the next
/// round starts 2 slots after the last kick-off of the round before.
class GalaPlan {
  GalaPlan({
    required this.teams,
    required DateTime firstDay,
    required DateTime lastDay,
    required this.kickoffHour,
    required this.kickoffMinute,
    required this.gapMinutes,
  })  : firstDay = DateTime(firstDay.year, firstDay.month, firstDay.day),
        lastDay = DateTime(lastDay.year, lastDay.month, lastDay.day) {
    _plan();
  }

  /// Latest kick-off, 4:30 pm: the match ends before dark (about 6:15 pm).
  static const lastKickoffHour = 16;
  static const lastKickoffMinute = 30;

  final int teams;
  final DateTime firstDay;
  final DateTime lastDay;
  final int kickoffHour;
  final int kickoffMinute;
  final int gapMinutes;

  /// Every round with its kick-offs; a round that doesn't fit has fewer
  /// kick-offs than ties.
  late final List<GalaRound> rounds;

  /// Every match has a kick-off between the first and the last day.
  late final bool fits;

  void _plan() {
    final knockout = KnockoutPlan(teams);
    final gap = Duration(minutes: gapMinutes);
    final slots = _slots();
    var next = 0; // the first slot not used yet
    DateTime? lastOfRound;
    var allFit = true;
    final planned = <GalaRound>[];
    for (final r in knockout.rounds) {
      // One free slot for every club since its last match
      if (lastOfRound != null) {
        final earliest = lastOfRound.add(gap * 2);
        while (next < slots.length && slots[next].isBefore(earliest)) {
          next++;
        }
      }
      final kickoffs = slots.skip(next).take(r.ties).toList();
      next += kickoffs.length;
      if (kickoffs.length < r.ties) allFit = false;
      if (kickoffs.isNotEmpty) lastOfRound = kickoffs.last;
      planned.add((
        name: r.name,
        teams: r.teams,
        byes: r.teamsLeft == 0 ? knockout.byes : 0,
        kickoffs: kickoffs,
      ));
    }
    rounds = planned;
    fits = allFit;
  }

  /// Every kick-off time the days allow, in order.
  List<DateTime> _slots() {
    final slots = <DateTime>[];
    if (gapMinutes <= 0) return slots;
    for (var day = firstDay;
        !day.isAfter(lastDay);
        day = DateTime(day.year, day.month, day.day + 1)) {
      final latest = DateTime(
        day.year, day.month, day.day, lastKickoffHour, lastKickoffMinute);
      for (var t = DateTime(
            day.year, day.month, day.day, kickoffHour, kickoffMinute);
          !t.isAfter(latest);
          t = t.add(Duration(minutes: gapMinutes))) {
        slots.add(t);
      }
    }
    return slots;
  }
}
