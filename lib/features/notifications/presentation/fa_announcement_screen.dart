import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/count_tabs.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/notifications/domain/announcement.dart';
import 'package:gedfa_connect/features/notifications/presentation/announcement_screen.dart';
import 'package:gedfa_connect/features/notifications/presentation/fa_announcements_screen.dart';
import 'package:gedfa_connect/features/people/data/people_repository.dart';
import 'package:gedfa_connect/features/settings/presentation/more_screen.dart'
    show PersonAvatar;
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:go_router/go_router.dart';

/// FA: one announcement, who has seen it (logos), unpin and delete.
class FaAnnouncementScreen extends ConsumerStatefulWidget {
  const FaAnnouncementScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<FaAnnouncementScreen> createState() =>
      _FaAnnouncementScreenState();
}

class _FaAnnouncementScreenState extends ConsumerState<FaAnnouncementScreen> {
  bool _showSeen = true;

  Future<void> _togglePin(Announcement a) async {
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .setPinned(a.id, !a.pinned);
      if (mounted) {
        AppToast.success(context, a.pinned ? 'Unpinned.' : 'Pinned.');
      }
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    }
  }

  Future<void> _delete(Announcement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this announcement?'),
        content: const Text(
          'It disappears for everyone. This cannot be undone.',
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
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(notificationsRepositoryProvider).delete(a.id);
      if (!mounted) return;
      AppToast.success(context, 'Announcement deleted.');
      context.go(Routes.adminAnnouncements);
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(announcementProvider(widget.id));
    final a = async.value;

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Announcement',
        subtitle: a == null ? null : 'Sent to ${a.to.label.toLowerCase()}',
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.adminAnnouncements),
        ),
        actions: [
          if (a != null)
            PopupMenuButton<String>(
              tooltip: 'More',
              iconColor: Colors.white,
              onSelected: (choice) =>
                  choice == 'pin' ? _togglePin(a) : _delete(a),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Text(a.pinned ? 'Unpin' : 'Pin to home screens'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (a) => a == null
            ? const EmptyView(
                icon: Icons.campaign_outlined,
                title: 'Not found',
                message: 'It may have been deleted.',
              )
            : AnnouncementView(announcement: a, footer: _seenSection(a)),
      ),
    );
  }

  Widget _seenSection(Announcement a) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final seen = ref.watch(announcementSeenProvider(a.id)).value ?? const {};

    // Who it was for: teams, or referees
    final List<({String key, String name, Team? team})> people;
    if (a.to == Audience.referees) {
      people = [
        for (final m in ref.watch(membersProvider).value ?? const [])
          if (m.role == UserRole.referee)
            (key: m.uid, name: m.name, team: null),
      ];
    } else {
      people = [
        for (final t in teamsFor(a.to, ref.watch(allTeamsProvider).value ?? const []))
          (key: t.id, name: t.name, team: t),
      ];
    }
    final seenList = people.where((p) => seen.containsKey(p.key)).toList();
    final notYet = people.where((p) => !seen.containsKey(p.key)).toList();
    final shown = _showSeen ? seenList : notYet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        CountTabs<bool>(
          tabs: [
            CountTab(value: true, label: 'Seen', count: seenList.length),
            CountTab(
              value: false,
              label: 'Not yet',
              count: notYet.length,
              highlight: notYet.isNotEmpty,
            ),
          ],
          selected: _showSeen,
          onChanged: (value) => setState(() => _showSeen = value),
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _showSeen ? 'Nobody has opened it yet.' : 'Everyone has seen it.',
              textAlign: TextAlign.center,
              style:
                  textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 14,
            children: [
              for (final p in shown)
                SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      Opacity(
                        opacity: _showSeen ? 1 : 0.55,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _showSeen
                                  ? const Color(0xFF1E8E5A)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: p.team == null
                              ? PersonAvatar(name: p.name, size: 44)
                              : TeamLogo(
                                  label: initialsFor(p.team!.name),
                                  color: p.team!.logoColor,
                                  url: p.team!.logoUrl,
                                  size: 44,
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _showSeen
                            ? _time(seen[p.key])
                            : 'Not yet',
                        style: textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 14),
        Text(
          'Only FA admins see who has read an announcement. A team counts as '
          'seen when its admin opens the announcement.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _time(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
      return '$h:${local.minute.toString().padLeft(2, '0')} '
          '${local.hour < 12 ? 'am' : 'pm'}';
    }
    return formatDate(local);
  }
}
