import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';

/// One tab in the shell's navigation (bottom bar on phones, rail on wide
/// screens).
class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The team admin's tabs. Add Fixtures and Feed here (and a branch for each
/// in the router) when those screens exist.
const teamDestinations = [
  ShellDestination(
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    label: 'Squad',
  ),
  ShellDestination(
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
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  /// Given by go_router. Holds one navigator per tab and knows which tab
  /// is showing.
  final StatefulNavigationShell navigationShell;
  final List<ShellDestination> destinations;

  void _goToTab(int index) {
    // Tapping the tab you're already on takes you back to its first screen.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
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
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
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
