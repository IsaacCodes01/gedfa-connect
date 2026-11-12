import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';

/// The commissioner's answer for one player (3.6b, mockup MC2). A mismatch
/// is recorded for the FA and the match report, not struck off the sheet
/// (Isaac, 11 Nov 2026).
enum CheckResult {
  match('Matches'),
  mismatch("Doesn't match"),
  absent('Absent');

  const CheckResult(this.label);

  final String label;

  static CheckResult? fromString(String? value) {
    for (final r in values) {
      if (r.name == value) return r;
    }
    return null;
  }
}

/// One player's check: the answer, a note (required for a mismatch), the
/// team and when.
class PlayerCheck {
  const PlayerCheck({
    required this.result,
    required this.teamId,
    this.note,
    this.at,
  });

  final CheckResult result;
  final String teamId;
  final String? note;
  final DateTime? at;

  static PlayerCheck? fromMap(Object? map) {
    if (map is! Map) return null;
    final result = CheckResult.fromString(map['result'] as String?);
    final teamId = map['teamId'];
    if (result == null || teamId is! String) return null;
    final note = map['note'];
    return PlayerCheck(
      result: result,
      teamId: teamId,
      note: note is String && note.trim().isNotEmpty ? note : null,
      at: (map['at'] as Timestamp?)?.toDate(),
    );
  }
}

/// `playerChecks/{fixtureId}`: the face check of one match, written by its
/// commissioner, one player per write (3.6b).
class MatchPlayerChecks {
  const MatchPlayerChecks({
    required this.fixtureId,
    this.results = const {},
    this.byName,
    this.updatedAt,
  });

  /// "Doesn't match" needs a note this long (the rules agree).
  static const minNote = 3;
  static const maxNote = 300;

  final String fixtureId;

  /// Player ID → their check.
  final Map<String, PlayerCheck> results;
  final String? byName;
  final DateTime? updatedAt;

  PlayerCheck? operator [](String playerId) => results[playerId];

  /// The write for one player: merged into the document (it is made by
  /// the first one).
  static Map<String, dynamic> entryWrite({
    required String fixtureId,
    required String playerId,
    required String teamId,
    required CheckResult result,
    String? note,
    required String by,
    required String byName,
  }) {
    final text = note?.trim();
    return {
      'fixtureId': fixtureId,
      'results': {
        playerId: {
          'result': result.name,
          'teamId': teamId,
          'at': FieldValue.serverTimestamp(),
          // A changed answer must not keep an old note (the write merges)
          'note': text != null && text.isNotEmpty ? text : FieldValue.delete(),
        },
      },
      'changed': playerId,
      'by': by,
      'byName': byName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static MatchPlayerChecks fromMap(String id, Map<String, dynamic>? data) {
    final raw = data?['results'];
    return MatchPlayerChecks(
      fixtureId: id,
      results: {
        if (raw is Map)
          for (final e in raw.entries)
            if (e.key is String) e.key as String: ?PlayerCheck.fromMap(e.value),
      },
      byName: data?['byName'] as String?,
      updatedAt: (data?['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// When the commissioner may record the check: from the lock (1 h before
/// kick-off) until 2 h after kick-off (Isaac, 12 Nov 2026). The rules
/// agree.
class CheckWindow {
  const CheckWindow._();

  static const after = Duration(hours: 2);

  static DateTime? opensAt(Fixture f) => f.sheetDueAt;

  static DateTime? closesAt(Fixture f) => f.kickoffAt?.add(after);

  static bool isOpen(Fixture f, DateTime now) {
    final open = opensAt(f), close = closesAt(f);
    return open != null &&
        close != null &&
        !now.isBefore(open) &&
        !now.isAfter(close);
  }
}

/// One player to check, from a saved sheet's copies.
class CheckLine {
  const CheckLine({
    required this.playerId,
    required this.teamId,
    required this.name,
    required this.position,
    required this.isBench,
    this.number,
    this.code,
    this.usual,
    this.ageGroup,
  });

  final String playerId;
  final String teamId;
  final String name;
  final String position;
  final bool isBench;

  /// The shirt number for this match.
  final int? number;
  final String? code;

  /// The registered number, only when it differs from [number].
  final int? usual;

  /// "U15" for a juvenile in the Division or playing up.
  final String? ageGroup;

  /// "CF · GE26-0017 · usual number 17"
  String get detail => [
    if (position.isNotEmpty) position,
    ?code,
    ?ageGroup,
    if (usual case final u?) 'usual number $u',
  ].join(' · ');

  /// Every player on [sheet] in shirt order (no number last), starters and
  /// bench together, as the commissioner calls them out (MC2).
  static List<CheckLine> forSheet(TeamSheet sheet, Fixture f) {
    CheckLine line(String id, bool bench) {
      final p = sheet.players[id];
      final number = sheet.numbers[id];
      final usual = p?.usual ?? 0;
      final group = p?.ageGroup;
      return CheckLine(
        playerId: id,
        teamId: sheet.teamId,
        name: p?.name ?? 'Player',
        position: p?.position ?? '',
        isBench: bench,
        number: number,
        code: p?.code,
        usual: usual > 0 && usual != number ? usual : null,
        ageGroup: group != null && group != f.ageGroup ? group.label : null,
      );
    }

    final lines = [
      for (final id in sheet.starters) line(id, false),
      for (final id in sheet.bench) line(id, true),
    ];
    lines.sort((a, b) => (a.number ?? 1000).compareTo(b.number ?? 1000));
    return lines;
  }

  /// How many of [lines] have a check in [checks].
  static int checkedCount(List<CheckLine> lines, MatchPlayerChecks? checks) =>
      checks == null
      ? 0
      : lines.where((l) => checks[l.playerId] != null).length;

  /// The first unchecked line after [index] (wrapping round), or null when
  /// all are checked.
  static int? nextUnchecked(
    List<CheckLine> lines,
    MatchPlayerChecks? checks,
    int index,
  ) {
    for (var step = 1; step <= lines.length; step++) {
      final i = (index + step) % lines.length;
      if (checks?[lines[i].playerId] == null) return i;
    }
    return null;
  }
}
