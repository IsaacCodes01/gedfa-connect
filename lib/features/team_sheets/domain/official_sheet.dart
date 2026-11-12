import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';

/// The official team sheet of a match (3.3, mockup MC4): what the paper
/// says, worked out from the match, the saved sheets and the officials.
/// Pure (no Flutter, no PDF), so the tests read it line by line;
/// `official_sheet_pdf.dart` draws it.
///
/// Two kinds: the official sheet with both teams (the FA and the match
/// officials), or one team's own sheet ([of] with `onlyTeamId`, 3.3b), which
/// a team prints for itself.
class OfficialSheet {
  const OfficialSheet({
    required this.title,
    required this.heading,
    required this.roundLabel,
    required this.matchLine,
    required this.whenWhere,
    required this.teams,
    required this.officials,
    required this.fileName,
    this.draftNote,
  });

  /// "Official team sheet", or "Team sheet" for one team's own copy.
  final String title;

  /// "GOMOA EAST DFA · DIVISION LEAGUE"
  final String heading;

  /// "Matchday 4"
  final String roundLabel;

  /// "Royal Unique FC v Asebu Stars"
  final String matchLine;

  /// "Sat 14 Nov 2026, 3:00 pm · Apam Park"
  final String whenWhere;

  /// Before the lock the sheets can still change, so the paper says DRAFT.
  final String? draftNote;

  /// Home then away; just the one team on a team's own copy.
  final List<OfficialSheetTeam> teams;

  /// True on a team's own copy (one team, one captain's line).
  bool get isOneTeam => teams.length == 1;

  /// The five places in order, with the appointed name or null (a blank
  /// line to write on).
  final List<(String, String?)> officials;

  /// "gedfa-sheet-RUF-v-AST-2026-11-14.pdf"
  final String fileName;

  static OfficialSheet of({
    required Fixture fixture,
    required TeamSheet? homeSheet,
    required TeamSheet? awaySheet,
    required MatchOfficials? officials,
    required DateTime now,
    String? onlyTeamId,
  }) {
    final f = fixture;
    final kickoff = f.kickoffAt;
    final due = f.sheetDueAt;
    final group = f.ageGroup;
    final date = kickoff == null
        ? 'Date to be fixed'
        : '${formatShortDate(kickoff)} ${kickoff.toLocal().year}, '
              '${formatTime(kickoff)}';
    String two(int n) => n.toString().padLeft(2, '0');
    String short(FixtureSide s) =>
        s.shortName.trim().replaceAll(RegExp(r'\s+'), '-');
    final day = kickoff?.toLocal();
    final one = onlyTeamId != null;
    final name = [
      one ? 'gedfa-teamsheet' : 'gedfa-sheet',
      short(f.home),
      'v',
      short(f.away),
      if (day != null) '${day.year}-${two(day.month)}-${two(day.day)}',
    ].join('-').replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
    return OfficialSheet(
      title: one ? 'Team sheet' : 'Official team sheet',
      heading: [
        'GOMOA EAST DFA',
        '${f.category.label} league'.toUpperCase(),
        ?group?.label,
      ].join(' · '),
      roundLabel: 'Matchday ${f.round}',
      matchLine: '${f.home.name} v ${f.away.name}',
      whenWhere: [
        date,
        if (f.venue.trim().isNotEmpty) f.venue.trim(),
      ].join(' · '),
      draftNote: due != null && now.isBefore(due)
          ? one
                ? 'DRAFT · you can change this sheet until '
                      '${formatShortDate(due)}, ${formatTime(due)}'
                : 'DRAFT · the teams can change their sheets until '
                      '${formatShortDate(due)}, ${formatTime(due)}'
          : null,
      teams: [
        if (!one || onlyTeamId == f.home.id)
          OfficialSheetTeam.of(f, f.home, homeSheet),
        if (!one || onlyTeamId == f.away.id)
          OfficialSheetTeam.of(f, f.away, awaySheet),
      ],
      officials: [
        for (final place in OfficialPlace.values)
          (place.label, officials?[place]?.name),
      ],
      fileName: '$name.pdf',
    );
  }
}

/// One team's half of the paper: its kit, players, officials and captain.
class OfficialSheetTeam {
  const OfficialSheetTeam({
    required this.name,
    required this.sideLabel,
    required this.kit,
    required this.kitLabel,
    required this.goalkeeperKit,
    required this.goalkeeperKitLabel,
    required this.saved,
    this.starters = const [],
    this.bench = const [],
    this.teamOfficials = const [],
    this.captain,
  });

  final String name;

  /// "Home" or "Away"
  final String sideLabel;
  final Kit kit;

  /// "Home kit"
  final String kitLabel;
  final Kit goalkeeperKit;
  final String goalkeeperKitLabel;

  /// False when the team saved no sheet: the paper says so.
  final bool saved;
  final List<OfficialSheetLine> starters;
  final List<OfficialSheetLine> bench;

  /// (role, name): "Team manager", "Kofi Mensah".
  final List<(String, String)> teamOfficials;

  /// The captain's line, for the signature ("4 Emmanuel Tetteh").
  final String? captain;

  static OfficialSheetTeam of(Fixture f, FixtureSide side, TeamSheet? s) {
    final kit = f.kitOf(side.id);
    final gk = side.id == f.home.id ? f.kits.homeGk : f.kits.awayGk;
    OfficialSheetLine line(String id) {
      final p = s!.players[id];
      final number = s.numbers[id];
      final usual = p?.usual ?? 0;
      final group = p?.ageGroup;
      return OfficialSheetLine(
        number: number,
        name: p?.name ?? 'Player (saved before names were copied)',
        position: p?.position ?? '',
        code: p?.code,
        roles: [
          if (id == s.captainId) 'C',
          if (id == s.viceCaptainId) 'VC',
          if (id == s.goalkeeperId) 'GK',
        ],
        // A juvenile in the Division, or playing up (as on the screen)
        ageGroup: group != null && group != f.ageGroup ? group.label : null,
        usual: usual > 0 && usual != number ? usual : null,
      );
    }

    final captainId = s?.captainId;
    final captainLine = captainId == null ? null : line(captainId);
    return OfficialSheetTeam(
      name: side.name,
      sideLabel: f.isHome(side.id) ? 'Home' : 'Away',
      kit: kit.kit,
      kitLabel: kit.slot.label,
      goalkeeperKit: gk.kit,
      goalkeeperKitLabel: gk.slot.label,
      saved: s != null,
      starters: [
        if (s != null)
          for (final id in s.starters) line(id),
      ],
      bench: [
        if (s != null)
          for (final id in s.bench) line(id),
      ],
      teamOfficials: [
        if (s != null)
          for (final o in s.officials) (o.roleText, o.name),
      ],
      captain: captainLine == null
          ? null
          : [?captainLine.number?.toString(), captainLine.name].join(' '),
    );
  }
}

/// One player on the paper: "4 · Emmanuel Tetteh (C) · CB · GE26-0004".
class OfficialSheetLine {
  const OfficialSheetLine({
    required this.number,
    required this.name,
    required this.position,
    this.code,
    this.roles = const [],
    this.ageGroup,
    this.usual,
  });

  /// The shirt number for this match.
  final int? number;
  final String name;
  final String position;

  /// The player ID, "GE26-0004".
  final String? code;

  /// "C", "VC", "GK" (for this match).
  final List<String> roles;

  /// "U15" for a juvenile in the Division or playing up.
  final String? ageGroup;

  /// The registered number, only when it differs from [number].
  final int? usual;

  /// "Emmanuel Tetteh (C)"
  String get nameWithRoles =>
      roles.isEmpty ? name : '$name (${roles.join(', ')})';
}
