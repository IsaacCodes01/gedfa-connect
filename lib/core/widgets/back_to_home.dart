import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:go_router/go_router.dart';

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
