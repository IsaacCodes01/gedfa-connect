import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:go_router/go_router.dart';

/// One tab in the shell's navigation (bottom bar on phones, rail on wide
/// screens).
class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Optional number shown in a gold bubble on the icon (e.g. requests
  /// waiting). Hidden when it is 0.
  final Provider<int>? badge;
}

/// The team admin's tabs. Add Feed here (and a branch in the router) when
/// that screen exists.
final teamDestinations = [
  // Home (TDa) comes first, like the FA's
  const ShellDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Home',
  ),
  const ShellDestination(
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    label: 'Squad',
  ),
  const ShellDestination(
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    label: 'Fixtures',
  ),
  const ShellDestination(
    icon: Icons.assignment_ind_outlined,
    selectedIcon: Icons.assignment_ind_rounded,
    label: 'Profiles',
  ),
  const ShellDestination(
    icon: Icons.more_horiz_rounded,
    selectedIcon: Icons.more_horiz_rounded,
    label: 'More',
  ),
];

/// The FA admin's tabs. The gold numbers are things waiting for the FA.
/// Home (the dashboard, 2.12) comes first and has no number: its
/// "Needs you" card lists them all.
final adminDestinations = [
  const ShellDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Home',
  ),
  ShellDestination(
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield_rounded,
    label: 'Teams',
    // New teams + change requests waiting (2.10b)
    badge: faTeamsWaitingCountProvider,
  ),
  ShellDestination(
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    label: 'Players',
    badge: pendingPlayerCountProvider,
  ),
  const ShellDestination(
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    label: 'Fixtures',
  ),
  const ShellDestination(
    icon: Icons.more_horiz_rounded,
    selectedIcon: Icons.more_horiz_rounded,
    label: 'More',
  ),
];

/// The frame around the tab screens. It stays on screen while the tab
/// content changes underneath.
///
/// - Phones (compact): bottom navigation bar.
/// - Tablets and laptops (medium, expanded): navigation rail on the left.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
    this.openedFromHome = false,
  });

  /// Given by go_router. Holds one navigator per tab and knows which tab
  /// is showing.
  final StatefulNavigationShell navigationShell;
  final List<ShellDestination> destinations;

  /// The screen showing was opened from a "Needs you" row on the FA's
  /// Home (`from=home`, 2.12a), so it has a back arrow to Home.
  final bool openedFromHome;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Tabs whose screen was opened from Home, or from a note with `back=`
  /// (3.0f2). Going back to one of them with the navigation bar opens its
  /// first screen instead, so it looks as usual (no back arrow).
  final _openedFromHome = <int>{};

  StatefulNavigationShell get navigationShell => widget.navigationShell;
  List<ShellDestination> get destinations => widget.destinations;

  @override
  void initState() {
    super.initState();
    _noteFromHome();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _noteFromHome();
  }

  void _noteFromHome() {
    final tab = navigationShell.currentIndex;
    if (widget.openedFromHome) {
      _openedFromHome.add(tab);
    } else {
      _openedFromHome.remove(tab);
    }
  }

  void _goToTab(int index) {
    // Tapping the tab you're already on takes you back to its first
    // screen, and so does a tab that was opened from Home.
    final fromHome = _openedFromHome.remove(index);
    navigationShell.goBranch(
      index,
      initialLocation: fromHome || index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // The badge number for each tab (0 = no bubble)
    final counts = [
      for (final d in destinations)
        d.badge == null ? 0 : ref.watch(d.badge!),
    ];

    Widget iconFor(int index, {required bool selected}) {
      final d = destinations[index];
      return _BadgedIcon(
        icon: selected ? d.selectedIcon : d.icon,
        count: counts[index],
      );
    }

    if (screenSizeOf(context) == ScreenSize.compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outline)),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goToTab,
            destinations: [
              for (var i = 0; i < destinations.length; i++)
                NavigationDestination(
                  icon: iconFor(i, selected: false),
                  selectedIcon: iconFor(i, selected: true),
                  label: destinations[i].label,
                  tooltip: counts[i] > 0
                      ? '${destinations[i].label}, ${counts[i]} waiting'
                      : null,
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goToTab,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (var i = 0; i < destinations.length; i++)
                NavigationRailDestination(
                  icon: iconFor(i, selected: false),
                  selectedIcon: iconFor(i, selected: true),
                  label: Text(destinations[i].label),
                ),
            ],
          ),
          VerticalDivider(width: 1, thickness: 1, color: scheme.outline),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

/// A tab icon with an optional gold number bubble, like the mockup.
class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: AppColors.ghanaGold,
      textColor: const Color(0xFF3A2C00),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      offset: const Offset(10, -6),
      child: Icon(icon),
    );
  }
}
