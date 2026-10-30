import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/player_code.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/core/widgets/status_badge.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/duplicates.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:go_router/go_router.dart';

/// Youngest age for the Division (same as the Add player form).
const _minDivisionAge = 13;

/// The quick reasons on the Reject sheet.
const _quickReasons = [
  'Photo is not clear',
  'Photo does not meet passport standards',
  'Date of birth requires verification',
  'Name does not match identity documents',
  'Player is registered with another team',
];

/// FA: one player to check. Photo, the app's automatic checks, what to
/// verify by eye, and the details. While pending: Reject and Approve.
class FaPlayerReviewScreen extends ConsumerWidget {
  const FaPlayerReviewScreen({super.key, required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerProvider(playerId));
    final player = playerAsync.value;

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Review player',
        leading: BackButton(onPressed: () => _leave(context, player)),
      ),
      bottomNavigationBar:
          player != null && player.status == ApprovalStatus.pending
              ? _ReviewActions(player: player)
              : null,
      body: playerAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (player) => player == null
            ? const EmptyView(
                icon: Icons.search_off_rounded,
                title: 'Player not found',
                message: 'The team may have removed this player.',
              )
            : _ReviewBody(player: player),
      ),
    );
  }
}

/// Back: to the screen we came from, or to the player's team if this
/// page was opened directly (e.g. a refreshed browser tab).
void _leave(BuildContext context, Player? player) {
  if (context.canPop()) {
    context.pop();
  } else if (player != null) {
    context.go(Routes.adminTeamPlayers(player.teamId));
  } else {
    context.go(Routes.adminPlayers);
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final sent = player.createdAt;
    final changed = player.updatedAt;
    final approvedAt = player.approvedAt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(player: player),
              const SizedBox(height: 22),

              // What the team changed since the FA last looked (2.3c)
              if (player.status == ApprovalStatus.pending &&
                  player.changes.isNotEmpty) ...[
                const SectionTitle('What the team changed'),
                _Changes(player: player),
                const SizedBox(height: 22),
              ],

              const SectionTitle('Checked by the app'),
              _Checks(player: player),
              _Duplicates(player: player),
              const SizedBox(height: 22),

              if (player.status == ApprovalStatus.pending) ...[
                const SectionTitle('Visual verification'),
                InfoBox(
                  icon: Icons.visibility_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  child: Text(
                    'Confirm that the face is clear and centred against a '
                    'plain background, and that the player appears to be '
                    'about ${player.age} years old. Where available, compare '
                    "with the player's identity document.",
                  ),
                ),
                const SizedBox(height: 22),
              ],

              const SectionTitle('Details'),
              TileGroup(
                children: [
                  DetailRow(
                    'Date of birth',
                    '${formatDate(player.dob)} (${player.age} years)',
                  ),
                  DetailRow('Position', player.position.display),
                  DetailRow(
                    'Team',
                    '${player.teamName} · ${player.category.label}',
                  ),
                  if (sent != null) DetailRow('Sent', formatDateTime(sent)),
                  // Shown when the team changed the player after sending
                  if (sent != null &&
                      changed != null &&
                      changed.difference(sent).inMinutes > 1)
                    DetailRow('Last changed', formatDateTime(changed)),
                  if (approvedAt != null)
                    DetailRow('Approved', formatDateTime(approvedAt)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Header: photo, name, team, status, ID, facts ─────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final code = player.playerCode;
    final reason = player.rejectionReason;
    final isPending = player.status == ApprovalStatus.pending;

    // The ID line: kept ID, or the next one from the counter
    final next = ref.watch(nextPlayerNumberProvider).value;
    final String idLabel;
    final String idValue;
    if (code != null) {
      idLabel = isPending ? 'Player ID (kept)' : 'Player ID';
      idValue = code;
    } else if (isPending) {
      idLabel = 'ID after approval';
      idValue = next == null
          ? '…'
          : playerCodeFor(next, DateTime.now().toUtc().year);
    } else {
      idLabel = 'Player ID';
      idValue = 'Not issued';
    }

    return TileGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            children: [
              PassportPhoto(
                name: player.fullName,
                url: player.photoUrl,
                width: 150,
              ),
              const SizedBox(height: 12),
              Text(
                player.fullName,
                textAlign: TextAlign.center,
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${player.teamName} · ${player.category.label}',
                textAlign: TextAlign.center,
                style:
                    textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              StatusBadge(status: player.status),
              const SizedBox(height: 12),
              Text(
                idLabel,
                style:
                    textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Text(
                idValue,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Fact(value: '#${player.jerseyNo}', label: 'Jersey'),
                  _Fact(value: player.positionGroup.code, label: 'Group'),
                  _Fact(value: '${player.age}', label: 'Age'),
                ],
              ),
              // A player approved before, changed by the team
              if (isPending && code != null) ...[
                const SizedBox(height: 12),
                InfoBox(
                  icon: Icons.history_rounded,
                  color: scheme.primary,
                  child: Text(
                    'Re-check: this player was approved before and the team '
                    'has changed their details (listed below). The player '
                    'keeps ID $code.',
                  ),
                ),
              ],
              if (player.status == ApprovalStatus.rejected &&
                  reason != null &&
                  reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                InfoBox(
                  icon: Icons.error_outline_rounded,
                  color: scheme.error,
                  child: Text('Rejected: $reason'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
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
    );
  }
}

// ── What the team changed (2.3c) ─────────────────────────────────────────

/// One row per change: "Jersey number   #10 → #14". The photo row shows
/// the old and new photos side by side.
class _Changes extends StatelessWidget {
  const _Changes({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // In a fixed order: name, date of birth, jersey, position, photo
    final keys = [
      for (final key in PlayerChange.labels.keys)
        if (player.changes.containsKey(key)) key,
    ];

    return TileGroup(
      children: [
        for (final key in keys)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: key == 'photo'
                ? _PhotoChange(
                    name: player.fullName,
                    change: player.changes[key]!,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 112,
                        child: Text(
                          PlayerChange.labels[key]!,
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: player.changes[key]!.from,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const TextSpan(text: '  →  '),
                              TextSpan(
                                text: player.changes[key]!.to,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _PhotoChange extends StatelessWidget {
  const _PhotoChange({required this.name, required this.change});

  final String name;
  final PlayerChange change;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget photo(String label, String url) => Column(
          children: [
            PassportPhoto(name: name, url: url, width: 104),
            const SizedBox(height: 6),
            Text(
              label,
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passport photo',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            photo('Before', change.from),
            Icon(Icons.arrow_forward_rounded, color: scheme.onSurfaceVariant),
            photo('Now', change.to),
          ],
        ),
      ],
    );
  }
}

// ── Possible duplicates (2.3c) ───────────────────────────────────────────

/// "No similar players found", or the players who might be the same
/// person, each with photo, team, ID and why it was flagged. Tap one to
/// open their review and compare.
class _Duplicates extends ConsumerWidget {
  const _Duplicates({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final all = ref.watch(allPlayersProvider).value;

    if (all == null) {
      return const CheckLine(
        ok: null,
        okText: '',
        waitingText: 'Looking for similar players…',
      );
    }

    // Only the same competition: the same person may play for a club's
    // Division and Juvenile sides (2.14)
    final matches = possibleDuplicates(
      player,
      all.where((p) => p.category == player.category).toList(),
    );
    if (matches.isEmpty) {
      return const CheckLine(
        ok: true,
        okText: 'No similar players found (name and date of birth)',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckLine(
          ok: false,
          okText: '',
          badText: matches.length == 1
              ? '1 possible duplicate. Compare the photos below.'
              : '${matches.length} possible duplicates. Compare the photos '
                  'below.',
        ),
        const SizedBox(height: 8),
        for (final match in matches) ...[
          Material(
            color: scheme.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.error, width: 1.5),
            ),
            child: InkWell(
              onTap: () => context.push(Routes.adminPlayer(match.player.id)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    PassportPhoto(
                      name: player.fullName,
                      url: player.photoUrl,
                      width: 56,
                    ),
                    const SizedBox(width: 6),
                    PassportPhoto(
                      name: match.player.fullName,
                      url: match.player.photoUrl,
                      width: 56,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.player.fullName,
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            [
                              match.player.teamName,
                              match.player.playerCode ?? 'No ID yet',
                            ].join(' · '),
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          Text(
                            'Born ${formatDate(match.player.dob)}',
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            match.reason,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Left: this player. Right: the possible match. If they are the '
          'same person, reject with "Player is registered with another team".',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── "Checked by the app" ─────────────────────────────────────────────────

class _Checks extends ConsumerWidget {
  const _Checks({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reserved =
        ref.watch(playerReservationsProvider(reservationKeyOf(player))).value;
    final hasPhoto = (player.photoUrl ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckLine(
          ok: hasPhoto,
          okText: 'Passport photo provided',
          badText: 'Passport photo is missing',
        ),
        CheckLine(
          ok: reserved?.key,
          okText: 'No duplicate registration (same name and date of birth)',
          badText: 'Duplicate check failed. This name and date of birth may '
              'be registered with another player.',
          waitingText: 'Checking for duplicate registrations…',
        ),
        CheckLine(
          ok: reserved?.jersey,
          okText: 'Jersey #${player.jerseyNo} reserved in this squad',
          badText: 'Jersey #${player.jerseyNo} is not reserved for this '
              'player',
          waitingText: 'Checking the jersey number…',
        ),
        CheckLine(
          ok: player.age >= _minDivisionAge,
          okText: 'Meets the Division minimum age ($_minDivisionAge)',
          badText: 'Below the Division minimum age ($_minDivisionAge)',
        ),
      ],
    );
  }
}

// ── Approve / Reject ─────────────────────────────────────────────────────

class _ReviewActions extends ConsumerStatefulWidget {
  const _ReviewActions({required this.player});

  final Player player;

  @override
  ConsumerState<_ReviewActions> createState() => _ReviewActionsState();
}

class _ReviewActionsState extends ConsumerState<_ReviewActions> {
  bool _busy = false;

  String? get _faUid => ref.read(authRepositoryProvider).currentUser?.uid;

  Future<void> _approve() async {
    final player = widget.player;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ApproveDialog(player: player),
    );
    final faUid = _faUid;
    if (ok != true || faUid == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final code = await ref
          .read(playerRepositoryProvider)
          .approve(player.id, faUid: faUid);
      if (!mounted) return;
      AppToast.success(context, '${player.fullName} approved · $code');
      _leave(context, player);
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final player = widget.player;
    final reason = await showReasonSheet(
      context,
      title: 'Reject ${player.fullName}?',
      message: "The team will see this reason on the player's record and "
          'may correct and resubmit.',
      fieldLabel: 'Reason for the team',
      quickReasons: _quickReasons,
    );
    final faUid = _faUid;
    if (reason == null || faUid == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(playerRepositoryProvider)
          .reject(player, reason: reason, faUid: faUid);
      if (!mounted) return;
      AppToast.success(
        context,
        'Player rejected. The team can see your reason.',
      );
      _leave(context, player);
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReviewActionsBar(
      approveLabel: 'Approve player',
      busy: _busy,
      onReject: _reject,
      onApprove: _approve,
    );
  }
}

/// "Approve Kwame Asante?" with the ID he will receive.
class _ApproveDialog extends ConsumerWidget {
  const _ApproveDialog({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final existing = player.playerCode;
    final next = ref.watch(nextPlayerNumberProvider).value;
    final code = existing ??
        (next == null ? '…' : playerCodeFor(next, DateTime.now().toUtc().year));

    return AlertDialog(
      title: Text('Approve ${player.fullName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  existing == null ? 'New player ID' : 'Player ID (kept)',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  code,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const DialogBullet(
            'The player becomes eligible for selection on team sheets',
          ),
          const DialogBullet(
            'This ID is permanent and remains with the player after any '
            'transfer',
          ),
        ],
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
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
