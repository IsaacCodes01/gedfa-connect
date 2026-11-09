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

  /// Opens a page so that ← (and the phone's Back) come back here (3.0f2).
  ///
  /// - A full-screen page opens on top (push), from anywhere.
  /// - A page of the same tab, opened from inside the tabs: on top too.
  /// - Anything else (another tab, or a tab's page from a full-screen page
  ///   like a note's details) switches with go and carries `back=` here:
  ///   go_router can't push a tab's page over a full-screen one.
  void open(String route) {
    final target = keepFromHome(route);
    final config = GoRouter.of(this).configuration;
    final match = config.findMatch(Uri.parse(target));
    final targetRoute = match.isEmpty ? null : match.last.route;
    if (targetRoute is GoRoute &&
        targetRoute.parentNavigatorKey == config.navigatorKey) {
      push<void>(target);
      return;
    }
    final here = GoRouterState.of(this);
    final onTop = here.topRoute?.parentNavigatorKey == config.navigatorKey;
    final tab = _tabOf(match);
    if (!onTop && tab != null && tab == _tabOf(config.findMatch(here.uri))) {
      push<void>(target);
      return;
    }
    go(Routes.withBack(target, here.uri.toString()));
  }

  /// ← : back where I came from: the `back=` page, the page underneath,
  /// or, with nothing behind (a link, a refresh on the web), [fallback]
  /// (the tab's main screen).
  void goBack(String fallback) {
    final back = Routes.backOf(GoRouterState.of(this).uri);
    if (back != null) {
      go(back);
    } else if (canPop()) {
      pop();
    } else {
      go(keepFromHome(fallback));
    }
  }

  /// The first page of the tab a location is in; null outside the tabs.
  static RouteBase? _tabOf(RouteMatchList match) {
    for (final m in match.matches) {
      if (m is ShellRouteMatch) return m.matches.firstOrNull?.route;
    }
    return null;
  }
}

/// The ← on a page (3.0f2): [KeepFromHome.goBack]. The phone's Back does
/// the same whenever it would do something else (a `back=` page, or
/// nothing behind). [close] shows ✕ instead of ←.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.fallback,
    this.close = false,
    this.enabled = true,
  });

  final String fallback;
  final bool close;

  /// False while saving: neither ← nor the phone's Back leaves.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final onPressed = enabled ? () => context.goBack(fallback) : null;
    final button = close
        ? CloseButton(onPressed: onPressed)
        : BackButton(onPressed: onPressed);
    final custom = Routes.backOf(GoRouterState.of(context).uri) != null ||
        !context.canPop();
    if (enabled && !custom) return button;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && enabled) context.goBack(fallback);
      },
      child: button,
    );
  }
}

/// The ← that [GedfaAppBar] adds by itself on a page opened with `back=`
/// and no ← of its own (a tab's main screen opened from a note).
class BackParamButton extends StatelessWidget {
  const BackParamButton({super.key, required this.back});

  final String back;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(back);
      },
      child: BackButton(onPressed: () => context.go(back)),
    );
  }
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
