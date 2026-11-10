import 'dart:math' as math;

/// Where a player is on the sheet.
enum Pick { out, start, bench }

/// The numbers a sheet must respect (from League settings).
class SheetLimits {
  const SheetLimits({this.matchdaySquad = 18, this.minPlayers = 7});

  /// Starting 11 + bench, at most (`settings/league.matchdaySquad`, 18).
  final int matchdaySquad;

  /// The fewest players a team may start with (`minPlayers`, 7).
  final int minPlayers;

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

/// What the checks say about a sheet: [problems] stop the save (red),
/// [warnings] don't (gold).
class SheetCheck {
  const SheetCheck({this.problems = const [], this.warnings = const []});

  final List<String> problems;
  final List<String> warnings;

  bool get canSave => problems.isEmpty;

  /// Checks [picks] against [limits]. [goalkeepers] are the IDs of the
  /// players registered as goalkeepers; [notAvailable] maps a picked
  /// player's ID to their name (injured or unavailable in Profiles).
  static SheetCheck of(
    SheetPicks picks,
    SheetLimits limits, {
    required Set<String> goalkeepers,
    Map<String, String> notAvailable = const {},
  }) {
    final problems = <String>[];
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
    if (starting > 0 && !picks.starters.any(goalkeepers.contains)) {
      problems.add('A goalkeeper must start.');
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
    return SheetCheck(problems: problems, warnings: warnings);
  }
}
