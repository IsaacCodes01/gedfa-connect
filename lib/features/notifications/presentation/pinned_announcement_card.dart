import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:go_router/go_router.dart';

/// The newest pinned FA announcement, on top of the team's Squad tab.
/// × hides it for me until the FA pins a new one.
class PinnedAnnouncementCard extends ConsumerWidget {
  const PinnedAnnouncementCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(pinnedAnnouncementProvider);
    if (a == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final accent = a.important ? scheme.error : scheme.primary;

    Future<void> hide() async {
      final uid = ref.read(appUserProvider).value?.uid;
      final mark = ref.read(readMarkProvider).value;
      if (uid == null || mark == null) return;
      try {
        await ref
            .read(notificationsRepositoryProvider)
            .hidePinned(uid, mark, a.id);
      } catch (_) {
        // Not important enough for an error message
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: accent, width: 1.5),
        ),
        child: InkWell(
          onTap: () => context.push(Routes.teamAnnouncement(a.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.push_pin_outlined, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'PINNED · FROM THE FA',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: hide,
                      tooltip: 'Hide until there is a new announcement',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                Text(
                  a.title,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    a.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Read the announcement →',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
