import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:go_router/go_router.dart';

/// Links on screens that can be opened from Home pass the note on
/// (2.12a): a screen opened from Home opens the next one with
/// `from=home` too, and its back arrow returns to the first one with the
/// note, so the trail always ends back on Home. Opened from the tabs,
/// [route] comes back unchanged.
extension KeepFromHome on BuildContext {
  String keepFromHome(String route) =>
      Routes.isFromHome(GoRouterState.of(this).uri) &&
              !Routes.isFromHome(Uri.parse(route))
          ? Routes.fromHome(route)
          : route;

  /// `context.go`, passing the note on.
  void goKeepingHome(String route) => go(keepFromHome(route));

  /// `context.push`, passing the note on.
  Future<T?> pushKeepingHome<T extends Object?>(String route) =>
      push<T>(keepFromHome(route));
}

/// The back arrow on a screen opened from a "Needs you" row on the FA's
/// Home (2.12a). It goes back to Home, and so does the phone's own Back
/// button while the arrow is on screen (the PopScope). Opened from the
/// tabs, the screen shows no arrow and Back works as before.
class BackToHomeButton extends StatelessWidget {
  const BackToHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.adminHome);
      },
      child: BackButton(onPressed: () => context.go(Routes.adminHome)),
    );
  }
}
