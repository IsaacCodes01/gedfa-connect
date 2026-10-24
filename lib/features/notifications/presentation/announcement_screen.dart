import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/notifications/domain/announcement.dart';
import 'package:gedfa_connect/features/settings/presentation/more_screen.dart'
    show PersonAvatar;

/// One announcement, as a team (or referee) reads it. Opening it marks it
/// "seen" for the team (team admins) or for me (referees), once.
class AnnouncementScreen extends ConsumerStatefulWidget {
  const AnnouncementScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends ConsumerState<AnnouncementScreen> {
  bool _marked = false;

  /// Tell the FA we've seen it (best effort: no error shown).
  void _markSeen() {
    if (_marked) return;
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final key = user.role == UserRole.teamAdmin ? user.teamId : user.uid;
    if (key == null || key.isEmpty || user.role == UserRole.faAdmin) return;
    _marked = true;
    ref
        .read(notificationsRepositoryProvider)
        .markSeen(widget.id, key: key, by: user.uid)
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(announcementProvider(widget.id));

    return Scaffold(
      appBar: const GedfaAppBar(title: 'Announcement'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (a) {
          if (a == null) {
            return const EmptyView(
              icon: Icons.campaign_outlined,
              title: 'Not found',
              message: 'The FA may have removed this announcement.',
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen());
          return AnnouncementView(announcement: a);
        },
      ),
    );
  }
}

/// The announcement itself: labels, title, who sent it, the text.
/// Also used on the FA's screen.
class AnnouncementView extends StatelessWidget {
  const AnnouncementView({
    super.key,
    required this.announcement,
    this.footer,
  });

  final Announcement announcement;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final a = announcement;
    final when = a.createdAt;

    Widget label(String text, Color bg, Color ink) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              color: ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        );
    final soft = scheme.primary.withValues(alpha: 0.12);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (a.important)
                    label(
                      'Important',
                      scheme.error.withValues(alpha: 0.12),
                      scheme.error,
                    ),
                  if (a.pinned) label('Pinned', soft, scheme.primary),
                  label(a.to.label, soft, scheme.primary),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                a.title,
                style:
                    textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  PersonAvatar(name: a.createdByName, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.createdByName,
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Gomoa East District FA'
                          '${when == null ? '' : ' · ${formatDateTime(when)}'}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.outline),
                ),
                child: SelectableText(
                  a.body,
                  style: textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),
              const SizedBox(height: 12),
              ?footer,
            ],
          ),
        ),
      ],
    );
  }
}
