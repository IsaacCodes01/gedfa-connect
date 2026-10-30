import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/pitch_lines_painter.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/core/widgets/status_badge.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/app/routes.dart';

class PlayerDetailsScreen extends ConsumerWidget {
  const PlayerDetailsScreen({super.key, required this.playerId});

  final String playerId;

    void _edit(BuildContext context) =>
      context.go(Routes.editPlayer(playerId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerProvider(playerId));
    final player = playerAsync.value;

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Player',
        actions: [
          if (player != null)
            IconButton(
              tooltip: 'Edit player',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context),
            ),
        ],
      ),
      bottomNavigationBar: player == null
          ? null
          : _BottomButton(player: player, onPressed: () => _edit(context)),
      body: playerAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: appErrorMessage(error),
          onRetry: () => ref.invalidate(playerProvider(playerId)),
        ),
        data: (player) => player == null
            ? const EmptyView(
                icon: Icons.person_off_outlined,
                title: 'Player not found',
                message: 'This player may have been removed.',
              )
            : _Details(player: player),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rejected = player.status == ApprovalStatus.rejected;
    final reason = player.rejectionReason;

    const bandHeight = 96.0;
    const photoWidth = 124.0;
    const photoTop = 18.0;

    final reviewDate = player.status == ApprovalStatus.approved
        ? player.approvedAt
        : (rejected ? player.updatedAt : null);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Blue pitch strip with the passport photo overlapping it
        SizedBox(
          height: photoTop + photoWidth * 4 / 3,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: double.infinity,
                height: bandHeight,
                color: isDark ? AppColors.heroDark : AppColors.brandBlue,
                child: const CustomPaint(
                  painter: PitchLinesPainter(),
                  size: Size(double.infinity, bandHeight),
                ),
              ),
              Positioned(
                top: photoTop,
                child: PassportPhoto(
                  name: player.fullName,
                  url: player.photoUrl,
                  width: photoWidth,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  player.fullName,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(status: player.status),
                    _IdChip(code: player.playerCode),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _FactTile(value: '#${player.jerseyNo}', label: 'Jersey'),
                    const SizedBox(width: 10),
                    _FactTile(
                      value: player.position.code,
                      label: player.positionGroup.label,
                    ),
                    const SizedBox(width: 10),
                    _FactTile(value: '${player.age}', label: 'Age'),
                  ],
                ),
                if (rejected) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.rejectedBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.rejectedText, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Not approved by the FA',
                                style: textTheme.titleSmall?.copyWith(
                                  color: AppColors.rejectedText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                reason == null || reason.isEmpty
                                    ? 'No reason was given.'
                                    : reason,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.rejectedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: Column(
                    children: [
                      _Row(
                        label: 'Player ID',
                        value: player.playerCode ?? 'Not given yet',
                        note: player.playerCode == null
                            ? 'Given when the FA approves'
                            : null,
                        first: true,
                      ),
                      _Row(label: 'Team', value: player.teamName),
                      _Row(
                        label: 'Competition',
                        value: player.category.label,
                        note: player.category == Competition.division
                            ? 'Third Division · senior'
                            : 'Youth league',
                      ),
                      // Juvenile (2.14): age group and parent or guardian
                      if (player.ageGroup case final group?)
                        _Row(
                          label: 'Age group',
                          value: group.label,
                          note: AgeGroup.ownGroup(player.dob) == group
                              ? 'Own age group'
                              : 'Playing up (own group: '
                                  '${AgeGroup.ownGroup(player.dob)?.label ?? '-'})',
                        ),
                      if (player.guardian case final guardian?)
                        _Row(
                          label: guardian.relation.label,
                          value: guardian.name,
                          note: '${guardian.phone} · only your team and the '
                              'FA see this',
                        ),
                      if (player.isWaitingForScreening)
                        const _Row(
                          label: 'Screening',
                          value: 'Waiting',
                          note: 'Bring the player to the FA screening day '
                              'with a birth certificate',
                        ),
                      _Row(
                        label: 'Position',
                        value: player.position.code,
                        note: '${player.position.label} · '
                            '${player.positionGroup.label}',
                      ),
                      _Row(label: 'Jersey number', value: '#${player.jerseyNo}'),
                      _Row(
                        label: 'Date of birth',
                        value: formatDate(player.dob),
                        note: 'Only your team and the FA see this',
                      ),
                      if (player.createdAt != null)
                        _Row(
                          label: 'Registered',
                          value: formatDateTime(player.createdAt!),
                        ),
                      if (reviewDate != null)
                        _Row(
                          label: rejected ? 'Rejected' : 'Approved',
                          value: formatDateTime(reviewDate),
                          note: 'by the FA',
                        ),
                    ],
                  ),
                ),
                if (player.isApproved) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Changing the name, date of birth, jersey number or '
                          'photo sends the player back to the FA for approval.',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IdChip extends StatelessWidget {
  const _IdChip({required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            code ?? 'ID after approval',
            style: TextStyle(
              color: scheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.note,
    this.first = false,
  });

  final String label;
  final String value;
  final String? note;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final note = this.note;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (note != null)
                  Text(
                    note,
                    textAlign: TextAlign.right,
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  const _BottomButton({required this.player, required this.onPressed});

  final Player player;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rejected = player.status == ApprovalStatus.rejected;

    final button = rejected
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Fix and send again'),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit details'),
          );

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
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(width: double.infinity, child: button),
            ),
          ),
        ),
      ),
    );
  }
}
