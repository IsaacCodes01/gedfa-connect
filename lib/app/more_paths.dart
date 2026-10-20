import 'package:flutter/widgets.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:go_router/go_router.dart';

/// The More tab exists for team admins (/team/more) and for FA admins
/// (/admin/more). The More, My profile and Settings screens are shared, so
/// they ask this class for the right addresses instead of hard-coding them.
class MorePaths {
  const MorePaths._(this.root);

  /// '/team/more' or '/admin/more'
  final String root;

  String get profile => '$root/profile';
  String get changeEmail => '$root/profile/email';
  String get settings => '$root/settings';

  /// Works out which area we are in from the current address.
  static MorePaths of(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return MorePaths._(
      location.startsWith(Routes.admin) ? Routes.adminMore : Routes.teamMore,
    );
  }
}
