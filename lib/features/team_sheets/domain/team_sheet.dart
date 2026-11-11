import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// A team's sheet for one match (3.1): `teamSheets/{fixtureId}_{teamId}`.
///
/// The players: [starters] (up to 11) and [bench] (up to 7, only once 11
/// start), 3.1a2. The roles for this match: captain, vice-captain,
/// goalkeeper, a shirt number for every picked player, and the team
/// officials (copies, without phone numbers), 3.1b.
class TeamSheet {
  const TeamSheet({
    required this.fixtureId,
    required this.teamId,
    required this.category,
    this.ageGroup,
    this.starters = const [],
    this.bench = const [],
    this.captainId,
    this.viceCaptainId,
    this.goalkeeperId,
    this.numbers = const {},
    this.officials = const [],
    this.savedBy,
    this.savedAt,
  });

  final String fixtureId;
  final String teamId;
  final Competition category;

  /// Juvenile matches only: the match's age group.
  final AgeGroup? ageGroup;
  final List<String> starters;
  final List<String> bench;
  final String? captainId;
  final String? viceCaptainId;
  final String? goalkeeperId;

  /// Player ID → shirt number for this match (1 to 99, no two the same).
  final Map<String, int> numbers;

  /// Team manager first, head coach second, then the others.
  final List<Official> officials;
  final String? savedBy;
  final DateTime? savedAt;

  /// The document ID: `{fixtureId}_{teamId}`, one sheet per team and match.
  static String idFor(String fixtureId, String teamId) =>
      '${fixtureId}_$teamId';

  int get playerCount => starters.length + bench.length;

  static TeamSheet fromMap(Map<String, dynamic> data) {
    List<String> ids(String key) =>
        (data[key] as List?)?.whereType<String>().toList() ?? const [];
    return TeamSheet(
      fixtureId: data['fixtureId'] as String? ?? '',
      teamId: data['teamId'] as String? ?? '',
      category: Competition.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => Competition.division,
      ),
      ageGroup: AgeGroup.fromString(data['ageGroup'] as String?),
      starters: ids('starters'),
      bench: ids('bench'),
      captainId: data['captainId'] as String?,
      viceCaptainId: data['viceCaptainId'] as String?,
      goalkeeperId: data['goalkeeperId'] as String?,
      numbers: {
        for (final e in (data['numbers'] as Map? ?? const {}).entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toInt(),
      },
      officials: [
        for (final o in data['officials'] as List? ?? const [])
          if (o is Map) ?Official.fromMap(Map<String, dynamic>.from(o)),
      ],
      savedBy: data['savedBy'] as String?,
      savedAt: (data['savedAt'] as Timestamp?)?.toDate(),
    );
  }
}
