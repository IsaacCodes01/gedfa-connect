import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `screeningDays/{id}` (2.14b, board J3): a day when the FA checks
/// juvenile children in person. Saving one also publishes an
/// announcement to Juvenile teams; [announcementId] points to it.
class ScreeningDay {
  const ScreeningDay({
    required this.id,
    required this.startsAt,
    required this.venue,
    required this.groups,
    required this.note,
    required this.announcementId,
  });

  final String id;

  /// Date and time it starts, e.g. Sat 14 Nov 2026, 9:00 am
  final DateTime startsAt;
  final String venue;

  /// Which age groups come that day, in order (U13, U15, U17)
  final List<AgeGroup> groups;

  /// "What to bring", optional (empty when not given)
  final String note;
  final String announcementId;

  /// "Sat 14 Nov"
  String get dateText => dateTextFor(startsAt);

  static String dateTextFor(DateTime date) {
    final d = date.toLocal();
    return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  /// "9:00 am"
  String get timeText {
    final d = startsAt.toLocal();
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour < 12 ? 'am' : 'pm'}';
  }

  /// "U13", "U13 and U15", "U13, U15 and U17"
  String get groupsText => groupsTextFor(groups);

  static String groupsTextFor(List<AgeGroup> groups) {
    final labels = [for (final g in groups) g.label];
    if (labels.length <= 1) return labels.join();
    return '${labels.sublist(0, labels.length - 1).join(', ')} and '
        '${labels.last}';
  }

  /// The card stays on the team's Squad tab until the day after.
  bool isShownOn(DateTime now) {
    final d = startsAt.toLocal();
    final dayAfter = DateTime(d.year, d.month, d.day + 1);
    return now.isBefore(dayAfter);
  }

  static ScreeningDay? fromMap(String id, Map<String, dynamic> data) {
    final startsAt = (data['startsAt'] as Timestamp?)?.toDate();
    if (startsAt == null) return null;
    final groups = [
      for (final raw in data['groups'] as List<dynamic>? ?? const [])
        ?AgeGroup.fromString(raw as String?),
    ]..sort((a, b) => a.index.compareTo(b.index));
    return ScreeningDay(
      id: id,
      startsAt: startsAt,
      venue: data['venue'] as String? ?? '',
      groups: groups,
      note: data['note'] as String? ?? '',
      announcementId: data['announcementId'] as String? ?? '',
    );
  }
}
