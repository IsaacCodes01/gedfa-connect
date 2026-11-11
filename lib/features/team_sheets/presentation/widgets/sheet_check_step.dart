import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_roles.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_preview.dart';

/// The sheet as it will look (3.1c, mockup MS5; on a laptop the right-hand
/// column of MS7, filling in as players are picked): today's kit in the
/// corner, the starting 11 with C / VC / GK, the bench with "usual 17"
/// beside a changed number, and the officials.
class SheetPaper extends StatelessWidget {
  const SheetPaper({
    super.key,
    required this.title,
    required this.subtitle,
    required this.kit,
    required this.starters,
    required this.bench,
    required this.maxBench,
    required this.numbers,
    required this.roles,
    required this.officials,
  });

  final String title;
  final String subtitle;
  final Kit kit;
  final List<Player> starters;
  final List<Player> bench;
  final int maxBench;

  /// Every picked player's number for this match.
  final Map<String, int> numbers;

  /// Fitted to the picks.
  final SheetRoles roles;
  final List<Official> officials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;

    Widget head(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
          color: muted,
        ),
      ),
    );

    Widget line(Player p) {
      final number = numbers[p.id] ?? p.jerseyNo;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(p.fullName, style: const TextStyle(fontSize: 13)),
                  if (p.id == roles.captainId) const _Mark('C', captain: true),
                  if (p.id == roles.viceCaptainId) const _Mark('VC'),
                  if (p.id == roles.goalkeeperId) const _Mark('GK'),
                  if (number != p.jerseyNo)
                    FixtureTag('usual ${p.jerseyNo}', tone: AccentTone.grey),
                ],
              ),
            ),
            Text(
              p.position.code,
              style: TextStyle(fontSize: 11.5, color: muted),
            ),
          ],
        ),
      );
    }

    return DashboardCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KitPreview(kit: kit, width: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(height: 12, color: dashboardBorder(context)),
          head(
            'STARTING ${starters.length == 11 ? '11' : '(${starters.length})'}',
          ),
          if (starters.isEmpty)
            Text('Nobody picked yet', style: TextStyle(color: muted)),
          for (final p in starters) line(p),
          if (bench.isNotEmpty) ...[
            head('BENCH (${bench.length} of $maxBench)'),
            for (final p in bench) line(p),
          ],
          if (officials.isNotEmpty) ...[
            head('OFFICIALS'),
            Text(
              [
                for (final o in officials) '${o.name} (${o.roleText})',
              ].join(' · '),
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark(this.label, {this.captain = false});

  final String label;
  final bool captain;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: captain
          ? const Color(0xFFFCD116)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        color: captain ? const Color(0xFF3A2C00) : null,
      ),
    ),
  );
}

/// One line of the checks: green tick, gold info, red problem, grey note.
typedef CheckLine = (AccentTone tone, String text);

/// The checks under the sheet (MS5).
class SheetCheckList extends StatelessWidget {
  const SheetCheckList({super.key, required this.lines});

  final List<CheckLine> lines;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          for (final (tone, text) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (tone) {
                      AccentTone.green => Icons.check_circle,
                      AccentTone.red => Icons.error,
                      _ => Icons.info_outline,
                    },
                    size: 18,
                    color: tone.foreground(isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(text, style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
