import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/position_rows.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:go_router/go_router.dart';

/// Team admin, Positions tab: "who can play where?"
///
/// - All: one row per group (Goalkeepers, Defenders, ...).
/// - One group (e.g. DEF): one row per detailed position (Centre-back,
///   Left-back, ...), so gaps in the squad are easy to see.
/// - Each row shows the average age; cards show position and age.
/// - "Approved players only" = the players who can go on a team sheet.
///
/// Division only for now (Juvenile waits for GEDFA's age rules).
class TeamPositionsScreen extends ConsumerStatefulWidget {
  const TeamPositionsScreen({super.key});

  @override
  ConsumerState<TeamPositionsScreen> createState() =>
      _TeamPositionsScreenState();
}

class _TeamPositionsScreenState extends ConsumerState<TeamPositionsScreen> {
  PositionGroup? _group; // null = All
  bool _onlyApproved = false;

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(myTeamProvider).value;
    final playersAsync = ref.watch(teamPlayersProvider);

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Positions',
        subtitle: team == null ? null : '${team.name} · Division',
        actions: const [NotificationBell()],
      ),
      body: playersAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: appErrorMessage(error),
          onRetry: () => ref.invalidate(teamPlayersProvider),
        ),
        data: (all) => _body(
          all.where((p) => p.category == Competition.division).toList(),
        ),
      ),
    );
  }

  Widget _body(List<Player> division) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (division.isEmpty) {
      return const EmptyView(
        icon: Icons.groups_outlined,
        title: 'No players yet',
        message: 'Add players on the Squad tab. They appear here by position.',
      );
    }

    final pool = _onlyApproved
        ? division.where((p) => p.status == ApprovalStatus.approved).toList()
        : division;
    final group = _group;

    final sections = group == null
        ? sectionsByGroup(pool, isDark: isDark)
        : sectionsByPosition(
            pool.where((p) => p.positionGroup == group),
            group,
            isDark: isDark,
          );

    int countIn(PositionGroup? g) =>
        g == null ? pool.length : pool.where((p) => p.positionGroup == g).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // All · GK · DEF · MID · FWD, equal widths, one row
              Row(
                children: [
                  for (final g in <PositionGroup?>[null, ...PositionGroup.values]) ...[
                    if (g != null) const SizedBox(width: 6),
                    Expanded(
                      child: _GroupChip(
                        label: g?.code ?? 'All',
                        tooltip: g == null ? 'All positions' : g.label,
                        count: countIn(g),
                        selected: _group == g,
                        onTap: () => setState(() => _group = g),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Material(
                color: scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: scheme.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  value: _onlyApproved,
                  onChanged: (value) => setState(() => _onlyApproved = value),
                  title: Text(
                    'Approved players only',
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Only these can be picked for team sheets',
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
              if (sections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyView(
                    icon: Icons.person_search_outlined,
                    title: 'No players here',
                    message: _onlyApproved
                        ? 'No approved players in this position yet.'
                        : 'No players in this position yet.',
                  ),
                )
              else
                PositionRows(
                  sections: sections,
                  cardLine: CardLine.positionAndAge,
                  showAverageAge: true,
                  // push, so Back returns here (not to the Squad tab)
                  onTap: (player) => context.push(Routes.player(player.id)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A pill with a label and a count bubble. Selected: filled blue.
class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.tooltip,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background = selected ? scheme.primary : scheme.surface;
    final ink = selected ? scheme.onPrimary : scheme.onSurface;
    final bubble = selected
        ? scheme.onPrimary.withValues(alpha: 0.25)
        : (isDark ? const Color(0xFF22385A) : const Color(0xFFDCE6F2));

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$tooltip, $count',
        excludeSemantics: true,
        child: Material(
          color: background,
          shape: StadiumBorder(
            side: selected
                ? BorderSide.none
                : BorderSide(color: scheme.outline),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bubble,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
