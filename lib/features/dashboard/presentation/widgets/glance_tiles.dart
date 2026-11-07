import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/features/dashboard/domain/dashboard_stats.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:go_router/go_router.dart';

/// League at a glance (2.12b): teams, players approved, fees collected
/// (every FA official sees it) and squads ready. 2 by 2 on phones, 4 in a
/// row on wide screens. Each tile opens its screen, with the way back to
/// Home.
class GlanceTiles extends StatelessWidget {
  const GlanceTiles({super.key, required this.stats, required this.wide});

  final DashboardStats stats;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final feePercent = s.due == 0 ? 0 : (s.collected * 100 / s.due).round();

    final tiles = [
      _Tile(
        icon: Icons.shield_rounded,
        tone: AccentTone.blue,
        value: s.teams,
        label: 'Teams',
        detail:
            '${s.bothCompetitions} in both competitions · '
            '${s.suspended} suspended',
        route: Routes.admin,
      ),
      _Tile(
        icon: Icons.groups_rounded,
        tone: AccentTone.green,
        value: s.approved,
        label: 'Players approved',
        detail: '${s.division} Division · ${s.juvenile} Juvenile',
        chip: s.approvedThisWeek > 0
            ? '+${s.approvedThisWeek} this week'
            : null,
        route: Routes.adminPlayers,
      ),
      _Tile(
        icon: Icons.account_balance_wallet_rounded,
        tone: AccentTone.gold,
        value: s.collected,
        prefix: 'GH₵',
        label: 'Fees collected',
        progress: s.due == 0 ? 0 : s.collected / s.due,
        progressColors: const [AppColors.ghanaGreen, Color(0xFF2FB67A)],
        detail: s.owing == 0
            ? 'Every team has paid ${cedis(Season.fee)}'
            : '$feePercent% of ${cedis(s.due)} · '
                  '${s.owing} ${s.owing == 1 ? 'team' : 'teams'} owing',
        route: Routes.adminFees,
      ),
      _Tile(
        icon: Icons.fact_check_rounded,
        tone: AccentTone.violet,
        value: s.squadsReady,
        suffix: 'of ${s.divisionTeams}',
        label: 'Squads ready',
        progress: s.divisionTeams == 0 ? 0 : s.squadsReady / s.divisionTeams,
        progressColors: const [Color(0xFF5B3FC4), Color(0xFF8E77F0)],
        detail: 'At least ${s.squadSize} approved Division players',
        route: Routes.adminPlayers,
      ),
    ];

    // Every tile has the same fixed parts, so they line up without being
    // measured (no IntrinsicHeight: on web the font loads late)
    Widget row(List<Widget> items) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: wide ? 16 : 10),
          Expanded(child: items[i]),
        ],
      ],
    );

    if (wide) return row(tiles);
    return Column(
      children: [
        row(tiles.sublist(0, 2)),
        const SizedBox(height: 10),
        row(tiles.sublist(2)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    required this.detail,
    required this.route,
    this.prefix,
    this.suffix,
    this.chip,
    this.progress,
    this.progressColors = const [],
  });

  final IconData icon;
  final AccentTone tone;
  final int value;
  final String label;
  final String detail;
  final String route;

  /// Small grey text before ("GH₵") or after ("of 18") the number.
  final String? prefix;
  final String? suffix;

  /// Green pill at the top right ("+17 this week").
  final String? chip;

  /// A bar under the label (0 to 1), when given.
  final double? progress;
  final List<Color> progressColors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final small = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );

    return Semantics(
      button: true,
      label: '$label: ${prefix ?? ''} $value ${suffix ?? ''}. $detail',
      excludeSemantics: true,
      child: DashboardCard(
        padding: const EdgeInsets.all(14),
        onTap: () => context.go(Routes.fromHome(route)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AccentIcon(icon: icon, tone: tone),
                const SizedBox(width: 6),
                const Spacer(),
                // Shrinks on a narrow tile instead of overflowing
                if (chip != null)
                  Flexible(
                    flex: 6,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AccentTone.green.background(isDark),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          chip!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AccentTone.green.foreground(isDark),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // A fixed height: a long number shrinks to fit the width
            // without making this tile shorter than the others
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(28) * 1.15,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (prefix != null) Text('${prefix!} ', style: small),
                    CountUpText(
                      value,
                      format: _thousands,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                    if (suffix != null) Text(' ${suffix!}', style: small),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            FixedLinesText(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              GrowingBar(
                fraction: progress!,
                colors: progressColors,
                height: 7,
              ),
            ],
            const SizedBox(height: 2),
            FixedLinesText(
              detail,
              lines: 2,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            // Tiles without a bar keep its room at the bottom
            if (progress == null) const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  /// 13500 -> '13,500'
  static String _thousands(int n) => cedis(n).replaceFirst('GH₵ ', '');
}
