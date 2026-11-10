import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/team_home_widgets.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/domain/match_calendar.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';

/// The line colour of each kind (mockup TF2).
Color matchKindColour(MatchKind kind) => switch (kind) {
  MatchKind.league => const Color(0xFF1E88E5),
  MatchKind.cup => const Color(0xFFE0A800),
  MatchKind.gala => const Color(0xFF8B5CF6),
};

/// One month of the team's matches (TDc, mockup TF2): ‹ › move a month, a
/// match day shows the opponent's crest (gold ring for a "B" side, a
/// trophy for a Gala) with a blue (League), gold (Cup) or purple (Gala)
/// line, today is circled. A day with one match opens it; a day with
/// several shows them under the calendar.
class MatchCalendarCard extends StatefulWidget {
  const MatchCalendarCard({
    super.key,
    required this.fixtures,
    required this.teamId,
    required this.cups,
    required this.startMonth,
    required this.onOpen,
    this.now,
  });

  /// The matches the switch shows.
  final List<Fixture> fixtures;
  final String teamId;
  final Map<String, Cup> cups;
  final DateTime startMonth;
  final ValueChanged<Fixture> onOpen;

  /// For tests; default: now.
  final DateTime? now;

  @override
  State<MatchCalendarCard> createState() => _MatchCalendarCardState();
}

class _MatchCalendarCardState extends State<MatchCalendarCard> {
  late DateTime _month = widget.startMonth;
  int? _selected;

  void _move(int months) => setState(() {
    _month = DateTime(_month.year, _month.month + months);
    _selected = null;
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final now = (widget.now ?? DateTime.now()).toLocal();
    final byDay = matchesByDay(widget.fixtures, _month);
    final grid = monthGrid(_month);
    final isThisMonth = now.year == _month.year && now.month == _month.month;
    final picked = _selected == null ? null : byDay[_selected];

    Widget arrow(IconData icon, String tip, int months) =>
        IconButton.filledTonal(
          tooltip: tip,
          onPressed: () => _move(months),
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: dashboardTrack(context),
            foregroundColor: scheme.onSurface,
            minimumSize: const Size(36, 36),
            fixedSize: const Size(36, 36),
            padding: EdgeInsets.zero,
          ),
        );

    Widget day(int? d) {
      if (d == null) return const SizedBox.shrink();
      final matches = byDay[d];
      final first = matches?.first;
      final today = isThisMonth && d == now.day;
      final kind = first == null ? null : MatchKind.of(first, widget.cups);

      final number = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: today
            ? BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(99),
              )
            : null,
        child: Text(
          '$d',
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            fontWeight: first != null || today ? FontWeight.w700 : null,
            color: today
                ? scheme.onPrimary
                : first != null
                ? scheme.onSurface
                : muted,
          ),
        ),
      );

      final crest = first == null
          ? null
          : kind == MatchKind.gala
          ? Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: matchKindColour(MatchKind.gala),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 14,
                color: Colors.white,
              ),
            )
          : FixtureCrest(side: first.opponentOf(widget.teamId), size: 22);

      final cell = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          number,
          const SizedBox(height: 2),
          if (crest != null)
            Stack(
              clipBehavior: Clip.none,
              children: [
                crest,
                // More than one match that day (juvenile age groups)
                if (matches!.length > 1)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Text(
                      '+${matches.length - 1}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ),
              ],
            ),
          if (kind != null) ...[
            const SizedBox(height: 2),
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: matchKindColour(kind),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ],
      );

      if (matches == null) {
        return Semantics(
          label: '${monthTitle(_month)} $d${today ? ', today' : ''}',
          child: Padding(padding: const EdgeInsets.only(top: 3), child: cell),
        );
      }
      return Semantics(
        button: true,
        label:
            '$d ${monthTitle(_month)}: '
            '${[for (final f in matches) '${f.opponentOf(widget.teamId).name}, ${MatchKind.of(f, widget.cups).label}'].join('; ')}',
        excludeSemantics: true,
        child: Material(
          color: d == _selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => matches.length == 1
                ? widget.onOpen(matches.single)
                : setState(() => _selected = _selected == d ? null : d),
            child: Padding(padding: const EdgeInsets.only(top: 3), child: cell),
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < grid.length; i += 7) {
      final week = grid.sublist(i, (i + 7).clamp(0, grid.length));
      rows.add(
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(11) * 1.3 + 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < 7; j++)
                Expanded(child: day(j < week.length ? week[j] : null)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  arrow(Icons.chevron_left_rounded, 'Month before', -1),
                  Expanded(
                    child: Text(
                      monthTitle(_month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  arrow(Icons.chevron_right_rounded, 'Next month', 1),
                ],
              ),
              const SizedBox(height: 10),
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                      Expanded(
                        child: Text(
                          w,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ...rows,
              if (byDay.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    'No matches this month',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              const SizedBox(height: 6),
              Divider(height: 1, color: dashboardBorder(context)),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    for (final k in MatchKind.values)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 4,
                            decoration: BoxDecoration(
                              color: matchKindColour(k),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            k.label,
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (picked != null) ...[
          DashboardSectionTitle(
            title: formatShortDate(picked.first.kickoffAt!),
            trailing: '${picked.length} matches',
          ),
          ComingUpCard(
            fixtures: picked,
            teamId: widget.teamId,
            onTap: widget.onOpen,
          ),
        ],
      ],
    );
  }
}
