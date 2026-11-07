import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/features/dashboard/data/dashboard_providers.dart';
import 'package:gedfa_connect/features/dashboard/domain/dashboard_stats.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/glance_tiles.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/needs_you_card.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/player_charts.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/season_stats_card.dart';
import 'package:go_router/go_router.dart';

/// FA: the Home tab, the first screen after signing in (2.12, mockup
/// 2.12-fa-dashboard).
///
/// Phones, one column: Needs you, League at a glance, the two charts,
/// Season stats, Coming later. Tablets and laptops, up to 1,100 px wide:
/// the tiles 4 in a row first, then Needs you on the left and the charts
/// on the right. Every number is live (no pull to refresh).
class FaDashboardScreen extends ConsumerWidget {
  const FaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = screenSizeOf(context) != ScreenSize.compact;
    final waitingAsync = ref.watch(faWaitingProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    final needs = [
      DashboardSectionTitle(
        title: 'Needs you',
        top: wide ? 26 : 2,
        trailing: switch (waitingAsync.value) {
          final w? when !w.isEmpty => '${w.total} waiting',
          _ => null,
        },
      ),
      waitingAsync.when(
        loading: () => const _LoadingCard(),
        error: (error, _) => _ErrorCard(error: error),
        data: (waiting) => waiting.isEmpty
            ? const AllCaughtUpCard()
            : NeedsYouCard(waiting: waiting),
      ),
    ];

    /// One stats section: its title, then the card (or loading / error).
    List<Widget> section(
      String title,
      Widget Function(DashboardStats stats) build, {
      String? trailing,
      VoidCallback? onTap,
      double top = 20,
    }) => [
      DashboardSectionTitle(
        title: title,
        trailing: trailing,
        onTap: onTap,
        top: top,
      ),
      statsAsync.when(
        loading: () => const _LoadingCard(),
        error: (error, _) => _ErrorCard(error: error),
        data: build,
      ),
    ];

    final glance = section(
      'League at a glance',
      (s) => GlanceTiles(stats: s, wide: wide),
      trailing: 'Season ${Season.label(Season.current)}',
      top: wide ? 2 : 20,
    );
    final charts = [
      ...section(
        'Players by competition',
        (s) => CompetitionChart(stats: s),
        trailing: 'Players ›',
        onTap: () => context.go(Routes.fromHome(Routes.adminPlayers)),
        top: wide ? 26 : 20,
      ),
      ...section('Players by position', (s) => PositionChart(stats: s)),
    ];
    final later = [
      const DashboardSectionTitle(
        title: 'Season stats',
        trailing: 'After the first match report',
      ),
      SeasonStatsCard(wide: wide),
      const DashboardSectionTitle(title: 'Coming later', trailing: 'Phase 4'),
      ComingLater(wide: wide),
      const _LiveNote(),
    ];

    final List<Widget> content = wide
        ? [
            ...glance,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: needs,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: charts,
                  ),
                ),
              ],
            ),
            ...later,
          ]
        : [...needs, ...glance, ...charts, ...later];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons over the blue header
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            DashboardHeader(wide: wide),
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: wide
                      ? const EdgeInsets.fromLTRB(28, 22, 28, 30)
                      : const EdgeInsets.fromLTRB(14, 16, 14, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The line at the bottom: the numbers change by themselves.
class _LiveNote extends StatelessWidget {
  const _LiveNote();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt_rounded, size: 15, color: muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Live · updates by itself',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(18),
      child: Text(appErrorMessage(error)),
    );
  }
}

/// Grey rows of the same shape while the numbers load.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final grey = dashboardBorder(context);

    Widget block(double width, double height, double radius) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: grey,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  block(38, 38, 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        block(120, 12, 6),
                        const SizedBox(height: 6),
                        block(180, 10, 5),
                      ],
                    ),
                  ),
                  block(30, 26, 99),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
