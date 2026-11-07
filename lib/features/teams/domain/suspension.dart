import 'package:cloud_firestore/cloud_firestore.dart';

/// Why the chairman lifted a suspension (2.11c, mockup C4).
enum LiftReason {
  finePaid('Fine paid'),
  bondSigned('Bond signed'),
  boardDecision('Board decision'),
  other('Other');

  const LiftReason(this.label);

  final String label;

  static LiftReason? fromString(String? value) {
    for (final reason in values) {
      if (reason.name == value) return reason;
    }
    return null;
  }
}

/// A team's suspension (2.11c): the `suspension` map on the team, and the
/// same details on its line in `teams/{teamId}/suspensions/{id}`.
///
/// [until] is the moment it ends: the start of the day AFTER the date the
/// chairman picked (Ghana time is UTC), or null until the chairman lifts
/// it (after the FA board meets the club).
class Suspension {
  const Suspension({
    required this.id,
    required this.reason,
    this.since,
    this.until,
    this.byName,
    this.liftedAt,
    this.liftReason,
    this.liftNote,
    this.liftedByName,
  });

  final String id;
  final String reason;
  final DateTime? since;
  final DateTime? until;
  final String? byName;

  // History lines only: how it was lifted
  final DateTime? liftedAt;
  final LiftReason? liftReason;
  final String? liftNote;
  final String? liftedByName;

  /// The last day of a dated suspension ("until 30 Nov")
  DateTime? get lastDay => until?.subtract(const Duration(days: 1));

  /// In force now (a dated one ends by itself)
  bool get isActive {
    final until = this.until;
    return liftedAt == null &&
        (until == null || DateTime.now().isBefore(until));
  }

  /// The end of [lastDay] in Ghana: the start of the next day, UTC.
  static DateTime endOf(DateTime lastDay) =>
      DateTime.utc(lastDay.year, lastDay.month, lastDay.day + 1);

  static Suspension? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    DateTime? time(String field) => (data[field] as Timestamp?)?.toDate();
    return Suspension(
      id: id,
      reason: data['reason'] as String? ?? '',
      since: time('since'),
      until: time('until'),
      byName: data['byName'] as String?,
      liftedAt: time('liftedAt'),
      liftReason: LiftReason.fromString(data['liftReason'] as String?),
      liftNote: data['liftNote'] as String?,
      liftedByName: data['liftedByName'] as String?,
    );
  }

  /// The map on the team (its ID is inside)
  static Suspension? fromTeamMap(Map<String, dynamic>? data) =>
      data == null ? null : fromMap(data['id'] as String? ?? '', data);
}
