import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/notifications/presentation/pinned_announcement_card.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/position_rows.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
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
  ApprovalStatus? _status; // null = show everyone
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _addPlayer() {
    // The FA can close player registration (2.13d)
    final open =
        ref.read(leagueSettingsProvider).value?.playerRegistrationOpen ?? true;
    if (!open) {
      AppToast.warning(
        context,
        'Player registration is closed. The FA will open it again.',
      );
      return;
    }
    context.go(Routes.addPlayer);
  }

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

    final playersOpen =
        ref.watch(leagueSettingsProvider).value?.playerRegistrationOpen ??
            true;

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
        actions: const [NotificationBell()],
      ),
      floatingActionButton: isDivision && squadCount > 0
          ? playersOpen
              ? FloatingActionButton.extended(
                  onPressed: _addPlayer,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add player'),
                )
              // Board L3: greyed out; a tap explains why
              : FloatingActionButton.extended(
                  onPressed: _addPlayer,
                  elevation: 0,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Add player (closed)'),
                )
          : null,
      body: Column(
        children: [
          if (!playersOpen)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ResponsiveCenter(child: _ClosedBanner()),
            ),
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
                      _status = null;
                      _search.clear();
                    }),
                  ),
                ),
              ),
            ),
          Expanded(child: _SquadBody(
            competition: competition,
            status: _status,
            search: _search,
            onStatusChanged: (status) => setState(() => _status = status),
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
    required this.status,
    required this.search,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onAddPlayer,
  });

  final Competition competition;

  /// Which tile is selected (null = show everyone).
  final ApprovalStatus? status;
  final TextEditingController search;
  final ValueChanged<ApprovalStatus?> onStatusChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onAddPlayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(teamPlayersProvider);
    final isDivision = competition == Competition.division;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

        int count(ApprovalStatus s) => squad.where((p) => p.status == s).length;
        final rejected = count(ApprovalStatus.rejected);

        final shown = squad
            .where((p) => status == null || p.status == status)
            .where((p) => p.matches(search.text))
            .toList();

        /// Tapping a tile shows only those players; tapping it again
        /// shows everyone.
        void pick(ApprovalStatus s) => onStatusChanged(status == s ? null : s);

        final hint = status == null
            ? 'Tap a number to show only those players.'
            : 'Showing ${_statusWord(status!)} players. Tap again to show all.';

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            ResponsiveCenter(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // FA's pinned announcement (2.7), if any
                  const PinnedAnnouncementCard(),
                  Row(
                    children: [
                      _StatusTile(
                        value: count(ApprovalStatus.approved),
                        label: 'Approved',
                        color: isDark
                            ? AppColors.darkGreen
                            : AppColors.ghanaGreen,
                        selected: status == ApprovalStatus.approved,
                        onTap: () => pick(ApprovalStatus.approved),
                      ),
                      const SizedBox(width: 10),
                      _StatusTile(
                        value: count(ApprovalStatus.pending),
                        label: 'Pending',
                        color: isDark
                            ? const Color(0xFFF5D25B)
                            : const Color(0xFF8A6A00),
                        selected: status == ApprovalStatus.pending,
                        onTap: () => pick(ApprovalStatus.pending),
                      ),
                      const SizedBox(width: 10),
                      _StatusTile(
                        value: rejected,
                        label: 'Rejected',
                        color: scheme.error,
                        selected: status == ApprovalStatus.rejected,
                        onTap: () => pick(ApprovalStatus.rejected),
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
                  // Rejected players need the team's attention
                  if (rejected > 0) ...[
                    const SizedBox(height: 12),
                    InfoBox(
                      icon: Icons.error_outline_rounded,
                      color: scheme.error,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: rejected == 1
                                  ? '1 player was not approved. '
                                  : '$rejected players were not approved. ',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(
                              text: "Open the player to read the FA's "
                                  'reason, correct the details and resubmit.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No players match.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    PositionRows(
                      sections: sectionsByGroup(shown, isDark: isDark),
                      cardLine: CardLine.squad,
                      onTap: (player) => context.go(Routes.player(player.id)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _statusWord(ApprovalStatus status) => switch (status) {
        ApprovalStatus.approved => 'approved',
        ApprovalStatus.pending => 'pending',
        ApprovalStatus.rejected => 'rejected',
      };
}

/// One of the three numbers at the top. Tap to filter; the selected tile
/// gets a blue border.
class _StatusTile extends StatelessWidget {
  const _StatusTile({
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
        label: '$label, $value. ${selected ? 'Showing only these.' : ''}',
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

/// Board L3: "Player registration is closed."
class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC);
    final ink = isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              const TextSpan(
                children: [
                  TextSpan(
                    text: 'Player registration is closed. ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: 'You can still correct players the FA rejected. '
                        'New players can be added when the FA opens it again.',
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    height: 1.5,
                    color: ink,
                  ),
            ),
          ),
        ],
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
