import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';

/// "Postpone" a league or a cup (3.0c1c, mockups C10, C11): every match not
/// played yet moves by the same number of days, so the weeks off between
/// matchdays stay as they are (GEDFA, 8 Nov 2026).
class PostponePlan {
  PostponePlan._(this.moving, this.days);

  /// The matches that move, by kick-off: scheduled, with a date, not
  /// kicked off yet. Postponed ones still waiting for a date and cancelled
  /// ones stay as they are. Null when nothing is left to move.
  static PostponePlan? of(Iterable<Fixture> matches, DateTime now) {
    final moving = [
      for (final f in matches)
        if (f.isScheduled && f.kickoffAt != null && f.kickoffAt!.isAfter(now))
          f,
    ]..sort((a, b) => a.kickoffAt!.compareTo(b.kickoffAt!));
    return moving.isEmpty ? null : PostponePlan._(moving, 0);
  }

  final List<Fixture> moving;

  /// How many days later; 0 until the FA picks the new date.
  final int days;

  Fixture get first => moving.first;
  Fixture get last => moving.last;

  /// The same plan, with the first match moved to the day [newFirstDay].
  PostponePlan movedTo(DateTime newFirstDay) =>
      PostponePlan._(moving, daysBetween(first.kickoffAt!, newFirstDay));

  /// Where a match's kick-off goes: [days] later, the same time.
  DateTime newKickoff(Fixture f) => shiftDays(f.kickoffAt!, days);
}

/// Whole days from [from] to [to], times ignored.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// [days] later at the same time of day.
DateTime shiftDays(DateTime when, int days) =>
    DateTime(when.year, when.month, when.day + days, when.hour, when.minute);

/// "2 weeks later", "10 days later" or "1 day later"
String laterLabel(int days) {
  if (days % 7 == 0) {
    final weeks = days ~/ 7;
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'} later';
  }
  return '$days ${days == 1 ? 'day' : 'days'} later';
}
