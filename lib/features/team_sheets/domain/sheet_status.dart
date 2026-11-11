import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';

/// Where a team's sheet for one match stands (3.1c, mockups MS1, MS1b).
enum SheetState {
  /// Open, nothing saved yet (gold).
  notStarted,

  /// Open and saved; can still be changed (green).
  saved,

  /// Locked 1 hour before kick-off with a sheet (grey, view only).
  locked,

  /// Locked with nothing saved, or the match is off (red / nothing).
  missed,
}

class SheetStatus {
  const SheetStatus(this.state, {this.due, this.sheet});

  final SheetState state;

  /// The lock: 1 hour before kick-off.
  final DateTime? due;
  final TeamSheet? sheet;

  bool get isOpen =>
      state == SheetState.notStarted || state == SheetState.saved;

  static SheetStatus of(Fixture f, TeamSheet? sheet, DateTime now) {
    final due = f.sheetDueAt;
    final open = f.isScheduled && due != null && now.isBefore(due);
    final SheetState state;
    if (open) {
      state = sheet == null ? SheetState.notStarted : SheetState.saved;
    } else {
      state = sheet == null ? SheetState.missed : SheetState.locked;
    }
    return SheetStatus(state, due: due, sheet: sheet);
  }

  /// "Needs you" shows a sheet not started from 2 days before it is due
  /// (mockup MS1).
  bool needsYou(DateTime now) =>
      state == SheetState.notStarted &&
      due != null &&
      due!.difference(now) <= const Duration(days: 2);

  /// Red on the day it is due.
  bool isDueToday(DateTime now) =>
      due != null &&
      due!.year == now.year &&
      due!.month == now.month &&
      due!.day == now.day;
}

/// The team's most recent sheet for ANOTHER match of the same competition
/// and age group, for "Use last sheet" (3.1c); null if there is none.
TeamSheet? lastSheetFor(Fixture f, Iterable<TeamSheet> sheets) {
  TeamSheet? best;
  for (final s in sheets) {
    if (s.fixtureId == f.id ||
        s.category != f.category ||
        s.ageGroup != f.ageGroup ||
        s.savedAt == null) {
      continue;
    }
    if (best == null || s.savedAt!.isAfter(best.savedAt!)) best = s;
  }
  return best;
}
