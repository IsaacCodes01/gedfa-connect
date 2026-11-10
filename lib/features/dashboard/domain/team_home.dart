import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// What the team's Home shows (TDa, mockup td-team-dashboard), worked out
/// from lists the team app already reads. No Flutter here, so it is easy
/// to test (test/team_home_test.dart).

/// The Division | Juvenile switch on Home (and Fixtures, TDc). It only
/// picks which MATCHES show. [ageGroup] null = all age groups.
class MatchView {
  const MatchView({this.competition, this.ageGroup});

  /// Null = not chosen yet: the club's first competition.
  final Competition? competition;
  final AgeGroup? ageGroup;

  /// The competition really shown for a club playing in [categories]
  /// (a choice the club doesn't play falls back to its first one).
  Competition shownFor(Set<Competition> categories) =>
      competition != null && categories.contains(competition)
      ? competition!
      : Competition.values.firstWhere(
          categories.contains,
          orElse: () => Competition.division,
        );

  /// The matches of [all] that this view shows.
  List<Fixture> filter(List<Fixture> all, Set<Competition> categories) {
    final shown = shownFor(categories);
    return [
      for (final f in all)
        if (f.category == shown &&
            (shown == Competition.division ||
                ageGroup == null ||
                f.ageGroup == ageGroup))
          f,
    ];
  }
}

/// The age groups a club's juvenile matches are in, youngest first. With
/// no juvenile matches yet: all three (until JA lets the club pick).
List<AgeGroup> juvenileGroupsOf(List<Fixture> all) {
  final groups = {
    for (final f in all)
      if (f.category == Competition.juvenile && f.ageGroup != null) f.ageGroup!,
  };
  return groups.isEmpty
      ? AgeGroup.values
      : AgeGroup.values.where(groups.contains).toList();
}

/// Next match and Coming up.
class UpcomingMatches {
  const UpcomingMatches({required this.next, required this.comingUp});

  /// The very next scheduled match not played yet (one still on, less
  /// than 2 hours after kick-off, counts).
  final Fixture? next;

  /// The 2 after it: scheduled ones by kick-off, then postponed ones
  /// (with a new date by date, without one last).
  final List<Fixture> comingUp;

  static UpcomingMatches of(List<Fixture> shown, DateTime now) {
    final coming = [
      for (final f in shown)
        if (f.isScheduled && f.kickoffAt != null && !f.isPlayed(now)) f,
    ]..sort((a, b) => a.kickoffAt!.compareTo(b.kickoffAt!));
    final postponed = shown.where((f) => f.isPostponed).toList()
      ..sort((a, b) {
        final ka = a.kickoffAt;
        final kb = b.kickoffAt;
        if (ka == null) return kb == null ? 0 : 1;
        if (kb == null) return -1;
        return ka.compareTo(kb);
      });
    return UpcomingMatches(
      next: coming.firstOrNull,
      comingUp: [...coming.skip(1), ...postponed].take(2).toList(),
    );
  }
}

/// The blue chip on the Next match card: "Today", "Tomorrow", "in 4 days",
/// counted in calendar days (a Saturday match seen on Tuesday night is
/// "in 4 days"), and "On now" after kick-off.
String countdownLabel(DateTime kickoff, DateTime now) {
  final k = kickoff.toLocal();
  final n = now.toLocal();
  if (!k.isAfter(n)) return 'On now';
  final days = DateTime(
    k.year,
    k.month,
    k.day,
  ).difference(DateTime(n.year, n.month, n.day)).inDays;
  return switch (days) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => 'in $days days',
  };
}

/// How ready one squad is for a match (Isaac, 10 Nov 2026): a full
/// matchday squad is `matchdaySquad` (18) approved players; with fewer but
/// at least `minPlayers` (7) the team can still play.
class SquadReadiness {
  const SquadReadiness({
    required this.approved,
    required this.full,
    required this.minimum,
  });

  final int approved;
  final int full;
  final int minimum;

  bool get isFull => approved >= full;
  bool get canPlay => approved >= minimum;

  /// Players still to add for a full squad.
  int get missing => isFull ? 0 : full - approved;

  /// Players still to add before the team can play at all.
  int get missingToPlay => canPlay ? 0 : minimum - approved;
}

/// The kinds of row in the team's "Needs you" (only what the TEAM must
/// do; what waits for the FA is TDb's "Waiting on the FA").
enum TeamNeedKind {
  playersSentBack,
  correctionAsked,
  screening,
  feeOwed,
  squadShort,
}

/// One "Needs you" row's facts; the screen turns them into words.
class TeamNeed {
  const TeamNeed({
    required this.kind,
    this.count = 0,
    this.names = const [],
    this.competition,
    this.ageGroup,
    this.readiness,
    this.urgent = false,
  });

  final TeamNeedKind kind;

  /// Players sent back, children waiting for screening.
  final int count;

  /// Up to 3 player names (sent back).
  final List<String> names;

  /// Squad short: which squad.
  final Competition? competition;
  final AgeGroup? ageGroup;
  final SquadReadiness? readiness;

  /// Red: the team can't play yet, or nothing of the fee is paid.
  final bool urgent;
}

/// Everything the team must do now, in the order of the mockup (TD1):
/// players sent back, a correction the FA asked for, children waiting for
/// a screening day, the fee, then squads short of a full matchday squad
/// (the Division, then each juvenile age group the club plays).
List<TeamNeed> teamNeeds({
  required Set<Competition> categories,
  required List<Player> players,
  required List<AgeGroup> juvenileGroups,
  required bool correctionAsked,
  required bool screeningPlanned,
  required int feeLeft,
  required bool feeStarted,
  required int matchdaySquad,
  required int minPlayers,
}) {
  // Sent back by the FA to fix (a juvenile "needs correcting" too); a
  // child found not eligible can't be fixed, so it isn't a to-do
  final sentBack = [
    for (final p in players)
      if (p.status == ApprovalStatus.rejected && !p.notEligible) p,
  ];
  final waitingScreening = players.where((p) => p.isWaitingForScreening);

  SquadReadiness readiness(Iterable<Player> squad) => SquadReadiness(
    approved: squad.where((p) => p.isApproved).length,
    full: matchdaySquad,
    minimum: minPlayers,
  );

  // Null-aware elements: a full squad adds no row
  final squads = <TeamNeed>[
    if (categories.contains(Competition.division))
      ?_squadNeed(
        readiness(players.where((p) => p.category == Competition.division)),
        Competition.division,
        null,
      ),
    if (categories.contains(Competition.juvenile))
      for (final group in juvenileGroups)
        ?_squadNeed(
          readiness(players.where((p) => p.isJuvenile && p.ageGroup == group)),
          Competition.juvenile,
          group,
        ),
  ];

  return [
    if (sentBack.isNotEmpty)
      TeamNeed(
        kind: TeamNeedKind.playersSentBack,
        count: sentBack.length,
        names: [for (final p in sentBack.take(3)) p.fullName],
        urgent: true,
      ),
    if (correctionAsked) const TeamNeed(kind: TeamNeedKind.correctionAsked),
    if (waitingScreening.isNotEmpty && screeningPlanned)
      TeamNeed(kind: TeamNeedKind.screening, count: waitingScreening.length),
    if (feeLeft > 0)
      TeamNeed(kind: TeamNeedKind.feeOwed, count: feeLeft, urgent: !feeStarted),
    ...squads,
  ];
}

TeamNeed? _squadNeed(
  SquadReadiness r,
  Competition competition,
  AgeGroup? group,
) => r.isFull
    ? null
    : TeamNeed(
        kind: TeamNeedKind.squadShort,
        competition: competition,
        ageGroup: group,
        readiness: r,
        urgent: !r.canPlay,
      );
