import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/features/screening/data/screening_repository.dart';
import 'package:go_router/go_router.dart';

/// Board J5: "Next screening: Sat 14 Nov · Fetteh Park   Days ›" on the
/// FA's Players › Juvenile. With no day set: "No screening day set yet
/// Add ›". Both open More › Juvenile screening.
class NextScreeningStrip extends ConsumerWidget {
  const NextScreeningStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3EEFA);
    final ink = isDark ? const Color(0xFFCFE4FB) : const Color(0xFF0B3F7A);

    final daysAsync = ref.watch(upcomingScreeningsProvider);
    if (!daysAsync.hasValue) return const SizedBox.shrink();
    final next = daysAsync.requireValue.firstOrNull;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(Routes.adminScreening),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  next == null
                      ? const TextSpan(text: 'No screening day set yet')
                      : TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Next screening: ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: '${next.dateText} · ${next.venue}'),
                          ],
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall
                      ?.copyWith(fontSize: 12.5, color: ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                next == null ? 'Add ›' : 'Days ›',
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF7DBBFA) : scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
