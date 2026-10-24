import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/player_code.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/count_tabs.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/position_rows.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:go_router/go_router.dart';

/// The three tabs on this screen.
enum _Tab { toReview, approved, all }

/// FA: one team's players, in rows by position (Goalkeepers, Defenders,
/// Midfielders, Forwards), 3 cards per row on a phone.
///
/// Tap a card to review that player. "Select" lets the FA tick several
/// pending players and approve them together.
class FaTeamPlayersScreen extends ConsumerStatefulWidget {
  const FaTeamPlayersScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<FaTeamPlayersScreen> createState() =>
      _FaTeamPlayersScreenState();
}

class _FaTeamPlayersScreenState extends ConsumerState<FaTeamPlayersScreen> {
  _Tab? _tab; // null = not chosen yet (picked from the data, see below)
  bool _selecting = false;
  final _picked = <String>{}; // player IDs
  bool _busy = false;

  void _startSelecting() => setState(() {
        _selecting = true;
        _tab = _Tab.toReview; // only pending players can be selected
      });

  void _stopSelecting() => setState(() {
        _selecting = false;
        _picked.clear();
      });

  void _toggle(Player player) => setState(() {
        if (!_picked.remove(player.id)) _picked.add(player.id);
      });

  void _open(Player player) {
    if (_selecting) {
      if (player.status == ApprovalStatus.pending) _toggle(player);
      return;
    }
    context.push(Routes.adminPlayer(player.id));
  }

  Future<void> _approveSelected(List<Player> teamPlayers) async {
    // Keep the squad order (by position, then number) in the dialog
    final chosen = [
      for (final p in teamPlayers)
        if (_picked.contains(p.id) && p.status == ApprovalStatus.pending) p,
    ];
    if (chosen.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _BulkApproveDialog(players: chosen),
    );
    final faUid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (ok != true || faUid == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(playerRepositoryProvider).approveMany(
            [for (final p in chosen) p.id],
            faUid: faUid,
          );
      if (!mounted) return;
      final done = result.codes.length;
      if (result.failed == 0) {
        AppToast.success(
          context,
          done == 1 ? '1 player approved.' : '$done players approved.',
        );
      } else {
        AppToast.warning(
          context,
          '$done approved, ${result.failed} could not be approved. They may '
          'have been changed or reviewed by someone else. Open them to check.',
        );
      }
      _stopSelecting();
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamByIdProvider(widget.teamId));
    final playersAsync = ref.watch(allPlayersProvider);
    final team = teamAsync.value;

    // This team's players, sorted by position group, then jersey number
    final teamPlayers = sortedBySquadOrder(
      playersAsync.value?.where((p) => p.teamId == widget.teamId) ?? [],
    );
    final pending =
        teamPlayers.where((p) => p.status == ApprovalStatus.pending).length;

    final competitions = team == null
        ? ''
        : team.categories.map((c) => c.label).join(' & ');
    final subtitle = team == null
        ? null
        : '$competitions · ${teamPlayers.length} '
            '${teamPlayers.length == 1 ? 'player' : 'players'}';

    Widget body;
    final error = teamAsync.error ?? playersAsync.error;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!teamAsync.hasValue || !playersAsync.hasValue) {
      body = const LoadingView();
    } else if (team == null) {
      body = const EmptyView(
        icon: Icons.search_off_rounded,
        title: 'Team not found',
        message: 'It may have been removed.',
      );
    } else {
      body = _body(teamPlayers, pending);
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: team?.name ?? 'Team players',
        subtitle: subtitle,
        leading: BackButton(onPressed: () => context.go(Routes.adminPlayers)),
        actions: [
          if (pending > 0)
            TextButton(
              onPressed: _busy
                  ? null
                  : (_selecting ? _stopSelecting : _startSelecting),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(
                  alpha: _selecting ? 0.28 : 0.16,
                ),
                minimumSize: const Size(64, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(_selecting ? 'Done' : 'Select'),
            ),
        ],
      ),
      bottomNavigationBar: _selecting
          ? _SelectionBar(
              count: _picked.length,
              busy: _busy,
              onApprove: () => _approveSelected(teamPlayers),
            )
          : null,
      body: body,
    );
  }

  Widget _body(List<Player> teamPlayers, int pending) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // First visit: open on "To review" if there is anything to review
    final tab = _tab ?? (pending > 0 ? _Tab.toReview : _Tab.all);

    final approved =
        teamPlayers.where((p) => p.status == ApprovalStatus.approved).length;
    final shown = teamPlayers.where((p) {
      return switch (tab) {
        _Tab.toReview => p.status == ApprovalStatus.pending,
        _Tab.approved => p.status == ApprovalStatus.approved,
        _Tab.all => true,
      };
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CountTabs<_Tab>(
                tabs: [
                  CountTab(
                    value: _Tab.toReview,
                    label: 'To review',
                    count: pending,
                    highlight: true,
                  ),
                  CountTab(
                    value: _Tab.approved,
                    label: 'Approved',
                    count: approved,
                  ),
                  CountTab(
                    value: _Tab.all,
                    label: 'All',
                    count: teamPlayers.length,
                  ),
                ],
                selected: tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
              if (_selecting) ...[
                const SizedBox(height: 12),
                Text(
                  'Tap the players awaiting review that you have checked. '
                  'Only pending players can be selected.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 8),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyView(
                    icon: Icons.groups_outlined,
                    title: switch (tab) {
                      _Tab.toReview => 'Nothing to review',
                      _Tab.approved => 'No approved players yet',
                      _Tab.all => 'No players yet',
                    },
                    message: tab == _Tab.toReview
                        ? 'All players of this team have been reviewed.'
                        : 'Players appear here once the team adds them.',
                  ),
                )
              else
                PositionRows(
                  sections: sectionsByGroup(
                    shown,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                  cardLine: CardLine.fa,
                  selecting: _selecting,
                  picked: _picked,
                  onTap: _open,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Select mode: bottom bar and dialog ───────────────────────────────────

/// "3 selected   [Approve selected]"
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.busy,
    required this.onApprove,
  });

  final int count;
  final bool busy;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$count selected',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: count == 0 || busy ? null : onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: approveGreen(context),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.done_all_rounded),
                    label: const Text('Approve selected'),
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

/// "Approve 3 players?" listing each name with the ID they will receive.
/// Players approved before keep their ID; the others get the next numbers.
class _BulkApproveDialog extends ConsumerWidget {
  const _BulkApproveDialog({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final next = ref.watch(nextPlayerNumberProvider).value;
    final year = DateTime.now().toUtc().year;

    // Work out the ID each player will receive, in order
    var number = next ?? 0;
    final rows = <(String, String)>[];
    for (final player in players) {
      final existing = player.playerCode;
      if (existing != null) {
        rows.add((player.fullName, '$existing (kept)'));
      } else {
        rows.add((
          player.fullName,
          next == null ? '…' : playerCodeFor(number++, year),
        ));
      }
    }

    final count = players.length;
    return AlertDialog(
      title: Text(count == 1 ? 'Approve 1 player?' : 'Approve $count players?'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Each player receives a permanent player ID and becomes '
              'eligible for selection on team sheets.',
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outline),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: scheme.outline),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            rows[i].$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rows[i].$2,
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'IDs are confirmed when saved.',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(96, 44),
            backgroundColor: approveGreen(context),
            foregroundColor: Colors.white,
          ),
          child: Text(count == 1 ? 'Approve' : 'Approve all'),
        ),
      ],
    );
  }
}
