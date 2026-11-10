import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/widgets/dashed_border.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';

/// The Season stats card (2.12b, mockup D for later): top scorer, assists,
/// clean sheets, best attack and best defence. Until match reports exist
/// (Phase 4) it shows dashes and "Open" is switched off.
class SeasonStatsCard extends StatelessWidget {
  const SeasonStatsCard({super.key, required this.wide});

  final bool wide;

  static const _rows = [
    (Icons.sports_soccer_outlined, 'Top scorer'),
    (Icons.assistant_navigation, 'Most assists'),
    (Icons.front_hand_outlined, 'Clean sheets'),
    (Icons.local_fire_department_outlined, 'Best attack'),
    (Icons.security_outlined, 'Best defence'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget row((IconData, String) r) {
      final (icon, label) = r;
      final content = Row(
        children: [
          Icon(icon, size: 19, color: AppColors.ghanaGold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const Text(
            '—',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
      // Wide: small boxes in a row. Phone: lines one under the other.
      return wide
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: content,
            )
          : Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
              child: content,
            );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF081A30), Color(0xFF15467F)]
              : const [AppColors.heroDark, AppColors.deepBlue],
        ),
      ),
      child: Stack(
        children: [
          // A soft gold circle, only for looks (as in the mockup)
          Positioned(
            right: -40,
            bottom: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.ghanaGold.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Season stats ${Season.label(Season.current)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Top scorers, assists, clean sheets and the '
                            'best teams',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Switched off until the first match report (Phase 4)
                    Opacity(
                      opacity: 0.55,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Open',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (wide)
                  Row(
                    children: [
                      for (var i = 0; i < _rows.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: row(_rows[i])),
                      ],
                    ],
                  )
                else
                  for (final r in _rows) row(r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Coming later (2.12b): dashed boxes for what Phase 4 brings. Real tiles
/// replace them when those screens exist.
class ComingLater extends StatelessWidget {
  const ComingLater({super.key, required this.wide, this.items = faItems});

  final bool wide;

  /// Four boxes: icon, title, detail. The team's Home has its own (TDb).
  final List<(IconData, String, String)> items;

  static const faItems = [
    (Icons.calendar_month_outlined, 'Fixtures', 'Match days and venues'),
    (Icons.sports_outlined, 'Referee appointments', 'Officials for each match'),
    (Icons.style_outlined, 'Yellow and red cards', 'From match reports'),
    (Icons.gavel_outlined, 'Player suspensions', 'From cards and the FA'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget box((IconData, String, String) item) {
      final (icon, title, detail) = item;
      return DashedBorder(
        color: dashboardBorder(context),
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: dashboardTrack(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              FixedLinesText(
                title,
                lines: 2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              FixedLinesText(
                detail,
                lines: 2,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // Fixed parts (two lines each), so the boxes line up without being
    // measured
    Widget row(List<(IconData, String, String)> items) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: wide ? 16 : 10),
          Expanded(child: box(items[i])),
        ],
      ],
    );

    if (wide) return row(items);
    return Column(
      children: [
        row(items.sublist(0, 2)),
        const SizedBox(height: 10),
        row(items.sublist(2)),
      ],
    );
  }
}
