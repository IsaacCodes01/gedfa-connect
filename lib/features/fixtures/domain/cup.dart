import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// A cup, or a gala: a one-off straight knockout at one ground (GEDFA
/// plays one before the season starts).
enum CupKind {
  cup('Cup'),
  gala('Gala');

  const CupKind(this.label);

  final String label;

  static CupKind fromString(String? value) =>
      values.firstWhere((k) => k.name == value, orElse: () => CupKind.cup);
}

/// Who plays: Division clubs, one juvenile age group, or an open cup with
/// Division and juvenile sides together (like the Ghana FA Cup).
enum CupWho {
  division('Division'),
  juvenile('Juvenile'),
  open('Open');

  const CupWho(this.label);

  final String label;

  static CupWho fromString(String? value) =>
      values.firstWhere((w) => w.name == value, orElse: () => CupWho.division);
}

enum CupFormat {
  knockout,
  groups;

  static CupFormat fromString(String? value) => values
      .firstWhere((f) => f.name == value, orElse: () => CupFormat.knockout);
}

/// What happens when a tie is level after 90 minutes (or on aggregate
/// after two legs; no away goals). The FA picks it for each cup.
enum LevelRule {
  penalties('Penalties'),
  extraTime('Extra time, then penalties'),
  replay('Replay');

  const LevelRule(this.label);

  final String label;

  static LevelRule fromString(String? value) => values
      .firstWhere((r) => r.name == value, orElse: () => LevelRule.penalties);
}

/// Where a cup is: only `notDrawn` in 3.0c1; the draw (3.0c2) moves it on.
enum CupStage {
  notDrawn;

  static CupStage fromString(String? value) =>
      values.firstWhere((s) => s.name == value, orElse: () => notDrawn);
}

/// One side in a cup: a club's Division side or its juvenile side. A club
/// in both competitions can have both sides in an open cup.
class CupEntry {
  const CupEntry({required this.teamId, required this.category});

  final String teamId;
  final Competition category;

  Map<String, dynamic> toMap() => {
        'teamId': teamId,
        'category': category.name,
      };

  static CupEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final teamId = raw['teamId'];
    final category = Competition.fromString(raw['category'] as String?);
    if (teamId is! String || category == null) return null;
    return CupEntry(teamId: teamId, category: category);
  }

  /// 'royal:division', to tell the sides apart in a set.
  String get key => '$teamId:${category.name}';
}

/// A gala's ground and days (C2b).
class GalaSettings {
  const GalaSettings({
    required this.ground,
    required this.firstDay,
    required this.lastDay,
    required this.kickoffHour,
    required this.kickoffMinute,
    required this.gapMinutes,
  });

  final String ground;
  final DateTime firstDay;
  final DateTime lastDay;
  final int kickoffHour;
  final int kickoffMinute;

  /// Minutes from one kick-off to the next.
  final int gapMinutes;

  Map<String, dynamic> toMap() => {
        'ground': ground.trim(),
        'firstDay': Timestamp.fromDate(firstDay),
        'lastDay': Timestamp.fromDate(lastDay),
        'kickoffHour': kickoffHour,
        'kickoffMinute': kickoffMinute,
        'gapMinutes': gapMinutes,
      };

  static GalaSettings? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final first = (raw['firstDay'] as Timestamp?)?.toDate();
    final last = (raw['lastDay'] as Timestamp?)?.toDate();
    if (first == null || last == null) return null;
    return GalaSettings(
      ground: raw['ground'] as String? ?? '',
      firstDay: first,
      lastDay: last,
      kickoffHour: (raw['kickoffHour'] as num?)?.toInt() ?? 9,
      kickoffMinute: (raw['kickoffMinute'] as num?)?.toInt() ?? 0,
      gapMinutes: (raw['gapMinutes'] as num?)?.toInt() ?? 90,
    );
  }
}

/// `cups/{cupId}`: a cup or a gala of one season (3.0c1). Made by the FA,
/// read by everyone with a role. Its matches are ordinary `fixtures` with
/// this cup's ID as their `competitionId` (from the draw, 3.0c2).
class Cup {
  const Cup({
    required this.id,
    required this.season,
    required this.kind,
    required this.name,
    required this.who,
    required this.entries,
    required this.format,
    required this.legs,
    required this.level,
    required this.bracketFrom,
    required this.seeded,
    required this.stage,
    this.ageGroup,
    this.gala,
    this.createdAt,
  });

  final String id;
  final String season;
  final CupKind kind;
  final String name;
  final CupWho who;

  /// Juvenile: the age group. Open: the age group of the juvenile sides.
  final AgeGroup? ageGroup;
  final List<CupEntry> entries;
  final CupFormat format;

  /// 1 = one match, 2 = home and away. The final is always one match, at
  /// a ground the FA picks (GEDFA, 8 Nov 2026).
  final int legs;

  final LevelRule level;

  /// The bracket is fixed from the round with this many clubs left (8 =
  /// quarter-finals); 0 = the whole draw at once.
  final int bracketFrom;

  /// Pots from the standings; off = fully random.
  final bool seeded;
  final CupStage stage;

  /// Galas only.
  final GalaSettings? gala;
  final DateTime? createdAt;

  bool get isGala => kind == CupKind.gala;

  /// "Division", "U17" or "Open"
  String get whoLabel => switch (who) {
        CupWho.juvenile => ageGroup?.label ?? 'Juvenile',
        _ => who.label,
      };

  /// What the FA writes to `cups/{id}` (without the who and when).
  Map<String, dynamic> toMap() => {
        'season': season,
        'kind': kind.name,
        'name': name.trim(),
        'category': who.name,
        if (who != CupWho.division) 'ageGroup': ?ageGroup?.label,
        'entries': [for (final e in entries) e.toMap()],
        'format': format.name,
        'legs': legs,
        'level': level.name,
        'bracketFrom': bracketFrom,
        'seeded': seeded,
        'stage': stage.name,
        if (isGala) 'gala': ?gala?.toMap(),
      };

  static Cup fromMap(String id, Map<String, dynamic> data) => Cup(
        id: id,
        season: data['season'] as String? ?? '',
        kind: CupKind.fromString(data['kind'] as String?),
        name: data['name'] as String? ?? '',
        who: CupWho.fromString(data['category'] as String?),
        ageGroup: AgeGroup.fromString(data['ageGroup'] as String?),
        entries: [
          for (final e in data['entries'] as List<dynamic>? ?? const [])
            ?CupEntry.fromMap(e),
        ],
        format: CupFormat.fromString(data['format'] as String?),
        legs: (data['legs'] as num?)?.toInt() ?? 1,
        level: LevelRule.fromString(data['level'] as String?),
        bracketFrom: (data['bracketFrom'] as num?)?.toInt() ?? 0,
        seeded: data['seeded'] as bool? ?? false,
        stage: CupStage.fromString(data['stage'] as String?),
        gala: GalaSettings.fromMap(data['gala']),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
}
