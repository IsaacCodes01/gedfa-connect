import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/features/dashboard/domain/dashboard_stats.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';

/// Players by competition (2.12b): approved players in Division and in
/// each juvenile age group, as bars against the biggest one.
class CompetitionChart extends StatelessWidget {
  const CompetitionChart({super.key, required this.stats});

  final DashboardStats stats;

  static const _blue = [AppColors.deepBlue, AppColors.brandBlue];
  static const _green = [Color(0xFF00703F), Color(0xFF2FB67A)];

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final scheme = Theme.of(context).colorScheme;
    final rows = [
      ('Division', s.division, _blue),
      for (final g in AgeGroup.values.reversed)
        ('Juvenile ${g.label}', s.juvenileByGroup[g] ?? 0, _green),
    ];
    final biggest = rows.fold<int>(0, (m, r) => r.$2 > m ? r.$2 : m);
    final waiting = s.waitingDivision + s.waitingJuvenile;

    return DashboardCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.approved} approved',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          Text(
            waiting == 0
                ? 'Nobody waiting'
                : '+ $waiting waiting (${s.waitingDivision} Division, '
                      '${s.waitingJuvenile} Juvenile)',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
          for (final (name, value, colors) in rows) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            GrowingBar(
              fraction: biggest == 0 ? 0 : value / biggest,
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }
}

/// Players by position (2.12b): GK, DEF, MID and FWD in Ghana colours as
/// one bar in four parts, with a Division | Juvenile switch.
class PositionChart extends StatefulWidget {
  const PositionChart({super.key, required this.stats});

  final DashboardStats stats;

  @override
  State<PositionChart> createState() => _PositionChartState();
}

class _PositionChartState extends State<PositionChart> {
  bool _juvenile = false;

  static Color _colorOf(PositionGroup g, bool isDark) => switch (g) {
    PositionGroup.gk => isDark ? AppColors.ghanaGold : const Color(0xFFE0A800),
    PositionGroup.def => isDark ? AppColors.darkPrimary : AppColors.brandBlue,
    PositionGroup.mid => isDark ? AppColors.darkGreen : const Color(0xFF00895A),
    PositionGroup.fwd => isDark ? const Color(0xFFFF6B78) : AppColors.ghanaRed,
  };

  static String _plural(PositionGroup g) => switch (g) {
    PositionGroup.gk => 'Goalkeepers',
    PositionGroup.def => 'Defenders',
    PositionGroup.mid => 'Midfielders',
    PositionGroup.fwd => 'Forwards',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final counts = _juvenile
        ? widget.stats.juvenilePositions
        : widget.stats.divisionPositions;
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final groups = PositionGroup.values;

    return DashboardCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total ${_juvenile ? 'Juvenile' : 'Division'} players',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Main position',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              _Switch(
                juvenile: _juvenile,
                onChanged: (v) => setState(() => _juvenile = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // One bar in four parts; it grows from the left once
          SizedBox(
            height: 18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: total == 0
                  ? ColoredBox(color: dashboardTrack(context))
                  : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: dashboardMotion(context),
                      curve: Curves.easeOutCubic,
                      builder: (_, f, child) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: f,
                          child: child,
                        ),
                      ),
                      child: Row(
                        children: [
                          for (final g in groups)
                            if ((counts[g] ?? 0) > 0)
                              Expanded(
                                flex: counts[g]!,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: g == groups.last ? 0 : 3,
                                  ),
                                  child: ColoredBox(color: _colorOf(g, isDark)),
                                ),
                              ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              children: [
                for (var col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _Legend(
                      name: _plural(groups[row * 2 + col]),
                      code: groups[row * 2 + col].code,
                      value: counts[groups[row * 2 + col]] ?? 0,
                      total: total,
                      color: _colorOf(groups[row * 2 + col], isDark),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.name,
    required this.code,
    required this.value,
    required this.total,
    required this.color,
  });

  final String name;
  final String code;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = total == 0 ? 0 : (value * 100 / total).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name · $code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      CountUpText(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The small "Division | Juvenile" pill switch.
class _Switch extends StatelessWidget {
  const _Switch({required this.juvenile, required this.onChanged});

  final bool juvenile;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget side(String label, bool value) {
      final on = juvenile == value;
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: dashboardMotion(context) ~/ 3,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: on ? scheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: on ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dashboardTrack(context),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [side('Division', false), side('Juvenile', true)],
      ),
    );
  }
}
