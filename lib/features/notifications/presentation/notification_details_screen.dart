import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/notifications/presentation/widgets/note_look.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:go_router/go_router.dart';

/// Notification details (3.0f, N2): the whole note, every name, who it is
/// from, and a button to where it is about. Opening it marks only this
/// note read.
class NotificationDetailsScreen extends ConsumerStatefulWidget {
  const NotificationDetailsScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<NotificationDetailsScreen> createState() =>
      _NotificationDetailsScreenState();
}

class _NotificationDetailsScreenState
    extends ConsumerState<NotificationDetailsScreen> {
  bool _marked = false;

  /// Read before, then changed: worked out once, before it is marked read.
  bool? _changed;

  /// Marks it read once (best effort: no error shown).
  void _markRead(AppNotification note) {
    if (_marked) return;
    final uid = ref.read(appUserProvider).value?.uid;
    final mark = ref.read(readMarkProvider).value;
    final time = note.updatedAt;
    if (uid == null || mark == null || time == null) return;
    _marked = true;
    if (!mark.isUnread(note.id, time)) return;
    ref
        .read(notificationsRepositoryProvider)
        .markRead(
          uid,
          mark,
          id: note.id,
          time: time,
          keep: ref.read(bellIdsProvider),
        )
        .catchError((_) {});
  }

  /// The club account a team was registered with (the FA's team page).
  String? _requestUidOf(String teamId) => ref
      .watch(allTeamsProvider)
      .value
      ?.where((t) => t.id == teamId)
      .firstOrNull
      ?.requestUid;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myNotificationProvider(widget.id));
    final mark = ref.watch(readMarkProvider).value;
    final note = async.value;

    final Widget body;
    if (async.hasError) {
      body = ErrorView(message: appErrorMessage(async.error!));
    } else if (!async.hasValue || mark == null) {
      body = const LoadingView();
    } else if (note == null) {
      body = const EmptyView(
        icon: Icons.notifications_off_outlined,
        title: 'Not found',
        message: 'This notification is no longer in your bell.',
      );
    } else {
      _changed ??= mark.changedSinceRead(note.id, note.updatedAt);
      WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(note));
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          ResponsiveCenter(
            maxWidth: 640,
            child: _DetailsCard(note: note, changed: _changed!),
          ),
        ],
      );
    }

    final target = note == null
        ? null
        : noteTarget(
            note,
            requestUid:
                note.audience == 'fa' ? _requestUidOf(note.teamId) : null,
          );

    return Scaffold(
      appBar: GedfaAppBar(title: 'Notification', subtitle: note?.title),
      body: body,
      bottomNavigationBar: target == null
          ? null
          : _OpenBar(
              label: target.button,
              onOpen: () => context.go(target.target),
            ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.note, required this.changed});

  final AppNotification note;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, bg, ink) = noteIcon(context, noteTarget(note).look);
    final time = note.updatedAt;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 28, color: ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          'From ${note.sender}',
                          if (time != null)
                            '${formatShortDate(time)}, ${formatTime(time)}',
                        ].join(' · '),
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (changed) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3D3410) : AppColors.pendingBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'New since you last read it, so it showed as unread again.',
                  style: textTheme.bodySmall?.copyWith(
                    color:
                        isDark ? const Color(0xFFF5D25B) : AppColors.pendingText,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              note.detailText,
              style: textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
            if (note.listsNames) ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (final (i, name) in note.names.indexed)
                      Container(
                        decoration: BoxDecoration(
                          border: i == 0
                              ? null
                              : Border(
                                  top: BorderSide(color: scheme.outline),
                                ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _nameIcon(note.kind),
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(name, style: textTheme.bodyMedium),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF123D2B) : AppColors.approvedBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.done_all_rounded,
                    size: 15,
                    color: isDark
                        ? const Color(0xFF7BE3B0)
                        : AppColors.approvedText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Status: Read',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF7BE3B0)
                          : AppColors.approvedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The icon on each name's line: a player, a match, a payment…
  static IconData _nameIcon(NotificationKind kind) => switch (kind) {
        NotificationKind.fixtureAdded ||
        NotificationKind.fixtureChanged ||
        NotificationKind.fixturePostponed ||
        NotificationKind.fixtureCancelled =>
          Icons.sports_soccer_outlined,
        NotificationKind.paymentConfirmed ||
        NotificationKind.paymentNotFound ||
        NotificationKind.paymentSent =>
          Icons.payments_outlined,
        NotificationKind.teamRequest => Icons.shield_outlined,
        NotificationKind.teamUpdated ||
        NotificationKind.changeRequested ||
        NotificationKind.changeApproved ||
        NotificationKind.changeRefused ||
        NotificationKind.teamCorrected ||
        NotificationKind.registrationChanged =>
          Icons.edit_note_rounded,
        _ => Icons.person_outline_rounded,
      };
}

/// The button at the bottom, named after where it goes ("Open Squad").
class _OpenBar extends StatelessWidget {
  const _OpenBar({required this.label, required this.onOpen});

  final String label;
  final VoidCallback onOpen;

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
          // heightFactor: 1, or the bar would fill the screen
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FilledButton.icon(
                onPressed: onOpen,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(label),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
