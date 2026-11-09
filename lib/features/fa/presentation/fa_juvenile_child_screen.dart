import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/screening/data/screening_repository.dart';
import 'package:gedfa_connect/features/screening/presentation/widgets/screening_countdown.dart';

/// FA: one juvenile child, read only (Isaac, 3 Nov 2026). Opened from
/// Players › Juvenile › a team. Shows what the FA needs on the screening
/// day: the big photo, date of birth, group, parent, and the result.
/// The decision itself is made in More › Juvenile screening.
class FaJuvenileChildScreen extends ConsumerWidget {
  const FaJuvenileChildScreen({super.key, required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerProvider(playerId));
    final player = playerAsync.value;

    void back() => context.goBack(player == null
        ? Routes.adminPlayersJuvenile
        : Routes.adminTeamJuvenile(player.teamId));

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Juvenile player',
        subtitle: player?.teamName,
        leading: BackButton(onPressed: back),
      ),
      // Board J6: "Screen player" while the child waits (2.14d)
      bottomNavigationBar: player != null && player.isWaitingForScreening
          ? _ScreenButton(player: player)
          : null,
      body: playerAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (player) => player == null
            ? const EmptyView(
                icon: Icons.person_off_outlined,
                title: 'Player not found',
                message: 'The team may have removed this player.',
              )
            : _Body(player: player),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final group = player.ageGroup;
    final own = AgeGroup.ownGroup(player.dob);
    final age = AgeGroup.seasonAge(player.dob);
    final year = Season.startYear(Season.current);
    final guardian = player.guardian;

    // The next screening day for this child's group, if waiting
    final nextDay = !player.isWaitingForScreening
        ? null
        : (ref.watch(upcomingScreeningsProvider).value ?? const [])
            .where((d) => d.groups.contains(group))
            .firstOrNull;

    final (statusTitle, statusText, bg, ink) = switch (player.status) {
      ApprovalStatus.pending => (
          'Waiting for screening',
          nextDay == null
              ? 'No screening day for ${group?.label ?? 'this group'} yet. '
                  'Add one in More › Juvenile screening.'
              : 'Next screening: ${nextDay.dateText} · ${nextDay.timeText} · '
                  '${nextDay.venue}',
          isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC),
          isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700),
        ),
      ApprovalStatus.approved => (
          'Passed · ${player.playerCode ?? ''}',
          player.approvedAt == null
              ? 'Passed at screening.'
              : 'Passed at screening on ${formatDate(player.approvedAt!)}.',
          isDark ? const Color(0xFF123D2B) : AppColors.approvedBg,
          isDark ? const Color(0xFF7BE3B0) : AppColors.approvedText,
        ),
      ApprovalStatus.rejected => (
          player.notEligible
              ? 'Not eligible for Juvenile'
              : 'Sent back to the team to correct',
          player.rejectionReason ?? 'No reason was given.',
          isDark ? const Color(0xFF4A1820) : AppColors.rejectedBg,
          isDark ? const Color(0xFFFF9DA6) : AppColors.rejectedText,
        ),
    };

    Widget row(String label, String value, {String? note}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (note != null)
                      Text(
                        note,
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: PassportPhoto(
                  name: player.fullName,
                  url: player.photoUrl,
                  width: 150,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                player.fullName,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${player.teamName} · #${player.jerseyNo} · '
                '${player.position.code}',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700, color: ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: textTheme.bodySmall?.copyWith(color: ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.outline),
                ),
                child: Column(
                  children: [
                    row(
                      'Date of birth',
                      formatDate(player.dob),
                      note: '$age in $year',
                    ),
                    row(
                      'Age group',
                      group?.label ?? '-',
                      note: own == null
                          ? null
                          : own == group
                              ? 'Own age group'
                              : '${own.label} age, in the ${group?.label} squad',
                    ),
                    if (guardian != null)
                      row(
                        guardian.relation.label,
                        guardian.name,
                        note: guardian.phone,
                      ),
                    row('Position', player.position.label),
                    if (player.createdAt != null)
                      row('Registered', formatDateTime(player.createdAt!)),
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

/// "Screen player" (board J6): opens the screening screen with this child
/// first. Locked before the day starts, with a countdown; a note when no
/// screening day covers the child's group yet.
class _ScreenButton extends ConsumerStatefulWidget {
  const _ScreenButton({required this.player});

  final Player player;

  @override
  ConsumerState<_ScreenButton> createState() => _ScreenButtonState();
}

class _ScreenButtonState extends ConsumerState<_ScreenButton> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final player = widget.player;
    final group = player.ageGroup;
    final now = DateTime.now();
    final days = [
      for (final d in ref.watch(upcomingScreeningsProvider).value ?? const [])
        if (d.groups.contains(group)) d,
    ];
    // A day that is open now comes first, else the next one
    final day = days.where((d) => d.hasStarted(now)).firstOrNull ??
        days.firstOrNull;
    final openDay = day != null && day.hasStarted(now) ? day : null;
    final open = openDay != null;
    final firstName = player.fullName.split(' ').first;
    final noteStyle =
        textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          // heightFactor: 1, or the bar would fill the screen
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: openDay == null
                        ? null
                        : () => context.open(Routes.adminScreeningDay(
                              openDay.id,
                              childId: player.id,
                            )),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF006B3F),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      open ? Icons.fact_check_outlined : Icons.lock_outline,
                    ),
                    label: Text(
                      open
                          ? 'Screen player'
                          : day == null
                              ? 'No screening day for '
                                  '${group?.label ?? 'this group'} yet'
                              : 'Screening opens ${day.dateText}, '
                                  '${day.timeText}',
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (open)
                    Text(
                      'Opens the screening screen with $firstName first.',
                      textAlign: TextAlign.center,
                      style: noteStyle,
                    )
                  else if (day == null)
                    Text(
                      'Add one in More › Juvenile screening.',
                      textAlign: TextAlign.center,
                      style: noteStyle,
                    )
                  else
                    Center(
                      child: ScreeningCountdown(
                        key: ValueKey(day.id),
                        startsAt: day.startsAt,
                        prefix: 'Opens by itself in ',
                        style: noteStyle,
                        onStarted: () {
                          if (mounted) setState(() {});
                        },
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
