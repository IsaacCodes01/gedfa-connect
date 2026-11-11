import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_status.dart';

/// The team sheet line on the Next match card (3.1c, mockups MS1, MS1b):
/// gold "not started" with Make team sheet; green "saved" with View sheet
/// and Change; grey "locked" with View sheet; red when the lock passed
/// with nothing saved.
class SheetLine extends StatelessWidget {
  const SheetLine({
    super.key,
    required this.status,
    required this.onOpen,
    required this.onView,
  });

  final SheetStatus status;

  /// Make or change the sheet (step 1).
  final VoidCallback onOpen;

  /// The sheet as saved (the Check step).
  final VoidCallback onView;

  /// "Sat 14 Nov, 2:00 pm"
  static String _when(DateTime d) => '${formatShortDate(d)}, ${formatTime(d)}';

  /// "Sat 2:00 pm"
  static String _short(DateTime d) =>
      '${formatShortDate(d).substring(0, 3)} ${formatTime(d)}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final due = status.due;
    final sheet = status.sheet;
    final (
      AccentTone tone,
      IconData icon,
      String title,
      String detail,
    ) = switch (status.state) {
      SheetState.notStarted => (
        AccentTone.gold,
        Icons.assignment_outlined,
        'Team sheet: not started',
        due == null ? '' : 'Due ${_when(due)} (1 hour before kick-off)',
      ),
      SheetState.saved => (
        AccentTone.green,
        Icons.task_alt,
        'Team sheet saved · ${sheet!.playerCount} players',
        [
          '${sheet.starters.length} starting, '
              '${sheet.bench.length} on the bench',
          if (sheet.savedAt case final at?) 'saved ${_short(at)}',
          if (due != null) 'change until ${_short(due)}',
        ].join(' · '),
      ),
      SheetState.locked => (
        AccentTone.grey,
        Icons.lock_outline,
        'Team sheet locked · ${sheet!.playerCount} players',
        due == null ? '' : 'Locked ${_when(due)}, 1 hour before kick-off',
      ),
      SheetState.missed => (
        AccentTone.red,
        Icons.error_outline,
        'No team sheet',
        due == null ? '' : 'It closed ${_when(due)} with nothing saved',
      ),
    };

    final buttons = <Widget>[
      if (status.state == SheetState.notStarted)
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.edit_note, size: 19),
          label: const Text('Make team sheet'),
        ),
      if (status.state == SheetState.saved || status.state == SheetState.locked)
        FilledButton.icon(
          onPressed: onView,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('View sheet'),
        ),
      if (status.state == SheetState.saved)
        FilledButton.tonal(onPressed: onOpen, child: const Text('Change')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tone.background(isDark),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: tone.foreground(isDark)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (buttons.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, b) in buttons.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: b),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
