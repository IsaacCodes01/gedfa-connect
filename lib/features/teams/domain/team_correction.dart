import 'package:cloud_firestore/cloud_firestore.dart';

/// What the FA can correct on an approved team itself (2.11a): only
/// misspellings and obvious mistakes in what the club typed. Kits,
/// colours and officials (sensitive) the FA asks the team to correct
/// (2.11b); short name, logo and competitions the team asks for (2.10b).
enum CorrectionSection {
  name('Club name'),
  details('Club details'); // town, ground, directions, year, email

  const CorrectionSection(this.label);

  final String label;

  static CorrectionSection? fromString(String? value) {
    for (final section in values) {
      if (section.name == value) return section;
    }
    return null;
  }
}

/// `teams/{teamId}/corrections/{id}`: one line of the FA's corrections
/// log. Written in the same batch as the correction; never edited.
class TeamCorrection {
  const TeamCorrection({
    required this.id,
    required this.section,
    required this.fields,
    required this.lines,
    required this.reason,
    this.byName,
    this.createdAt,
  });

  final String id;
  final CorrectionSection section;

  /// The team's fields that changed, e.g. `homeGround`
  final List<String> fields;

  /// What the FA and the team read, e.g. "Home ground: Apam Prk → Apam Park"
  final List<String> lines;

  /// "What was wrong?"
  final String reason;
  final String? byName;
  final DateTime? createdAt;

  factory TeamCorrection.fromMap(String id, Map<String, dynamic> data) {
    List<String> strings(Object? list) => [
          for (final item in list as List<dynamic>? ?? const [])
            if (item is String) item,
        ];
    return TeamCorrection(
      id: id,
      section: CorrectionSection.fromString(data['section'] as String?) ??
          CorrectionSection.details,
      fields: strings(data['fields']),
      lines: strings(data['lines']),
      reason: data['reason'] as String? ?? '',
      byName: data['byName'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
