import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:go_router/go_router.dart';

/// The bell on the right of the main app bars (team and FA), with a red
/// number for unread notifications. Opens Notifications (2.8).
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final isFa = ref.watch(myAudienceProvider) == 'fa';

    return IconButton(
      onPressed: () => context
          .push(isFa ? Routes.adminNotifications : Routes.teamNotifications),
      tooltip: unread == 0 ? 'Notifications' : 'Notifications, $unread new',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        backgroundColor: const Color(0xFFCE1126),
        textColor: Colors.white,
        child: Icon(
          unread > 0
              ? Icons.notifications_rounded
              : Icons.notifications_none_rounded,
        ),
      ),
    );
  }
}
