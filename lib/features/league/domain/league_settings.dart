import 'package:gedfa_connect/core/constants/season.dart';

/// `settings/league`: the FA's switches and numbers (2.13d).
/// Missing values use the defaults below, so the app works before the FA
/// has saved anything.
class LeagueSettings {
  const LeagueSettings({
    this.teamRegistrationOpen = true,
    this.playerRegistrationOpen = true,
    this.maxSquadSize = 30,
    this.matchdaySquad = 16,
    this.matchdaySubs = 5,
    this.minPlayers = 7,
    this.season = Season.defaultSeason,
    this.fee = Season.defaultFee,
    this.momoNumber = Season.defaultMomoNumber,
  });

  /// New clubs can send a registration.
  final bool teamRegistrationOpen;

  /// Teams can add new players.
  final bool playerRegistrationOpen;

  /// Most players per competition (squad).
  final int maxSquadSize;

  /// Starting 11 + substitutes on a team sheet (Phase 3).
  final int matchdaySquad;

  /// Substitutions allowed in a match.
  final int matchdaySubs;

  /// Fewest players to start a match; the team sheet stays red until then.
  final int minPlayers;

  /// Chairman only: '2026-27'
  final String season;

  /// Chairman only: GH₵ per team per season.
  final int fee;

  /// Chairman only.
  final String momoNumber;

  /// The fields only the chairman may change.
  static const chairmanOnly = {'season', 'fee', 'momoNumber'};

  /// Readable names, for the history and the bell.
  static const labels = {
    'teamRegistrationOpen': 'Team registration',
    'playerRegistrationOpen': 'Player registration',
    'maxSquadSize': 'Squad size',
    'matchdaySquad': 'Matchday squad',
    'matchdaySubs': 'Substitutes',
    'minPlayers': 'Fewest players to start',
    'season': 'Season',
    'fee': 'Affiliation fee',
    'momoNumber': 'MoMo number',
  };

  Map<String, Object> toMap() => {
        'teamRegistrationOpen': teamRegistrationOpen,
        'playerRegistrationOpen': playerRegistrationOpen,
        'maxSquadSize': maxSquadSize,
        'matchdaySquad': matchdaySquad,
        'matchdaySubs': matchdaySubs,
        'minPlayers': minPlayers,
        'season': season,
        'fee': fee,
        'momoNumber': momoNumber,
      };

  /// The fields that differ from [before], as `{field: (from, to)}`.
  Map<String, ({Object from, Object to})> changesFrom(LeagueSettings before) {
    final old = before.toMap();
    return {
      for (final e in toMap().entries)
        if (old[e.key] != e.value) e.key: (from: old[e.key]!, to: e.value),
    };
  }

  LeagueSettings copyWith({
    bool? teamRegistrationOpen,
    bool? playerRegistrationOpen,
    int? maxSquadSize,
    int? matchdaySquad,
    int? matchdaySubs,
    int? minPlayers,
    String? season,
    int? fee,
    String? momoNumber,
  }) =>
      LeagueSettings(
        teamRegistrationOpen: teamRegistrationOpen ?? this.teamRegistrationOpen,
        playerRegistrationOpen:
            playerRegistrationOpen ?? this.playerRegistrationOpen,
        maxSquadSize: maxSquadSize ?? this.maxSquadSize,
        matchdaySquad: matchdaySquad ?? this.matchdaySquad,
        matchdaySubs: matchdaySubs ?? this.matchdaySubs,
        minPlayers: minPlayers ?? this.minPlayers,
        season: season ?? this.season,
        fee: fee ?? this.fee,
        momoNumber: momoNumber ?? this.momoNumber,
      );

  factory LeagueSettings.fromMap(Map<String, dynamic>? data) {
    const d = LeagueSettings();
    int number(String key, int fallback) =>
        (data?[key] as num?)?.toInt() ?? fallback;
    return LeagueSettings(
      teamRegistrationOpen:
          data?['teamRegistrationOpen'] as bool? ?? d.teamRegistrationOpen,
      playerRegistrationOpen:
          data?['playerRegistrationOpen'] as bool? ?? d.playerRegistrationOpen,
      maxSquadSize: number('maxSquadSize', d.maxSquadSize),
      matchdaySquad: number('matchdaySquad', d.matchdaySquad),
      matchdaySubs: number('matchdaySubs', d.matchdaySubs),
      minPlayers: number('minPlayers', d.minPlayers),
      season: data?['season'] as String? ?? d.season,
      fee: number('fee', d.fee),
      momoNumber: data?['momoNumber'] as String? ?? d.momoNumber,
    );
  }
}

/// "Open" / "Closed", "30", "GH₵ 1,000": a value as people read it.
String settingText(String field, Object value) => switch (value) {
      bool open => open ? 'open' : 'closed',
      int n when field == 'fee' => cedis(n),
      String s when field == 'season' => Season.label(s),
      _ => value.toString(),
    };
