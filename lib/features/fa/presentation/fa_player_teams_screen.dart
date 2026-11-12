import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/count_tabs.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/core/widgets/status_badge.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/screening/presentation/widgets/next_screening_strip.dart';
import 'package:gedfa_connect/features/suspensions/data/player_suspension_repository.dart';
import 'package:gedfa_connect/features/suspensions/presentation/widgets/ban_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

/// FA, Players tab: every team with how many players it has, how many are
/// approved and how many are waiting. Teams with players to review come
/// first. Tap a team to see its players by position.
///
/// The search also finds single players (by name, player ID or #number)
/// across all teams.
///
/// 2.14b (board J5): a "Division | Juvenile" switch at the top. Juvenile
/// shows how many children wait for screening in each age group, and the
/// teams with their age groups. The switch lives in the address
/// (`?view=juvenile`), so the bell and the Back button can open either.
class FaPlayerTeamsScreen extends ConsumerStatefulWidget {
  const FaPlayerTeamsScreen({
    super.key,
    this.juvenile = false,
    this.fromHome = false,
  });

  /// True: the Juvenile side is showing.
  final bool juvenile;

  /// Opened from a "Needs you" row on Home: back arrow to Home (2.12a)
  final bool fromHome;

  @override
  ConsumerState<FaPlayerTeamsScreen> createState() =>
      _FaPlayerTeamsScreenState();
}

class _FaPlayerTeamsScreenState extends ConsumerState<FaPlayerTeamsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(allTeamsProvider);
    final playersAsync = ref.watch(allPlayersProvider);

    Widget body;
    final error = teamsAsync.error ?? playersAsync.error;
    if (error != null) {
      body = ErrorView(
        message: appErrorMessage(error),
        onRetry: () {
          ref.invalidate(allTeamsProvider);
          ref.invalidate(allPlayersProvider);
        },
      );
    } else if (!teamsAsync.hasValue || !playersAsync.hasValue) {
      body = const LoadingView(message: 'Loading the teams…');
    } else {
      final teams = teamsAsync.requireValue;
      final all = playersAsync.requireValue;
      final division = [for (final p in all) if (!p.isJuvenile) p];
      final juvenile = [for (final p in all) if (p.isJuvenile) p];
      body = Column(
        children: [
          _ViewSwitch(
            juvenile: widget.juvenile,
            toReview: division
                .where((p) => p.status == ApprovalStatus.pending)
                .length,
            waiting: juvenile.where((p) => p.isWaitingForScreening).length,
            // A new search for each side
            onChanged: (value) {
              setState(() => _search = '');
              // The back arrow to Home stays when switching sides
              context.goKeepingHome(
                value ? Routes.adminPlayersJuvenile : Routes.adminPlayers,
              );
            },
          ),
          Expanded(
            child: widget.juvenile
                ? _juvenileBody(teams, juvenile)
                : _body(teams, division),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Players',
        subtitle: 'Gomoa East District FA',
        leading: widget.fromHome ? const BackToHomeButton() : null,
        actions: const [NotificationBell()],
      ),
      body: body,
    );
  }

  /// The Juvenile side (board J5): waiting per age group, then the teams
  /// with an age-group chip each. The search finds teams and children.
  Widget _juvenileBody(List<Team> teams, List<Player> players) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Per team, per age group: how many children, how many waiting
    final stats = <String, Map<AgeGroup, _GroupCount>>{};
    for (final player in players) {
      final group = player.ageGroup;
      if (group == null) continue;
      final count = stats
          .putIfAbsent(player.teamId, () => {})
          .putIfAbsent(group, _GroupCount.new);
      count.total++;
      if (player.isWaitingForScreening) count.waiting++;
    }
    int waitingIn(AgeGroup group) => players
        .where((p) => p.ageGroup == group && p.isWaitingForScreening)
        .length;
    int waitingAt(String teamId) => (stats[teamId]?.values ?? const [])
        .fold(0, (sum, c) => sum + c.waiting);

    // Juvenile teams (and any team that still has juvenile players)
    final query = _search.trim().toLowerCase();
    final shownTeams = teams
        .where((team) =>
            team.categories.contains(Competition.juvenile) ||
            stats.containsKey(team.id))
        .where((team) =>
            query.isEmpty ||
            team.name.toLowerCase().contains(query) ||
            team.shortName.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) {
        final byWaiting = waitingAt(b.id).compareTo(waitingAt(a.id));
        return byWaiting != 0
            ? byWaiting
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final matchingChildren = query.isEmpty
        ? const <Player>[]
        : players.where((p) => p.matches(query)).take(20).toList();
    final gold = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF5D25B)
        : const Color(0xFF8A6A00);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (final group in AgeGroup.values) ...[
                    if (group != AgeGroup.values.first)
                      const SizedBox(width: 10),
                    _TotalCard(
                      value: waitingIn(group),
                      label: '${group.label} waiting',
                      color: waitingIn(group) > 0 ? gold : scheme.onSurface,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              const _SuspendedTile(),
              const SizedBox(height: 12),
              const NextScreeningStrip(),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('juvenile-search'),
                decoration: const InputDecoration(
                  hintText: 'Search a team or child',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 12),

              if (matchingChildren.isNotEmpty) ...[
                _SmallHeading('Children · ${matchingChildren.length}'),
                for (final child in matchingChildren) ...[
                  _PlayerResult(
                    player: child,
                    onTap: () =>
                        context.pushKeepingHome(Routes.adminJuvenileChild(child.id)),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                _SmallHeading('Teams · ${shownTeams.length}'),
              ],

              if (shownTeams.isEmpty && matchingChildren.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyView(
                    icon: Icons.child_care_outlined,
                    title: query.isEmpty ? 'No juvenile teams yet' : 'No match',
                    message: query.isEmpty
                        ? 'Approved clubs in the Juvenile competition will '
                            'appear here.'
                        : 'No team or child matches "$_search".',
                  ),
                )
              else ...[
                for (final team in shownTeams) ...[
                  _JuvenileTeamCard(
                    team: team,
                    groups: stats[team.id] ?? const {},
                    onTap: () =>
                        context.open(Routes.adminTeamJuvenile(team.id)),
                  ),
                  const SizedBox(height: 8),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(
                    'Tap a team to see its children by age group, with '
                    'photo, date of birth and parent. Decisions are made on '
                    'the screening day.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _body(List<Team> teams, List<Player> players) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Count each team's players by status (one pass over all players)
    final stats = <String, _TeamStats>{};
    for (final player in players) {
      stats.putIfAbsent(player.teamId, _TeamStats.new).add(player.status);
    }

    final pendingTotal =
        players.where((p) => p.status == ApprovalStatus.pending).length;
    final approvedTotal =
        players.where((p) => p.status == ApprovalStatus.approved).length;

    // Filter teams by the search, then: most to review first, then A to Z
    final query = _search.trim().toLowerCase();
    final shownTeams = teams
        .where((team) =>
            query.isEmpty ||
            team.name.toLowerCase().contains(query) ||
            team.shortName.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) {
        final byPending = (stats[b.id]?.pending ?? 0)
            .compareTo(stats[a.id]?.pending ?? 0);
        return byPending != 0
            ? byPending
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    // Players matching the search (name, player ID or #10), max 20
    final matchingPlayers = query.isEmpty
        ? const <Player>[]
        : players.where((p) => p.matches(query)).take(20).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _TotalCard(
                    value: pendingTotal,
                    label: 'To review',
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF5D25B)
                        : const Color(0xFF8A6A00),
                  ),
                  const SizedBox(width: 10),
                  _TotalCard(
                    value: approvedTotal,
                    label: 'Approved',
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkGreen
                        : AppColors.ghanaGreen,
                  ),
                  const SizedBox(width: 10),
                  _TotalCard(
                    value: teams.length,
                    label: 'Teams',
                    color: scheme.onSurface,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const _SuspendedTile(),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('division-search'),
                decoration: const InputDecoration(
                  hintText: 'Team, player name or player ID',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Teams with players awaiting review appear first.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 8),

              // Single players found by the search
              if (matchingPlayers.isNotEmpty) ...[
                const SizedBox(height: 4),
                _SmallHeading('Players · ${matchingPlayers.length}'),
                for (final player in matchingPlayers) ...[
                  _PlayerResult(
                    player: player,
                    onTap: () =>
                        context.pushKeepingHome(Routes.adminPlayer(player.id)),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                _SmallHeading('Teams · ${shownTeams.length}'),
              ],

              if (shownTeams.isEmpty && matchingPlayers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyView(
                    icon: Icons.groups_outlined,
                    title: query.isEmpty ? 'No teams yet' : 'No match',
                    message: query.isEmpty
                        ? 'Approved teams and their players will appear here.'
                        : 'No team or player matches "$_search".',
                  ),
                )
              else
                for (final team in shownTeams) ...[
                  _TeamCard(
                    team: team,
                    stats: stats[team.id] ?? _TeamStats(),
                    onTap: () =>
                        context.open(Routes.adminTeamPlayers(team.id)),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Division · 7 | Juvenile · 62" at the top of the tab (board J5).
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({
    required this.juvenile,
    required this.toReview,
    required this.waiting,
    required this.onChanged,
  });

  final bool juvenile;

  /// Division players to review
  final int toReview;

  /// Juvenile players waiting for screening
  final int waiting;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ResponsiveCenter(
        maxWidth: 720,
        child: CountTabs<bool>(
          tabs: [
            CountTab(
              value: false,
              label: 'Division',
              count: toReview,
              highlight: true,
            ),
            CountTab(
              value: true,
              label: 'Juvenile',
              count: waiting,
              highlight: true,
            ),
          ],
          selected: juvenile,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// One team's children in one age group.
class _GroupCount {
  int total = 0;
  int waiting = 0;
}

/// A juvenile team: logo, name and one chip per age group:
/// gold "U13 · 9 waiting", or grey "U17 · 4" when nobody waits.
class _JuvenileTeamCard extends StatelessWidget {
  const _JuvenileTeamCard({
    required this.team,
    required this.groups,
    required this.onTap,
  });

  final Team team;
  final Map<AgeGroup, _GroupCount> groups;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldBg = isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC);
    final goldInk = isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700);
    final greyBg = isDark ? AppColors.darkBorder : const Color(0xFFDCE6F2);

    final chips = [
      for (final group in AgeGroup.values)
        if (groups[group] case final count?)
          count.waiting > 0
              ? _Pill(
                  text: '${group.label} · ${count.waiting} waiting',
                  background: goldBg,
                  foreground: goldInk,
                )
              : _Pill(
                  text: '${group.label} · ${count.total}',
                  background: greyBg,
                  foreground: scheme.onSurfaceVariant,
                ),
    ];

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              TeamLogo(
                label: initialsFor(team.name),
                color: team.logoColor,
                url: team.logoUrl,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (chips.isEmpty)
                      Text(
                        'No juvenile players yet',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      )
                    else
                      Wrap(spacing: 6, runSpacing: 6, children: chips),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How many players a team has in each status.
class _TeamStats {
  int approved = 0;
  int pending = 0;
  int rejected = 0;

  int get total => approved + pending + rejected;

  void add(ApprovalStatus status) {
    switch (status) {
      case ApprovalStatus.approved:
        approved++;
      case ApprovalStatus.pending:
        pending++;
      case ApprovalStatus.rejected:
        rejected++;
    }
  }
}

/// One of the three numbers at the top (To review / Approved / Teams).
/// SP2 (3.1e1): "Suspended · 3 now" opens everyone suspended.
class _SuspendedTile extends ConsumerWidget {
  const _SuspendedTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(faBansProvider).length;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (bg, ink) = banColours(context);
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.open(Routes.adminSuspended),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.block_rounded, color: ink, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Suspended players',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                count == 0 ? 'None now' : '$count now',
                style: textTheme.labelMedium?.copyWith(
                  color: count == 0 ? scheme.onSurfaceVariant : ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline),
        ),
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
    );
  }
}

class _SmallHeading extends StatelessWidget {
  const _SmallHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

/// A team: logo, name, "19 players · 14 approved", a coloured progress bar
/// (green approved, gold pending, red rejected) and "4 to review".
class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.stats,
    required this.onTap,
  });

  final Team team;
  final _TeamStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final summary = stats.total == 0
        ? 'No players yet'
        : '${stats.total} ${stats.total == 1 ? 'player' : 'players'} · '
            '${stats.approved} approved';

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              TeamLogo(
                label: initialsFor(team.name),
                color: team.logoColor,
                url: team.logoUrl,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      summary,
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (stats.total > 0) ...[
                      const SizedBox(height: 6),
                      _ProgressBar(stats: stats),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (stats.pending > 0)
                    _Pill(
                      text: '${stats.pending} to review',
                      background: AppColors.ghanaGold,
                      foreground: const Color(0xFF3A2C00),
                    )
                  else if (stats.total > 0)
                    _Pill(
                      text: 'Up to date',
                      background: isDark
                          ? const Color(0xFF123D2B)
                          : AppColors.approvedBg,
                      foreground: isDark
                          ? const Color(0xFF7BE3B0)
                          : AppColors.approvedText,
                    ),
                  const SizedBox(height: 6),
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

/// Thin bar split into approved (green), pending (gold), rejected (red).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.stats});

  final _TeamStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget part(int count, Color color) => count == 0
        ? const SizedBox.shrink()
        : Expanded(flex: count, child: ColoredBox(color: color));

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 6,
          color: isDark ? AppColors.darkBorder : const Color(0xFFE3EAF2),
          child: Row(
            // Make each coloured part fill the bar's 6 px height.
            // Without this, an empty ColoredBox is 0 px tall and invisible.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              part(stats.approved,
                  isDark ? AppColors.darkGreen : AppColors.ghanaGreen),
              part(stats.pending, AppColors.ghanaGold),
              part(stats.rejected, scheme.error),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A player found by the search: photo, name, team · ID, status.
class _PlayerResult extends StatelessWidget {
  const _PlayerResult({required this.player, required this.onTap});

  final Player player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code = player.playerCode;

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              PlayerAvatar(name: player.fullName, url: player.thumbUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      [
                        player.teamName,
                        ?player.ageGroup?.label,
                        '#${player.jerseyNo}',
                        ?code,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Juvenile children waiting: "Screening", not "Pending"
              if (player.isWaitingForScreening)
                _Pill(
                  text: 'Screening',
                  background: isDark
                      ? const Color(0xFF3D3410)
                      : const Color(0xFFFFF6CC),
                  foreground: isDark
                      ? const Color(0xFFF5D25B)
                      : const Color(0xFF5C4700),
                )
              else
                StatusBadge(status: player.status),
            ],
          ),
        ),
      ),
    );
  }
}
