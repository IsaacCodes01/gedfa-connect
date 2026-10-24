import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/players/data/player_profile_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/player_profile.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/position_rows.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:go_router/go_router.dart';

/// Team admin, Positions tab: Player profiles, the team manager's view.
///
/// - Available / Injured / Unavailable counts (approved players).
/// - All · GK · DEF · MID · FWD; one group → rows by detailed position.
/// - Each row: average age and height. Cards: position, age, height,
///   foot, the C / VC badge and availability.
/// - Tap Available / Injured / Unavailable to show only those players
///   (Available = who can go on a team sheet right now); tap again for all.
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
  Availability? _filter; // null = everyone

  static const _category = 'division';

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(myTeamProvider).value;
    final playersAsync = ref.watch(teamPlayersProvider);
    final profilesAsync = ref.watch(teamProfilesProvider);
    final armbands =
        ref.watch(armbandsProvider(_category)).value ?? const Armbands();

    Widget body;
    final error = playersAsync.error ?? profilesAsync.error;
    if (error != null) {
      body = ErrorView(
        message: appErrorMessage(error),
        onRetry: () {
          ref.invalidate(teamPlayersProvider);
          ref.invalidate(teamProfilesProvider);
        },
      );
    } else if (!playersAsync.hasValue || !profilesAsync.hasValue) {
      body = const LoadingView();
    } else {
      body = _body(
        playersAsync.requireValue
            .where((p) => p.category == Competition.division)
            .toList(),
        profilesAsync.requireValue,
        armbands,
      );
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Player profiles',
        subtitle: team == null ? null : '${team.name} · Division',
        actions: const [NotificationBell()],
      ),
      body: body,
    );
  }

  Widget _body(
    List<Player> division,
    Map<String, PlayerProfile> profiles,
    Armbands armbands,
  ) {
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

    PlayerProfile profileOf(Player p) =>
        profiles[p.id] ?? PlayerProfile.empty(p.id, p.teamId);

    // Availability counts: approved players only (others can't play anyway)
    final approved =
        division.where((p) => p.status == ApprovalStatus.approved).toList();
    int countAvail(Availability a) =>
        approved.where((p) => profileOf(p).availability == a).length;

    // A tile selected: only approved players with that availability
    final filter = _filter;
    final pool = filter == null
        ? division
        : approved.where((p) => profileOf(p).availability == filter).toList();

    // Tap a tile to filter; tap it again to show everyone
    void pick(Availability a) =>
        setState(() => _filter = _filter == a ? null : a);
    final hint = filter == null
        ? 'Tap a number to show only those players.'
        : filter == Availability.available
            ? 'Showing who you can pick for a team sheet. Tap again to show '
                'all.'
            : 'Showing ${filter.label.toLowerCase()} players. Tap again to '
                'show all.';
    final group = _group;

    final sections = group == null
        ? sectionsByGroup(pool, isDark: isDark)
        : sectionsByPosition(
            pool.where((p) => p.positionGroup == group),
            group,
            isDark: isDark,
          );

    int countIn(PositionGroup? g) => g == null
        ? pool.length
        : pool.where((p) => p.positionGroup == g).length;

    // "Avg age 22 · 1.79 m" (height only from players who filled it in)
    String headingTrailing(PlayerSection section) {
      final heights = [
        for (final p in section.players) ?profileOf(p).heightCm,
      ];
      if (heights.isEmpty) return 'Avg age ${section.averageAge}';
      final avg = heights.reduce((a, b) => a + b) / heights.length / 100;
      return 'Avg age ${section.averageAge} · ${avg.toStringAsFixed(2)} m';
    }

    final extras = {
      for (final p in division)
        p.id: CardExtra(
          badge: armbands.badgeFor(p.id),
          availability: profileOf(p).availability,
          line: [
            profileOf(p).heightText ?? 'No height',
            profileOf(p).foot?.label ?? 'foot?',
          ].join(' · '),
        ),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _CountTile(
                    value: countAvail(Availability.available),
                    label: 'Available',
                    color:
                        isDark ? AppColors.darkGreen : AppColors.ghanaGreen,
                    selected: filter == Availability.available,
                    onTap: () => pick(Availability.available),
                  ),
                  const SizedBox(width: 10),
                  _CountTile(
                    value: countAvail(Availability.injured),
                    label: 'Injured',
                    color: scheme.error,
                    selected: filter == Availability.injured,
                    onTap: () => pick(Availability.injured),
                  ),
                  const SizedBox(width: 10),
                  _CountTile(
                    value: countAvail(Availability.unavailable),
                    label: 'Unavailable',
                    color: scheme.onSurfaceVariant,
                    selected: filter == Availability.unavailable,
                    onTap: () => pick(Availability.unavailable),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  hint,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              // All · GK · DEF · MID · FWD, equal widths, one row
              Row(
                children: [
                  for (final g in <PositionGroup?>[
                    null,
                    ...PositionGroup.values,
                  ]) ...[
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
              if (sections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyView(
                    icon: Icons.person_search_outlined,
                    title: 'No players here',
                    message: filter == null
                        ? 'No players in this position yet.'
                        : 'No ${filter.label.toLowerCase()} players in this '
                            'position.',
                  ),
                )
              else
                PositionRows(
                  sections: sections,
                  cardLine: CardLine.positionAndAge,
                  headingTrailing: headingTrailing,
                  extras: extras,
                  // push, so Back returns here (not to the Squad tab)
                  onTap: (player) =>
                      context.push(Routes.teamPlayerProfile(player.id)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One of the three numbers. Tap to filter; selected = blue border.
class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.value,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label, $value',
        excludeSemantics: true,
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
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
            side: selected ? BorderSide.none : BorderSide(color: scheme.outline),
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
