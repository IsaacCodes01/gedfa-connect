import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/screening/data/screening_repository.dart';
import 'package:gedfa_connect/features/screening/domain/screening_day.dart';
import 'package:gedfa_connect/features/screening/presentation/widgets/screening_countdown.dart';

/// Board J1: the blue "JUVENILE SCREENING" card on the team's Squad tab
/// (Juvenile side). One card per coming screening day; each one goes away
/// the day after. Nothing shows when no day is set.
class ScreeningCards extends ConsumerWidget {
  const ScreeningCards({super.key, required this.waiting});

  /// This team's children waiting for screening, per age group
  final Map<AgeGroup, int> waiting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final days = [
      for (final day in ref.watch(upcomingScreeningsProvider).value ?? const [])
        if (day.isShownOn(now)) day,
    ];
    if (days.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days) ...[
          _Card(day: day, waiting: waiting),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.day, required this.waiting});

  final ScreeningDay day;
  final Map<AgeGroup, int> waiting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onPrimary;
    final mine = day.groups.fold(0, (sum, g) => sum + (waiting[g] ?? 0));
    // "Bring: …" only when the FA typed something
    final bring = day.note.isEmpty ? '' : ' Bring: ${day.note}';

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JUVENILE SCREENING',
              style: TextStyle(
                color: ink.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.dateText} · ${day.timeText} · ${day.venue}',
              style: TextStyle(
                color: ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            // "⏱ Starts in 2 days 3 h", then "Happening now" (Isaac,
            // 3 Nov 2026). Ticks every second, like the FA's.
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: ink),
                const SizedBox(width: 6),
                ScreeningCountdown(
                  key: ValueKey(day.id),
                  startsAt: day.startsAt,
                  prefix: 'Starts in ',
                  nowText: 'Happening now',
                  style: TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${day.groupsText} players.$bring Only children screened '
              'that day can play this season.',
              style: TextStyle(
                color: ink.withValues(alpha: 0.92),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            if (mine > 0) ...[
              const SizedBox(height: 6),
              Text(
                mine == 1
                    ? 'You have 1 child waiting for this day.'
                    : 'You have $mine children waiting for this day.',
                style: TextStyle(
                  color: ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
