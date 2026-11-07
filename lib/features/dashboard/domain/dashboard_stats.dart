import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';

/// The numbers on the FA dashboard (2.12b): League at a glance and the
/// two charts. Worked out from lists the FA app already has live (every
/// team, every player, the season's fee totals), so they cost no extra
/// reads and change by themselves (Isaac, 7 Nov 2026).
class DashboardStats {
  const DashboardStats({
    required this.teams,
    required this.bothCompetitions,
    required this.suspended,
    required this.division,
    required this.juvenile,
    required this.approvedThisWeek,
    required this.waitingDivision,
    required this.waitingJuvenile,
    required this.juvenileByGroup,
    required this.divisionPositions,
    required this.juvenilePositions,
    required this.collected,
    required this.due,
    required this.owing,
    required this.divisionTeams,
    required this.squadsReady,
    required this.squadSize,
  });

  /// Approved teams, how many play both competitions, how many are
  /// suspended right now.
  final int teams;
  final int bothCompetitions;
  final int suspended;

  /// Approved players in each competition.
  final int division;
  final int juvenile;
  int get approved => division + juvenile;

  /// Approved in the last 7 days ("+17 this week").
  final int approvedThisWeek;

  /// Waiting: Division players for review, juvenile for screening.
  final int waitingDivision;
  final int waitingJuvenile;

  /// Approved juvenile players by age group.
  final Map<AgeGroup, int> juvenileByGroup;

  /// Approved players by main position group, per competition.
  final Map<PositionGroup, int> divisionPositions;
  final Map<PositionGroup, int> juvenilePositions;

  /// Season fees: confirmed so far, what all teams owe in total, and how
  /// many teams have not paid in full.
  final int collected;
  final int due;
  final int owing;

  /// Division teams, and how many have at least [squadSize] approved
  /// Division players (a full matchday squad). Juvenile sides are checked
  /// on screening days, so they are left out (Isaac, 7 Nov 2026).
  final int divisionTeams;
  final int squadsReady;
  final int squadSize;

  /// [feeTotals]: confirmed this season by club account (`requestUid`).
  /// [fee]: the season fee. [squadSize]: the matchday squad from League
  /// settings (16).
  factory DashboardStats.from({
    required List<Team> teams,
    required List<Player> players,
    required Map<String, int> feeTotals,
    required int fee,
    required int squadSize,
    required DateTime now,
  }) {
    final weekAgo = now.subtract(const Duration(days: 7));
    final approved = [
      for (final p in players)
        if (p.isApproved) p,
    ];
    final division = [
      for (final p in approved)
        if (!p.isJuvenile) p,
    ];
    final juvenile = [
      for (final p in approved)
        if (p.isJuvenile) p,
    ];

    Map<PositionGroup, int> byPosition(List<Player> list) => {
      for (final g in PositionGroup.values)
        g: list.where((p) => p.positionGroup == g).length,
    };

    // Approved Division players per team
    final perTeam = <String, int>{};
    for (final p in division) {
      perTeam[p.teamId] = (perTeam[p.teamId] ?? 0) + 1;
    }
    final divisionTeams = [
      for (final t in teams)
        if (t.categories.contains(Competition.division)) t,
    ];

    var collected = 0;
    var owing = 0;
    for (final t in teams) {
      final paid = feeTotals[t.requestUid] ?? 0;
      collected += paid;
      if (paid < fee) owing++;
    }

    return DashboardStats(
      teams: teams.length,
      bothCompetitions: teams.where((t) => t.hasBoth).length,
      suspended: teams.where((t) => t.isSuspended).length,
      division: division.length,
      juvenile: juvenile.length,
      approvedThisWeek: approved
          .where((p) => p.approvedAt != null && p.approvedAt!.isAfter(weekAgo))
          .length,
      waitingDivision: players
          .where((p) => !p.isJuvenile && p.status == ApprovalStatus.pending)
          .length,
      waitingJuvenile: players.where((p) => p.isWaitingForScreening).length,
      juvenileByGroup: {
        for (final g in AgeGroup.values)
          g: juvenile.where((p) => p.ageGroup == g).length,
      },
      divisionPositions: byPosition(division),
      juvenilePositions: byPosition(juvenile),
      collected: collected,
      due: teams.length * fee,
      owing: owing,
      divisionTeams: divisionTeams.length,
      squadsReady: divisionTeams
          .where((t) => (perTeam[t.id] ?? 0) >= squadSize)
          .length,
      squadSize: squadSize,
    );
  }
}
