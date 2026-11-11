import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
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
    this.players = const {},
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

  /// A copy of each picked player as saved (3.2): the FA and the opponent
  /// read the sheet without reading the club's player files. Empty on
  /// sheets saved before 3.2.
  final Map<String, SheetPlayer> players;
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
      players: {
        for (final e in (data['players'] as Map? ?? const {}).entries)
          if (e.key is String && e.value is Map)
            e.key as String: SheetPlayer.fromMap(
              e.key as String,
              Map<String, dynamic>.from(e.value as Map),
            ),
      },
      savedBy: data['savedBy'] as String?,
      savedAt: (data['savedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// One player as copied on a team sheet (3.2): what the sheet shows, no
/// photo and no date of birth (the opponent can read it after the lock).
class SheetPlayer {
  const SheetPlayer({
    required this.id,
    required this.name,
    required this.position,
    required this.usual,
    this.code,
    this.ageGroup,
  });

  SheetPlayer.fromPlayer(Player p)
    : id = p.id,
      name = p.fullName.trim(),
      position = p.position.code,
      usual = p.jerseyNo,
      code = p.playerCode,
      ageGroup = p.isJuvenile ? p.ageGroup : null;

  final String id;
  final String name;

  /// "CB"
  final String position;

  /// The registered (usual) shirt number.
  final int usual;

  /// The player ID, "GE26-0004".
  final String? code;

  /// Juveniles only.
  final AgeGroup? ageGroup;

  Map<String, dynamic> toMap() => {
    'name': name,
    'position': position,
    'usual': usual,
    'code': ?code,
    'ageGroup': ?ageGroup?.label,
  };

  static SheetPlayer fromMap(String id, Map<String, dynamic> m) => SheetPlayer(
    id: id,
    name: m['name'] as String? ?? '',
    position: m['position'] as String? ?? '',
    usual: (m['usual'] as num?)?.toInt() ?? 0,
    code: m['code'] as String?,
    ageGroup: AgeGroup.fromString(m['ageGroup'] as String?),
  );
}
