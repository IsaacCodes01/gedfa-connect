import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:go_router/go_router.dart';

/// Where the bell was opened from (Home, Fixtures, a match…). The bell's ←
/// goes back there, even after a note opened another tab and ← came back
/// through the note (3.0f2): the bell's address sits under Teams (FA) or
/// Squad (team), so a plain ← would land there instead.
class BellOrigin extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String location) => state = location;
}

final bellOriginProvider =
    NotifierProvider<BellOrigin, String?>(BellOrigin.new);

/// The bell's ← (and the phone's Back): back where the bell was opened
/// from, or, after a refresh on the web, the tab's main screen.
class BellBackButton extends ConsumerWidget {
  const BellBackButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void back() {
      final origin = ref.read(bellOriginProvider);
      if (origin != null) {
        context.go(origin);
      } else {
        final isFa = ref.read(myAudienceProvider) == 'fa';
        context.go(isFa ? Routes.adminHome : Routes.teamHome);
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: BackButton(onPressed: back),
    );
  }
}

/// The bell on the right of the main app bars (team and FA), with a red
/// number for unread notifications. Opens Notifications (2.8).
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final isFa = ref.watch(myAudienceProvider) == 'fa';

    return IconButton(
      onPressed: () {
        ref
            .read(bellOriginProvider.notifier)
            .set(GoRouterState.of(context).uri.toString());
        context.push(isFa ? Routes.adminNotifications : Routes.teamNotifications);
      },
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
