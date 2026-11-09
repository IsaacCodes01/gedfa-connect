import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/domain/team_change.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

/// How many decided changes the FA sees under "Decided".
const _decidedShown = 10;

/// FA › Teams › Changes (2.10b, board P4; grouped in 2.10c): name, short
/// name, logo and competition requests from approved teams. ONE card per
/// team with everything it asked for (the team that has waited longest
/// first), then the latest decisions.
class FaChangesView extends ConsumerWidget {
  const FaChangesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changesAsync = ref.watch(allTeamChangesProvider);
    final teams = ref.watch(allTeamsProvider).value ?? const <Team>[];

    return changesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 40),
        child: LoadingView(),
      ),
      error: (error, _) => ErrorView(
        message: appErrorMessage(error),
        onRetry: () => ref.invalidate(allTeamChangesProvider),
      ),
      data: (all) {
        DateTime asked(TeamChange c) => c.createdAt ?? DateTime(0);
        DateTime decided(TeamChange c) => c.reviewedAt ?? DateTime(0);
        final waiting = all.where((c) => c.isPending).toList()
          ..sort((a, b) => asked(a).compareTo(asked(b)));
        final done = all.where((c) => !c.isPending).toList()
          ..sort((a, b) => decided(b).compareTo(decided(a)));

        // One group per team, in the order of its oldest request
        final byTeam = <String, List<TeamChange>>{};
        for (final change in waiting) {
          (byTeam[change.teamId] ??= []).add(change);
        }
        Team? teamOf(String teamId) =>
            teams.where((t) => t.id == teamId).firstOrNull;

        final teamCount = byTeam.length;
        final changeCount = waiting.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(
              'WAITING FOR YOU · $teamCount ${teamCount == 1 ? 'TEAM' : 'TEAMS'}'
              ' · $changeCount ${changeCount == 1 ? 'CHANGE' : 'CHANGES'}',
            ),
            if (waiting.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyView(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing waiting',
                  message: 'When a team asks to change its name, short name '
                      'or logo, or to add a competition, it appears here.',
                ),
              )
            else
              for (final MapEntry(key: teamId, value: changes)
                  in byTeam.entries) ...[
                _TeamChangesCard(
                  // Newest first, like the team's screen
                  changes: changes.reversed.toList(),
                  team: teamOf(teamId),
                  onTap: () =>
                      context.open(Routes.adminTeamChanges(teamId)),
                ),
                const SizedBox(height: 10),
              ],
            if (done.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _Heading('DECIDED'),
              for (final change in done.take(_decidedShown))
                _DecidedLine(change: change),
            ],
            const SizedBox(height: 16),
            const _InfoBox(
              text: 'Direct changes (kits, officials, ground) are not here: '
                  'they show as notes in the bell, e.g. "Royal Unique FC '
                  'updated their kits".',
            ),
          ],
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

/// "Name → Golden Unity Stars FC", "Add Juvenile (plays Division)"
TextSpan asksText(TeamChange change) {
  const bold = TextStyle(fontWeight: FontWeight.w700);
  return switch (change.kind) {
      TeamChangeKind.name => TextSpan(children: [
          const TextSpan(text: 'Name → '),
          TextSpan(text: change.to, style: bold),
        ]),
      TeamChangeKind.shortName => TextSpan(children: [
          const TextSpan(text: 'Short name → '),
          TextSpan(text: change.to, style: bold),
        ]),
      TeamChangeKind.logo => const TextSpan(text: 'New logo'),
      TeamChangeKind.competition => TextSpan(children: [
          const TextSpan(text: 'Add '),
          TextSpan(text: change.competition?.label ?? change.to, style: bold),
          TextSpan(
            text: ' (plays ${competitionsText(change.fromCompetitions)})',
          ),
        ]),
      TeamChangeKind.juvenileName => TextSpan(children: [
          const TextSpan(text: 'Juvenile side name → '),
          TextSpan(text: change.isBackToB ? '"B"' : change.to, style: bold),
        ]),
    };
}

/// One team with changes waiting: logo, team, a line per change, when
/// (and why, if it is just one), and "3 changes" in gold.
class _TeamChangesCard extends StatelessWidget {
  const _TeamChangesCard({
    required this.changes,
    required this.team,
    required this.onTap,
  });

  /// Newest first
  final List<TeamChange> changes;
  final Team? team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final team = this.team;
    final name = team?.name ?? changes.first.teamName;
    final count = changes.length;

    // "3 Nov – 5 Nov", or for one change: "4 Nov · "the reason""
    final dates = [
      for (final change in changes.reversed)
        if (change.createdAt case final at?) formatDayMonth(at),
    ];
    final whenText = count == 1
        ? [...dates, '"${changes.first.reason}"'].join(' · ')
        : dates.isEmpty || dates.first == dates.last
            ? dates.firstOrNull ?? ''
            : '${dates.first} – ${dates.last}';

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TeamLogo(
                label: initialsFor(name),
                color: team?.logoColor ?? scheme.primary,
                url: team?.logoUrl,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    for (final change in changes)
                      Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: '•  '),
                          asksText(change),
                        ]),
                        style: textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      whenText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // "3 changes" in gold: waiting for the FA
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.ghanaGold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      count == 1 ? '1 change' : '$count changes',
                      style: const TextStyle(
                        color: Color(0xFF3A2C00),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "✓ Fetteh Rangers: short name FR → FRFC · approved 2 Nov"
class _DecidedLine extends StatelessWidget {
  const _DecidedLine({required this.change});

  final TeamChange change;

  @override
  Widget build(BuildContext context) {
    final approved = change.status == ApprovalStatus.approved;
    final reviewedAt = change.reviewedAt;
    final when = reviewedAt == null ? '' : ' ${formatDayMonth(reviewedAt)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
      child: Text(
        '${approved ? '✓' : '✕'} ${change.teamName}: ${change.decidedText} · '
        '${approved ? 'approved' : 'rejected'}$when',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// The blue ⓘ box.
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Competitions in words, e.g. "Division and Juvenile".
String competitionsText(Set<Competition> competitions) =>
    competitions.map((c) => c.label).join(' and ');
