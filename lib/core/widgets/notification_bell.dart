import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:go_router/go_router.dart';

/// Where the bell, its notes and the matches live for each role (3.5b:
/// referees have their own area). Like the signposts in each part of the
/// building: same words, different rooms.
class BellPlaces {
  const BellPlaces({
    required this.bell,
    required this.note,
    required this.announcement,
    required this.home,
    required this.match,
    required this.matches,
  });

  final String bell;
  final String Function(String id) note;
  final String Function(String id) announcement;
  final String home;

  /// A match, and the list of my matches.
  final String Function(String id) match;
  final String matches;

  static BellPlaces of(UserRole? role) => switch (role) {
    UserRole.faAdmin => const BellPlaces(
      bell: Routes.adminNotifications,
      note: Routes.adminNote,
      announcement: Routes.adminBellAnnouncement,
      home: Routes.adminHome,
      match: Routes.adminMatch,
      matches: Routes.adminFixtures,
    ),
    UserRole.referee => const BellPlaces(
      bell: Routes.refereeNotifications,
      note: Routes.refereeNote,
      announcement: Routes.refereeAnnouncement,
      home: Routes.referee,
      match: Routes.refereeMatch,
      matches: Routes.refereeMatches,
    ),
    _ => const BellPlaces(
      bell: Routes.teamNotifications,
      note: Routes.teamNote,
      announcement: Routes.teamAnnouncement,
      home: Routes.teamHome,
      match: Routes.teamMatch,
      matches: Routes.teamFixtures,
    ),
  };
}

/// My [BellPlaces], from my role.
final bellPlacesProvider = Provider<BellPlaces>((ref) {
  return BellPlaces.of(ref.watch(appUserProvider).value?.role);
});

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
        context.go(ref.read(bellPlacesProvider).home);
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
    final places = ref.watch(bellPlacesProvider);

    return IconButton(
      onPressed: () {
        ref
            .read(bellOriginProvider.notifier)
            .set(GoRouterState.of(context).uri.toString());
        context.push(places.bell);
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
