import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
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

/// The team admin's tabs. Add Fixtures and Feed here (and a branch for each
/// in the router) when those screens exist.
final teamDestinations = [
  const ShellDestination(
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    label: 'Squad',
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
final adminDestinations = [
  ShellDestination(
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield_rounded,
    label: 'Teams',
    badge: pendingTeamRequestCountProvider,
  ),
  ShellDestination(
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    label: 'Players',
    badge: pendingPlayerCountProvider,
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
class AppShell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
