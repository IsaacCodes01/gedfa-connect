import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// Why the FA suspends a player (3.1e, mockup SP1; Isaac 11 Nov 2026).
/// Must match the rules.
enum BanReason {
  redCard('Red card'),
  violentConduct('Violent conduct'),
  yellowCards('Yellow cards'),
  other('Other');

  const BanReason(this.label);

  final String label;

  static BanReason? fromString(String? value) {
    for (final reason in values) {
      if (reason.name == value) return reason;
    }
    return null;
  }
}

/// Why the FA lifts a player's suspension early (SP2). Must match the rules.
enum BanLiftReason {
  appealWon('Appeal won'),
  givenByMistake('Given by mistake'),
  other('Other');

  const BanLiftReason(this.label);

  final String label;

  static BanLiftReason? fromString(String? value) {
    for (final reason in values) {
      if (reason.name == value) return reason;
    }
    return null;
  }
}

/// Where a suspension applies: the Division, or one juvenile age group
/// (Isaac, 11 Nov 2026: only in the competition where it was given; a
/// juvenile named for the Division serves a Division ban in Division
/// matches).
class BanCompetition {
  const BanCompetition.division()
    : category = Competition.division,
      ageGroup = null;
  const BanCompetition.juvenile(AgeGroup this.ageGroup)
    : category = Competition.juvenile;

  final Competition category;

  /// Juvenile only.
  final AgeGroup? ageGroup;

  /// What Firestore stores in `group`: 'division', 'U13', 'U15' or 'U17'.
  String get group => ageGroup?.label ?? 'division';

  /// "Division" or "U15"
  String get label => ageGroup?.label ?? 'Division';

  bool covers(Fixture f) =>
      f.category == category &&
      (category == Competition.division || f.ageGroup == ageGroup);

  @override
  bool operator ==(Object other) =>
      other is BanCompetition &&
      other.category == category &&
      other.ageGroup == ageGroup;

  @override
  int get hashCode => Object.hash(category, ageGroup);
}

/// `playerSuspensions/{id}`: the FA suspends a player for a number of
/// matches (3.1e1). Like a page in the referee's book: who, why, how many
/// matches, and which matches they are ([fixtureIds], the club's next ones
/// in that competition when the FA saved). Each of those matches carries
/// the player in its `banned` map (same batch), so team sheets can be
/// checked without reading this page (3.1e2).
class PlayerSuspension {
  const PlayerSuspension({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.season,
    required this.competition,
    required this.reason,
    required this.matches,
    required this.fixtureIds,
    this.playerCode,
    this.reasonText,
    this.note,
    this.byName,
    this.at,
    this.liftedAt,
    this.liftReason,
    this.liftNote,
  });

  /// The most matches the FA can give at once.
  static const maxMatches = 10;

  final String id;
  final String playerId;
  final String playerName;
  final String? playerCode;
  final String teamId;
  final String teamName;
  final String season;
  final BanCompetition competition;
  final BanReason reason;

  /// "Other": what the FA typed.
  final String? reasonText;
  final String? note;

  /// How many matches the player misses.
  final int matches;

  /// The matches to miss, in kick-off order. Fewer than [matches] when the
  /// calendar had fewer matches left.
  final List<String> fixtureIds;
  final String? byName;
  final DateTime? at;

  final DateTime? liftedAt;
  final BanLiftReason? liftReason;
  final String? liftNote;

  bool get isLifted => liftedAt != null;

  /// "Red card", or what the FA typed for "Other".
  String get reasonLabel =>
      reason == BanReason.other ? (reasonText ?? reason.label) : reason.label;

  /// "Kojo Brew (U15)" for a juvenile, else the name.
  String get displayName => competition.ageGroup == null
      ? playerName
      : '$playerName (${competition.label})';

  static PlayerSuspension? fromMap(String id, Map<String, dynamic> data) {
    final reason = BanReason.fromString(data['reason'] as String?);
    final category = Competition.fromString(data['category'] as String?);
    if (reason == null || category == null) return null;
    final group = AgeGroup.fromString(data['group'] as String?);
    final BanCompetition competition;
    if (category == Competition.division) {
      competition = const BanCompetition.division();
    } else if (group != null) {
      competition = BanCompetition.juvenile(group);
    } else {
      return null;
    }
    return PlayerSuspension(
      id: id,
      playerId: data['playerId'] as String? ?? '',
      playerName: data['playerName'] as String? ?? '',
      playerCode: data['playerCode'] as String?,
      teamId: data['teamId'] as String? ?? '',
      teamName: data['teamName'] as String? ?? '',
      season: data['season'] as String? ?? '',
      competition: competition,
      reason: reason,
      reasonText: data['reasonText'] as String?,
      note: data['note'] as String?,
      matches: (data['matches'] as num?)?.toInt() ?? 1,
      fixtureIds: [
        for (final f in data['fixtureIds'] as List<dynamic>? ?? const [])
          f.toString(),
      ],
      byName: data['byName'] as String?,
      at: (data['at'] as Timestamp?)?.toDate(),
      liftedAt: (data['liftedAt'] as Timestamp?)?.toDate(),
      liftReason: BanLiftReason.fromString(data['liftReason'] as String?),
      liftNote: data['liftNote'] as String?,
    );
  }
}

/// Where a suspension stands today, worked out from the calendar:
/// how many matches are left, which ones, and the match the player is
/// back for. Null from [BanStatus.of] when it is over or lifted.
class BanStatus {
  const BanStatus({
    required this.suspension,
    required this.left,
    required this.toMiss,
    required this.notInCalendar,
    this.returnMatch,
  });

  final PlayerSuspension suspension;

  /// Matches still to miss (1 or more).
  final int left;

  /// The matches still to miss that are in the calendar, in order.
  final List<Fixture> toMiss;

  /// Matches still to miss that weren't in the calendar when the FA saved.
  final int notInCalendar;

  /// The first match the player can play again, when known.
  final Fixture? returnMatch;

  /// [fixtures]: the club's (or the season's) matches.
  static BanStatus? of(
    PlayerSuspension s,
    List<Fixture> fixtures,
    DateTime now,
  ) {
    if (s.isLifted) return null;
    final byId = {for (final f in fixtures) f.id: f};
    final listed = [for (final id in s.fixtureIds) ?byId[id]];
    final played = listed.where((f) => f.isPlayed(now)).length;
    final left = s.matches - played;
    if (left <= 0) return null;
    final toMiss = [
      for (final f in listed)
        if (!f.isPlayed(now)) f,
    ]..sort(_byKickoff);
    final notInCalendar = s.matches - s.fixtureIds.length;
    return BanStatus(
      suspension: s,
      left: left,
      toMiss: toMiss,
      notInCalendar: notInCalendar,
      returnMatch: notInCalendar > 0
          ? null
          : BanPlan.returnMatch(
              fixtures,
              teamId: s.teamId,
              competition: s.competition,
              missed: s.fixtureIds.toSet(),
              after: toMiss.lastOrNull?.kickoffAt ?? now,
            ),
    );
  }

  /// "2 matches left"
  String get leftText => left == 1 ? '1 match left' : '$left matches left';

  /// "Suspended · 2 left" (the Squad card strip)
  String get shortText => 'Suspended · $left left';

  /// "Misses Sat 21 Nov v Asebu Stars and Sat 28 Nov v Gomoa Stars."
  String missesText(String teamId) =>
      BanPlan.missesText(toMiss, teamId: teamId, notInCalendar: notInCalendar);

  /// "Returns Sat 5 Dec, against Ojobi Rangers."
  String returnsText(String teamId) =>
      BanPlan.returnsText(returnMatch, teamId: teamId, pending: notInCalendar);
}

int _byKickoff(Fixture a, Fixture b) {
  final ta = a.kickoffAt, tb = b.kickoffAt;
  if (ta == null || tb == null) return ta == null ? 1 : -1;
  return ta.compareTo(tb);
}

/// A suspension moved off a match that won't be played (3.1e2).
class BanMove {
  const BanMove({
    required this.suspension,
    required this.to,
    required this.fixtureIds,
  });

  final PlayerSuspension suspension;

  /// The match it moves to; null when the calendar has none yet.
  final Fixture? to;

  /// The suspension's new list of matches to miss.
  final List<String> fixtureIds;
}

/// The calendar arithmetic of a suspension (pure, tested).
class BanPlan {
  BanPlan._();

  /// The club's next [count] matches in [competition] that are still to
  /// kick off and scheduled (not postponed or cancelled), in order.
  static List<Fixture> matchesToMiss(
    List<Fixture> fixtures, {
    required String teamId,
    required BanCompetition competition,
    required int count,
    required DateTime now,
  }) => (_upcoming(fixtures, teamId, competition, now)).take(count).toList();

  /// The first match after the missed ones: the player's return.
  static Fixture? returnMatch(
    List<Fixture> fixtures, {
    required String teamId,
    required BanCompetition competition,
    required Set<String> missed,
    required DateTime after,
  }) => _upcoming(
    fixtures,
    teamId,
    competition,
    after,
  ).where((f) => !missed.contains(f.id)).firstOrNull;

  static List<Fixture> _upcoming(
    List<Fixture> fixtures,
    String teamId,
    BanCompetition competition,
    DateTime after,
  ) => [
    for (final f in fixtures)
      if (f.hasTeam(teamId) &&
          competition.covers(f) &&
          f.isScheduled &&
          f.kickoffAt != null &&
          f.kickoffAt!.isAfter(after))
        f,
  ]..sort(_byKickoff);

  /// 3.1e2: [off] won't be played on its date (postponed, or cancelled).
  /// Each suspension in force that listed it moves to the club's next
  /// scheduled match in that competition that it doesn't list yet, so the
  /// player still misses N matches that are played (mockup SP1). With no
  /// such match the suspension keeps one more "not in the calendar yet".
  static List<BanMove> movesFor(
    Fixture off,
    List<PlayerSuspension> suspensions,
    List<Fixture> fixtures,
    DateTime now,
  ) => [
    for (final s in suspensions)
      if (!s.isLifted && s.fixtureIds.contains(off.id))
        _move(s, off, fixtures, now),
  ];

  static BanMove _move(
    PlayerSuspension s,
    Fixture off,
    List<Fixture> fixtures,
    DateTime now,
  ) {
    final to = _upcoming(
      fixtures,
      s.teamId,
      s.competition,
      now,
    ).where((f) => f.id != off.id && !s.fixtureIds.contains(f.id)).firstOrNull;
    return BanMove(
      suspension: s,
      to: to,
      fixtureIds: [
        for (final id in s.fixtureIds)
          if (id != off.id) id,
        ?to?.id,
      ],
    );
  }

  /// "Sat 21 Nov v Asebu Stars"
  static String matchText(Fixture f, String teamId) {
    final when = f.kickoffAt;
    final vs = 'v ${f.opponentOf(teamId).name}';
    return when == null ? vs : '${formatShortDate(when)} $vs';
  }

  /// "Misses Sat 21 Nov v Asebu Stars and Sat 28 Nov v Gomoa Stars."
  static String missesText(
    List<Fixture> toMiss, {
    required String teamId,
    int notInCalendar = 0,
  }) {
    final parts = [
      for (final f in toMiss) matchText(f, teamId),
      if (notInCalendar > 0)
        notInCalendar == 1
            ? '1 more match not in the calendar yet'
            : '$notInCalendar more matches not in the calendar yet',
    ];
    if (parts.isEmpty) return '';
    final joined = parts.length == 1
        ? parts.first
        : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    return 'Misses $joined.';
  }

  /// "Returns Sat 5 Dec, against Ojobi Rangers." Without a known match:
  /// "Returns after the missed matches (not in the calendar yet)."
  static String returnsText(
    Fixture? back, {
    required String teamId,
    int pending = 0,
  }) {
    final when = back?.kickoffAt;
    if (back == null || when == null) {
      return pending > 0
          ? 'Returns once the missed matches are played.'
          : 'Returns for the next match in the calendar.';
    }
    return 'Returns ${formatShortDate(when)}, against '
        '${back.opponentOf(teamId).name}.';
  }
}
