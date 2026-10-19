import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/core/widgets/status_badge.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

class TeamHomeScreen extends ConsumerStatefulWidget {
  const TeamHomeScreen({super.key});

  @override
  ConsumerState<TeamHomeScreen> createState() => _TeamHomeScreenState();
}

class _TeamHomeScreenState extends ConsumerState<TeamHomeScreen> {
  Competition? _competition; // null = the team's first competition
  PositionGroup? _group; // null = All
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _addPlayer() => context.go(Routes.addPlayer);

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(myTeamProvider);

    return teamAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, _) => Scaffold(
        appBar: const GedfaAppBar(title: 'My team'),
        body: ErrorView(
          message: appErrorMessage(error),
          onRetry: () => ref.invalidate(myTeamProvider),
        ),
      ),
      data: (team) {
        if (team == null) {
          return Scaffold(
            appBar: const GedfaAppBar(title: 'My team'),
            body: const EmptyView(
              icon: Icons.shield_outlined,
              title: 'No team linked',
              message: 'Your account is not linked to a team yet. '
                  'Please contact the FA.',
            ),
          );
        }
        return _buildForTeam(team);
      },
    );
  }

  Widget _buildForTeam(Team team) {
    final competition = _competition != null &&
            team.categories.contains(_competition)
        ? _competition!
        : Competition.values.firstWhere(team.categories.contains);
    final isDivision = competition == Competition.division;

    final squadCount = ref
            .watch(teamPlayersProvider)
            .value
            ?.where((p) => p.category == competition)
            .length ??
        0;

    return Scaffold(
      appBar: GedfaAppBar(
        title: team.name,
        subtitle: [team.shortName, team.town]
            .where((part) => part.isNotEmpty)
            .join(' · '),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: TeamLogo(
              label: initialsFor(team.name),
              color: team.logoColor,
              url: team.logoUrl,
              size: 36,
            ),
          ),
        ),
      ),
      floatingActionButton: isDivision && squadCount > 0
          ? FloatingActionButton.extended(
              onPressed: _addPlayer,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add player'),
            )
          : null,
      body: Column(
        children: [
          if (team.hasBoth)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ResponsiveCenter(
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<Competition>(
                    segments: const [
                      ButtonSegment(
                        value: Competition.division,
                        icon: Icon(Icons.shield_outlined),
                        label: Text('Division'),
                      ),
                      ButtonSegment(
                        value: Competition.juvenile,
                        icon: Icon(Icons.groups_outlined),
                        label: Text('Juvenile'),
                      ),
                    ],
                    selected: {competition},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) => setState(() {
                      _competition = value.first;
                      _group = null;
                      _search.clear();
                    }),
                  ),
                ),
              ),
            ),
          Expanded(child: _SquadBody(
            competition: competition,
            group: _group,
            search: _search,
            onGroupChanged: (group) => setState(() => _group = group),
            onSearchChanged: () => setState(() {}),
            onAddPlayer: _addPlayer,
          )),
        ],
      ),
    );
  }
}

class _SquadBody extends ConsumerWidget {
  const _SquadBody({
    required this.competition,
    required this.group,
    required this.search,
    required this.onGroupChanged,
    required this.onSearchChanged,
    required this.onAddPlayer,
  });

  final Competition competition;
  final PositionGroup? group;
  final TextEditingController search;
  final ValueChanged<PositionGroup?> onGroupChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onAddPlayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(teamPlayersProvider);
    final isDivision = competition == Competition.division;

    return playersAsync.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: appErrorMessage(error),
        onRetry: () => ref.invalidate(teamPlayersProvider),
      ),
      data: (allPlayers) {
        final squad =
            allPlayers.where((p) => p.category == competition).toList();

        if (squad.isEmpty) {
          return isDivision
              ? _EmptySquad(onAddPlayer: onAddPlayer)
              : const EmptyView(
                  icon: Icons.groups_outlined,
                  title: 'Youth registration opens soon',
                  message: 'You can add U13, U15 and U17 players once the FA '
                      'confirms the juvenile age rules.',
                );
        }

        final shown = squad
            .where((p) => group == null || p.positionGroup == group)
            .where((p) => p.matches(search.text))
            .toList();

        int count(ApprovalStatus status) =>
            squad.where((p) => p.status == status).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _CountTile(
                        value: count(ApprovalStatus.approved),
                        label: 'Approved',
                        color: AppColors.approvedText,
                      ),
                      const SizedBox(width: 10),
                      _CountTile(
                        value: count(ApprovalStatus.pending),
                        label: 'Pending',
                        color: AppColors.pendingText,
                      ),
                      const SizedBox(width: 10),
                      _CountTile(
                        value: count(ApprovalStatus.rejected),
                        label: 'Rejected',
                        color: AppColors.rejectedText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: search,
                    onChanged: (_) => onSearchChanged(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search by name or player ID',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                search.clear();
                                onSearchChanged();
                              },
                            ),
                    ),
                  ),
                  if (isDivision) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: group == null,
                          onSelected: (_) => onGroupChanged(null),
                        ),
                        for (final g in PositionGroup.values)
                          ChoiceChip(
                            label: Text(g.code),
                            tooltip: g.label,
                            selected: group == g,
                            onSelected: (_) => onGroupChanged(g),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No players match.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    )
                  else
                    for (final player in shown) ...[
                      _PlayerTile(
                        player: player,
                        onTap: () => context.go(Routes.player(player.id)),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                // The light-mode status colours are too dark on navy
                color: isDark ? scheme.onSurface : color,
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

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.onTap});

  final Player player;
  final VoidCallback onTap;

  String get _subtitle {
    final id = switch (player.status) {
      ApprovalStatus.approved => player.playerCode ?? 'ID coming',
      ApprovalStatus.pending => 'ID after approval',
      ApprovalStatus.rejected => 'Not approved',
    };
    return '$id · ${player.position.display}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _subtitle,
                      maxLines: 1,
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
                  Text(
                    '#${player.jerseyNo}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(status: player.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySquad extends StatelessWidget {
  const _EmptySquad({required this.onAddPlayer});

  final VoidCallback onAddPlayer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget step(int number, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: scheme.primary.withValues(alpha: 0.14),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(text,
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: scheme.outline),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.approvedBg,
                      child: const Icon(Icons.check_rounded,
                          size: 32, color: AppColors.approvedText),
                    ),
                    const SizedBox(height: 10),
                    Text('Your team is approved',
                        style: textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Next, add your Division players. The FA approves each '
                      'one before they can play.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onAddPlayer,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add your first player'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOW IT WORKS',
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 10),
                    step(1, 'Add your players',
                        'Name, date of birth, position, jersey number and a passport photo.'),
                    step(2, 'The FA checks each player',
                        "You'll see Pending, Approved or the reason it was rejected."),
                    step(3, 'Approved players can play',
                        'Only they appear on team sheets.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
