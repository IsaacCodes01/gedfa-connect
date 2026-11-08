import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/features/fixtures/domain/round_robin.dart';

/// A week with no matches (e.g. Christmas): from [start] to [end], both
/// days included.
class WeekOff {
  const WeekOff(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(_day(start)) && !d.isAfter(_day(end));
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  Map<String, dynamic> toMap() => {
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
      };

  static WeekOff? fromMap(Map<String, dynamic>? map) {
    final start = (map?['start'] as Timestamp?)?.toDate();
    final end = (map?['end'] as Timestamp?)?.toDate();
    return start == null || end == null ? null : WeekOff(start, end);
  }
}

/// How the FA wants the season (mockup G1).
class SeasonSettings {
  const SeasonSettings({
    required this.firstDay,
    required this.homeAndAway,
    required this.sundayToo,
    required this.kickoffHour,
    required this.kickoffMinute,
    this.weeksOff = const [],
  });

  /// The first matchday (a Saturday is best).
  final DateTime firstDay;
  final bool homeAndAway;

  /// Matches on Saturday and Sunday (split), or Saturday only.
  final bool sundayToo;
  final int kickoffHour;
  final int kickoffMinute;
  final List<WeekOff> weeksOff;

  Map<String, dynamic> toMap() => {
        'firstDay': Timestamp.fromDate(firstDay),
        'homeAndAway': homeAndAway,
        'sundayToo': sundayToo,
        'kickoffHour': kickoffHour,
        'kickoffMinute': kickoffMinute,
        'weeksOff': [for (final w in weeksOff) w.toMap()],
      };

  static SeasonSettings? fromMap(Map<String, dynamic>? map) {
    final first = (map?['firstDay'] as Timestamp?)?.toDate();
    if (map == null || first == null) return null;
    return SeasonSettings(
      firstDay: first,
      homeAndAway: map['homeAndAway'] as bool? ?? true,
      sundayToo: map['sundayToo'] as bool? ?? true,
      kickoffHour: (map['kickoffHour'] as num?)?.toInt() ?? 15,
      kickoffMinute: (map['kickoffMinute'] as num?)?.toInt() ?? 0,
      weeksOff: [
        for (final w in map['weeksOff'] as List<dynamic>? ?? const [])
          ?WeekOff.fromMap(w as Map<String, dynamic>?),
      ],
    );
  }
}

/// A team as the plan needs it.
class PlanTeam {
  const PlanTeam({required this.id, required this.name, required this.ground});

  final String id;
  final String name;
  final String ground;
}

/// One match of the draft (not saved as a match until the FA publishes).
class DraftMatch {
  const DraftMatch({
    required this.round,
    required this.homeId,
    required this.awayId,
    required this.kickoffAt,
    required this.venue,
  });

  final int round;
  final String homeId;
  final String awayId;
  final DateTime kickoffAt;
  final String venue;

  DraftMatch copyWith({
    String? homeId,
    String? awayId,
    DateTime? kickoffAt,
    String? venue,
  }) =>
      DraftMatch(
        round: round,
        homeId: homeId ?? this.homeId,
        awayId: awayId ?? this.awayId,
        kickoffAt: kickoffAt ?? this.kickoffAt,
        venue: venue ?? this.venue,
      );

  Map<String, dynamic> toMap() => {
        'round': round,
        'homeId': homeId,
        'awayId': awayId,
        'kickoffAt': Timestamp.fromDate(kickoffAt),
        'venue': venue,
      };

  static DraftMatch? fromMap(Map<String, dynamic>? map) {
    final at = (map?['kickoffAt'] as Timestamp?)?.toDate();
    final home = map?['homeId'] as String?;
    final away = map?['awayId'] as String?;
    if (at == null || home == null || away == null) return null;
    return DraftMatch(
      round: (map!['round'] as num?)?.toInt() ?? 1,
      homeId: home,
      awayId: away,
      kickoffAt: at,
      venue: map['venue'] as String? ?? '',
    );
  }
}

/// A draft season: the matches and anything the FA should know.
class SeasonDraft {
  const SeasonDraft({required this.matches, this.warnings = const []});

  final List<DraftMatch> matches;
  final List<String> warnings;

  int get rounds => matches.isEmpty
      ? 0
      : matches.map((m) => m.round).reduce((a, b) => a > b ? a : b) -
          matches.map((m) => m.round).reduce((a, b) => a < b ? a : b) +
          1;

  DateTime? get lastDay => matches.isEmpty
      ? null
      : matches
          .map((m) => m.kickoffAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
}

/// Turns the round robin into dated matches: one matchday a weekend from
/// [SeasonSettings.firstDay], skipping weeks off. With Sunday too, the
/// first half of a matchday is on Saturday and the rest on Sunday; a team
/// whose ground is already used that day moves to the other day.
/// Matchdays are numbered from [firstRound] (after any existing ones).
SeasonDraft planSeason({
  required List<PlanTeam> teams,
  required SeasonSettings settings,
  int firstRound = 1,
}) {
  final rounds = roundRobin(teams.length, homeAndAway: settings.homeAndAway);
  final matches = <DraftMatch>[];
  final warnings = <String>[];

  var saturday = DateTime(
    settings.firstDay.year,
    settings.firstDay.month,
    settings.firstDay.day,
  );
  for (var r = 0; r < rounds.length; r++) {
    // The next weekend that isn't off
    while (settings.weeksOff.any((w) => w.covers(saturday))) {
      saturday = saturday.add(const Duration(days: 7));
    }
    final sunday = saturday.add(const Duration(days: 1));
    DateTime at(DateTime day) => DateTime(day.year, day.month, day.day,
        settings.kickoffHour, settings.kickoffMinute);

    final pairs = rounds[r];
    final half = settings.sundayToo ? (pairs.length + 1) ~/ 2 : pairs.length;
    final groundsUsed = {saturday: <String>{}, sunday: <String>{}};

    for (var i = 0; i < pairs.length; i++) {
      final home = teams[pairs[i].home];
      final away = teams[pairs[i].away];
      final ground = home.ground.trim().toLowerCase();
      var day = i < half ? saturday : sunday;
      if (ground.isNotEmpty && groundsUsed[day]!.contains(ground)) {
        final other = day == saturday ? sunday : saturday;
        if (settings.sundayToo && !groundsUsed[other]!.contains(ground)) {
          warnings.add('${home.name} share ${home.ground} with another '
              'team on matchday ${firstRound + r}: one match was moved to '
              '${other == sunday ? 'Sunday' : 'Saturday'}.');
          day = other;
        } else {
          warnings.add('${home.ground} has two matches on matchday '
              '${firstRound + r}. Change one of them.');
        }
      }
      if (ground.isNotEmpty) groundsUsed[day]!.add(ground);
      matches.add(DraftMatch(
        round: firstRound + r,
        homeId: home.id,
        awayId: away.id,
        kickoffAt: at(day),
        venue: home.ground.trim().isEmpty ? 'To be decided' : home.ground,
      ));
    }
    saturday = saturday.add(const Duration(days: 7));
  }
  if (teams.length.isOdd) {
    warnings.insert(0, 'With ${teams.length} teams, one team rests each '
        'matchday.');
  }
  return SeasonDraft(matches: matches, warnings: warnings);
}
