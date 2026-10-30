import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/count_tabs.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/notifications/domain/announcement.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:go_router/go_router.dart';

enum _Tab { all, fromFa }

enum _Look { ok, no, fa, team, ref }

/// One line in the list: a grouped notification or an announcement.
class _Item {
  const _Item({
    required this.look,
    required this.title,
    required this.body,
    required this.time,
    required this.onTap,
    this.important = false,
    this.isAnnouncement = false,
  });

  final _Look look;
  final String title;
  final String body;
  final DateTime? time;
  final VoidCallback onTap;
  final bool important;
  final bool isAnnouncement;
}

/// The bell's list (2.8), for teams and the FA. Grouped by day, newest
/// first. Similar events on the same day are already ONE notification.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _Tab _tab = _Tab.all;

  Future<void> _markAllRead() async {
    final uid = ref.read(appUserProvider).value?.uid;
    if (uid == null) return;
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead(uid);
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFa = ref.watch(myAudienceProvider) == 'fa';
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final announcementsAsync = ref.watch(myAnnouncementsProvider);
    final mark = ref.watch(readMarkProvider).value ?? const ReadMark();
    final unread = ref.watch(unreadCountProvider);

    Widget body;
    final error = notificationsAsync.error ?? announcementsAsync.error;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!notificationsAsync.hasValue || !announcementsAsync.hasValue) {
      body = const LoadingView();
    } else {
      body = _body(
        isFa: isFa,
        notifications: notificationsAsync.requireValue,
        announcements: announcementsAsync.requireValue,
        mark: mark,
      );
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Notifications',
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                shape: const StadiumBorder(),
              ),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _body({
    required bool isFa,
    required List<AppNotification> notifications,
    required List<Announcement> announcements,
    required ReadMark mark,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final items = <_Item>[
      for (final n in notifications) _fromNotification(n),
      for (final a in announcements)
        _Item(
          look: _Look.fa,
          title: a.title,
          body: a.body,
          time: a.createdAt,
          important: a.important,
          isAnnouncement: true,
          onTap: () => context.push(
            isFa ? Routes.adminAnnouncement(a.id) : Routes.teamAnnouncement(a.id),
          ),
        ),
    ]..sort((a, b) {
        final zero = DateTime.fromMillisecondsSinceEpoch(0);
        return (b.time ?? zero).compareTo(a.time ?? zero);
      });

    bool isNew(_Item i) => mark.isNew(i.time) && !(isFa && i.isAnnouncement);
    final shown = _tab == _Tab.all
        ? items
        : items.where((i) => i.isAnnouncement).toList();

    // Today / This week / Earlier
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String groupOf(_Item i) {
      final t = i.time?.toLocal();
      if (t == null || !t.isBefore(today)) return 'Today';
      if (today.difference(DateTime(t.year, t.month, t.day)).inDays < 7) {
        return 'This week';
      }
      return 'Earlier';
    }

    final groups = <String, List<_Item>>{};
    for (final item in shown) {
      groups.putIfAbsent(groupOf(item), () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CountTabs<_Tab>(
                tabs: [
                  CountTab(
                    value: _Tab.all,
                    label: 'All',
                    count: items.where(isNew).length,
                    highlight: true,
                  ),
                  CountTab(
                    value: _Tab.fromFa,
                    label: isFa ? 'Announcements' : 'From the FA',
                    count: items
                        .where((i) => i.isAnnouncement && isNew(i))
                        .length,
                    highlight: true,
                  ),
                ],
                selected: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: EmptyView(
                    icon: Icons.notifications_none_rounded,
                    title: 'Nothing yet',
                    message: 'Approvals, rejections and FA announcements '
                        'will appear here.',
                  ),
                )
              else
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  for (final item in entry.value) ...[
                    _ItemCard(item: item, unread: isNew(item)),
                    const SizedBox(height: 8),
                  ],
                ],
              const SizedBox(height: 10),
              Text(
                'Similar news on the same day is grouped into one '
                'notification, so approving 20 players is 1 notification, '
                'not 20.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Where each kind of notification goes when tapped, and how it looks.
  _Item _fromNotification(AppNotification n) {
    final (look, target) = switch (n.kind) {
      NotificationKind.playersApproved => (_Look.ok, Routes.team),
      NotificationKind.playersRejected => (_Look.no, Routes.team),
      NotificationKind.teamApproved => (_Look.team, Routes.team),
      // One club: its request. Several (grouped): the list of requests.
      NotificationKind.teamRequest => (
          _Look.team,
          n.people == 1 ? Routes.adminRequest(n.teamId) : Routes.admin,
        ),
      NotificationKind.playersSubmitted =>
        (_Look.ok, Routes.adminTeamPlayers(n.teamId)),
      NotificationKind.playersResubmitted =>
        (_Look.no, Routes.adminTeamPlayers(n.teamId)),
      NotificationKind.inviteAccepted => (_Look.ref, Routes.adminPeople),
      NotificationKind.paymentConfirmed => (_Look.ok, Routes.teamFee),
      NotificationKind.paymentNotFound => (_Look.no, Routes.teamFee),
      NotificationKind.feeReminder => (_Look.fa, Routes.teamFee),
      NotificationKind.paymentSent =>
        (_Look.team, Routes.adminTeamFee(n.teamId)),
      NotificationKind.registrationChanged =>
        (_Look.fa, Routes.adminLeagueSettings),
    };
    return _Item(
      look: look,
      title: n.title,
      body: n.body,
      time: n.updatedAt,
      onTap: () => context.go(target),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.unread});

  final _Item item;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (icon, bg, ink) = switch (item.look) {
      _Look.ok => (
          Icons.check_rounded,
          isDark ? const Color(0xFF123D2B) : AppColors.approvedBg,
          isDark ? const Color(0xFF7BE3B0) : AppColors.approvedText,
        ),
      _Look.no => (
          Icons.close_rounded,
          isDark ? const Color(0xFF4A1820) : AppColors.rejectedBg,
          isDark ? const Color(0xFFFF9DA6) : AppColors.rejectedText,
        ),
      _Look.fa => (
          Icons.campaign_outlined,
          isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3EEFA),
          isDark ? const Color(0xFF9CCBFA) : AppColors.deepBlue,
        ),
      _Look.team => (
          Icons.shield_outlined,
          isDark ? const Color(0xFF3D3410) : AppColors.pendingBg,
          isDark ? const Color(0xFFF5D25B) : AppColors.pendingText,
        ),
      _Look.ref => (
          Icons.how_to_reg_outlined,
          isDark ? const Color(0xFF2A2147) : const Color(0xFFEEE8FF),
          isDark ? const Color(0xFFC9B8FF) : const Color(0xFF4B2E9E),
        ),
    };

    final background = unread
        ? (isDark ? const Color(0xFF172C47) : const Color(0xFFF3F8FE))
        : scheme.surface;

    return Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.important ? scheme.error : scheme.outline,
          width: item.important ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: bg,
                child: Icon(icon, size: 20, color: ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _ago(item.time),
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (item.important) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'IMPORTANT',
                          style: TextStyle(
                            color: scheme.error,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Semantics(
                    label: 'New',
                    child: Icon(Icons.circle, size: 9, color: scheme.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "5m", "2h", "3d", then the date.
  static String _ago(DateTime? time) {
    if (time == null) return '';
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return formatDate(time.toLocal());
  }
}
