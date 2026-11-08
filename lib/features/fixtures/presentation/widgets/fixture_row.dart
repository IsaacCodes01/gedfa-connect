import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

/// A team's crest in a match: its logo, or its short name on its colour.
class FixtureCrest extends StatelessWidget {
  const FixtureCrest({super.key, required this.side, this.size = 32});

  final FixtureSide side;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = side.shortName.isNotEmpty
        ? side.shortName
        : side.name.isEmpty
            ? '?'
            : side.name.substring(0, 1).toUpperCase();
    return TeamLogo(
      label: label,
      color: side.colour,
      url: side.logoUrl,
      size: size,
    );
  }
}

/// A small coloured pill: "Postponed", "U15", "Sheet sent"…
class FixtureTag extends StatelessWidget {
  const FixtureTag(this.text, {super.key, this.tone = AccentTone.blue});

  final String text;
  final AccentTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.background(isDark),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tone.foreground(isDark),
        ),
      ),
    );
  }
}

/// One match in a list (mockup F1, F3, F4): the date and ground, both
/// teams with the kick-off between them, then any tags.
class FixtureRow extends StatelessWidget {
  const FixtureRow({
    super.key,
    required this.fixture,
    this.onTap,
    this.dateLabel,
    this.showJuvenileRules = false,
  });

  final Fixture fixture;
  final VoidCallback? onTap;

  /// Instead of the plain date, e.g. "Sat 21 Nov · Away".
  final String? dateLabel;

  /// Juvenile lists (F3): match length and who may play up.
  final bool showJuvenileRules;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final f = fixture;
    final kickoff = f.kickoffAt;
    final muted = TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant);
    final group = f.ageGroup;

    final tags = <Widget>[
      if (group != null) FixtureTag(group.label, tone: AccentTone.gold),
      if (f.isPostponed)
        const FixtureTag('Postponed', tone: AccentTone.red),
      if (f.isCancelled)
        const FixtureTag('Cancelled', tone: AccentTone.red),
      if (showJuvenileRules && group != null) ...[
        FixtureTag(group.matchLengthText),
        if (group.playUpText case final text?) FixtureTag(text),
      ],
    ];

    return Semantics(
      button: onTap != null,
      label: '${f.home.name} versus ${f.away.name}, '
          '${kickoff == null ? 'date to come' : '${formatShortDate(kickoff)} '
              '${formatTime(kickoff)}'}, ${f.venue}'
          '${f.isPostponed ? ', postponed' : ''}'
          '${f.isCancelled ? ', cancelled' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: f.isCancelled ? 0.6 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateLabel ??
                            (kickoff == null
                                ? 'New date to come'
                                : formatShortDate(kickoff)),
                        style: muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        f.venue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _Side(side: f.home)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: dashboardTrack(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        kickoff == null || f.isPostponed
                            ? 'TBC'
                            : formatTime(kickoff),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _Side(side: f.away, end: true)),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(spacing: 6, runSpacing: 6, children: tags),
                ],
                if ((f.isPostponed || f.isCancelled) &&
                    (f.note ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Reason: ${f.note}', style: muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.side, this.end = false});

  final FixtureSide side;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final name = Flexible(
      child: Text(
        side.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: end ? TextAlign.end : TextAlign.start,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
    return Row(
      mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: end
          ? [name, const SizedBox(width: 8), FixtureCrest(side: side)]
          : [FixtureCrest(side: side), const SizedBox(width: 8), name],
    );
  }
}

/// A white card holding match rows with thin lines between them.
class FixtureListCard extends StatelessWidget {
  const FixtureListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: dashboardBorder(context)),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
