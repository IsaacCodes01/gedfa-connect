import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/dashboard/domain/dashboard_stats.dart';
import 'package:gedfa_connect/features/dashboard/domain/fa_waiting.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/league/domain/league_settings.dart';
import 'package:gedfa_connect/features/payments/data/payment_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/teams/data/correction_request_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/correction_request.dart';

/// FA: everything waiting, live (2.12a). It reuses the streams behind the
/// gold tab badges, so opening Home costs no extra reads.
///
/// Loading until every stream has its first answer, so "All caught up"
/// never flashes before the numbers arrive. An error in any of them is
/// shown instead of a wrong 0.
final faWaitingProvider = Provider<AsyncValue<FaWaiting>>((ref) {
  final requests = ref.watch(allTeamRequestsProvider);
  final changes = ref.watch(allTeamChangesProvider);
  final players = ref.watch(allPlayersProvider);
  final payments = ref.watch(waitingPaymentsProvider);
  final corrections = ref.watch(allCorrectionRequestsProvider);

  final all = <AsyncValue<Object?>>[
    requests,
    changes,
    players,
    payments,
    corrections,
  ];
  for (final a in all) {
    if (a.hasError) return AsyncError(a.error!, a.stackTrace!);
  }
  if (all.any((a) => !a.hasValue)) return const AsyncLoading();

  return AsyncData(
    FaWaiting(
      newTeams: requests.value!
          .where((r) => r.status == ApprovalStatus.pending)
          .length,
      // One row per team, however many kinds it asked to change
      teamChanges: {
        for (final c in changes.value!)
          if (c.isPending) c.teamId,
      }.length,
      players: players.value!
          .where((p) => !p.isJuvenile && p.status == ApprovalStatus.pending)
          .length,
      screening: players.value!.where((p) => p.isWaitingForScreening).length,
      payments: payments.value!.length,
      correctionsBack: corrections.value!
          .where((c) => c.status == CorrectionStatus.sentBack)
          .length,
    ),
  );
});

/// FA: League at a glance and the charts (2.12b), live. Same streams as
/// the Teams and Players tabs and Season fees, so no extra reads.
final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final teams = ref.watch(allTeamsProvider);
  final players = ref.watch(allPlayersProvider);
  final totals = ref.watch(seasonTotalsProvider);
  // The matchday squad (16); the defaults until the settings arrive
  final settings =
      ref.watch(leagueSettingsProvider).value ?? const LeagueSettings();

  final all = <AsyncValue<Object?>>[teams, players, totals];
  for (final a in all) {
    if (a.hasError) return AsyncError(a.error!, a.stackTrace!);
  }
  if (all.any((a) => !a.hasValue)) return const AsyncLoading();

  return AsyncData(
    DashboardStats.from(
      teams: teams.value!,
      players: players.value!,
      feeTotals: totals.value!,
      fee: settings.fee,
      squadSize: settings.matchdaySquad,
      now: DateTime.now(),
    ),
  );
});
