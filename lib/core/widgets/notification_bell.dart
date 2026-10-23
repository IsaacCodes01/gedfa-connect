import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';

/// The bell on the right of the main app bars (team and FA).
///
/// For now it opens a "Coming soon" page. When notifications are built,
/// this is the one place to change: point it at the real screen and add
/// a red dot for unread items.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  void _open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          appBar: GedfaAppBar(title: 'Notifications'),
          body: EmptyView(
            icon: Icons.notifications_none_rounded,
            title: 'Coming soon',
            message: 'Approvals, rejections, fixtures and announcements '
                'from the FA will appear here.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _open(context),
      icon: const Icon(Icons.notifications_none_rounded),
      tooltip: 'Notifications',
    );
  }
}
