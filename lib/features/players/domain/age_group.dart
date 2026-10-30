import 'package:gedfa_connect/core/constants/season.dart';

/// The juvenile age groups (2.14). A player's own group comes from their
/// age in the year the season STARTS (GEDFA's answer, 27 Oct 2026):
/// season 2026/27 → 2026 − birth year.
///
///   born 2013 or later → 13 or under → U13
///   born 2011–2012    → 14–15        → U15
///   born 2009–2010    → 16–17        → U17
///   born 2008 or before → 18+        → too old for Juvenile
enum AgeGroup {
  u13('U13', 13),
  u15('U15', 15),
  u17('U17', 17);

  const AgeGroup(this.label, this.maxAge);

  /// 'U13'. Also what Firestore stores.
  final String label;

  /// The oldest age allowed in this group.
  final int maxAge;

  static AgeGroup? fromString(String? value) {
    for (final group in values) {
      if (group.label == value) return group;
    }
    return null;
  }

  /// Age in the year the season starts, e.g. born 2015 → 11 in 2026.
  static int seasonAge(DateTime dob, [String? season]) =>
      Season.startYear(season ?? Season.current) - dob.year;

  /// The youngest group this player fits, or null if too old.
  static AgeGroup? ownGroup(DateTime dob, [String? season]) {
    final age = seasonAge(dob, season);
    for (final group in values) {
      if (age <= group.maxAge) return group;
    }
    return null;
  }

  /// Own group and older ones: younger players may play UP, nobody
  /// plays down, and nobody too old plays at all.
  static List<AgeGroup> allowedFor(DateTime dob, [String? season]) {
    final own = ownGroup(dob, season);
    if (own == null) return const [];
    return values.where((g) => g.index >= own.index).toList();
  }

  /// "Born 2013 or later" for the tab's note.
  String bornText([String? season]) {
    final year = Season.startYear(season ?? Season.current) - maxAge;
    return 'Born $year or later ($maxAge or under in '
        '${Season.startYear(season ?? Season.current)})';
  }
}

/// A juvenile player's parent or guardian (required, 2.14).
/// Only the team and the FA can read it.
enum GuardianRelation {
  mother('Mother'),
  father('Father'),
  guardian('Guardian'),
  other('Other');

  const GuardianRelation(this.label);

  final String label;

  static GuardianRelation fromString(String? value) => values.firstWhere(
        (r) => r.name == value,
        orElse: () => GuardianRelation.guardian,
      );
}

class Guardian {
  const Guardian({
    required this.relation,
    required this.name,
    required this.phone,
  });

  final GuardianRelation relation;
  final String name;
  final String phone;

  Map<String, dynamic> toMap() => {
        'relation': relation.name,
        'name': name.trim(),
        'phone': phone.trim(),
      };

  static Guardian? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return Guardian(
      relation: GuardianRelation.fromString(raw['relation'] as String?),
      name: raw['name'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
    );
  }
}
