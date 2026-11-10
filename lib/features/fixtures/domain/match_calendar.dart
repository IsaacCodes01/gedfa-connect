import 'package:gedfa_connect/features/fixtures/domain/cup.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';

/// The month calendar of matches (TDc, mockup td-team-dashboard TF2), on
/// the team's Home and its Fixtures tab. No Flutter here, so it is easy
/// to test (test/match_calendar_test.dart).

/// The coloured line under a match day: blue League, gold Cup, purple Gala.
enum MatchKind {
  league('League'),
  cup('Cup'),
  gala('Gala');

  const MatchKind(this.label);

  final String label;

  /// A league match's `competitionId` ends in "-league"; a cup or gala
  /// match carries its cup's ID (3.0c2), so [cups] says which it is. An
  /// unknown cup counts as a cup.
  static MatchKind of(Fixture f, Map<String, Cup> cups) {
    if (f.competitionId.endsWith('-league')) return MatchKind.league;
    return cups[f.competitionId]?.isGala ?? false
        ? MatchKind.gala
        : MatchKind.cup;
  }
}

/// The days of [month] in a grid whose weeks start on Monday: null for the
/// blank cells before the 1st, then 1 to the last day.
List<int?> monthGrid(DateTime month) {
  final first = DateTime(month.year, month.month);
  final days = DateTime(month.year, month.month + 1, 0).day;
  // Monday = 1 … Sunday = 7: Monday has no blank, Sunday has 6
  return [
    for (var i = 1; i < first.weekday; i++) null,
    for (var d = 1; d <= days; d++) d,
  ];
}

/// The matches of [month] by day of the month, each day earliest first.
/// Postponed matches without a new date have no day, so they are not here.
Map<int, List<Fixture>> matchesByDay(List<Fixture> fixtures, DateTime month) {
  final byDay = <int, List<Fixture>>{};
  for (final f in fixtures) {
    final k = f.kickoffAt?.toLocal();
    if (k == null || f.isCancelled) continue;
    if (k.year != month.year || k.month != month.month) continue;
    byDay.putIfAbsent(k.day, () => []).add(f);
  }
  for (final list in byDay.values) {
    list.sort((a, b) => a.kickoffAt!.compareTo(b.kickoffAt!));
  }
  return byDay;
}

/// The month the calendar opens on: the next match's month, or this month.
DateTime startMonth(Fixture? next, DateTime now) {
  final k = next?.kickoffAt?.toLocal() ?? now.toLocal();
  return DateTime(k.year, k.month);
}

/// "November 2026"
String monthTitle(DateTime month) =>
    '${_months[month.month - 1]} ${month.year}';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];
