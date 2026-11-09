import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/utils/color_hex.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/side_name.dart';

enum FixtureStatus {
  scheduled,
  postponed,
  cancelled;

  static FixtureStatus fromString(String? value) => values.firstWhere(
    (s) => s.name == value,
    orElse: () => FixtureStatus.scheduled,
  );
}

/// One side of a match, copied from the team when the FA saves the match
/// (teams can't read each other's team documents). The rules check the
/// copy matches the team.
class FixtureSide {
  const FixtureSide({
    required this.id,
    required this.name,
    required this.shortName,
    required this.colour,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String shortName;
  final String? logoUrl;

  /// The team's main home colour: behind the initials when there's no logo.
  final Color colour;

  /// A club's juvenile side playing as its name with " B" ("RUF B"): its
  /// crest gets a gold ring (juvenile side names, mockup JS5).
  bool get isBSide => isBSideShortName(shortName);

  /// What goes on the crest: "RUF" for "RUF B" (the ring says "B").
  String get crestLabel =>
      isBSide ? shortName.substring(0, shortName.length - 2) : shortName;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'logoUrl': logoUrl,
    'colour': colorToHex(colour),
  };

  static FixtureSide fromMap(Map<String, dynamic>? map) => FixtureSide(
    id: map?['id'] as String? ?? '',
    name: map?['name'] as String? ?? '',
    shortName: map?['shortName'] as String? ?? '',
    logoUrl: map?['logoUrl'] as String?,
    colour: colorFromHex(map?['colour'] as String?) ?? const Color(0xFF1E88E5),
  );
}

/// The kit a side wears in a match: which of the team's kits ([slot]), and
/// that kit as it was when the match was saved. [raw] is the kit exactly
/// as on the team document (the rules compare it key by key).
class KitChoice {
  const KitChoice({required this.slot, required this.kit, required this.raw});

  final KitSlot slot;
  final Kit kit;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toMap() => {'slot': slot.name, 'kit': raw};

  static KitChoice? fromMap(Map<String, dynamic>? map) {
    final raw = map?['kit'] as Map<String, dynamic>?;
    final kit = Kit.fromMap(raw);
    final slot = KitSlot.values
        .where((s) => s.name == map?['slot'])
        .firstOrNull;
    if (raw == null || kit == null || slot == null) return null;
    return KitChoice(slot: slot, kit: kit, raw: raw);
  }
}

/// The four kits of a match: both outfield kits and both goalkeepers.
class MatchKits {
  const MatchKits({
    required this.home,
    required this.away,
    required this.homeGk,
    required this.awayGk,
  });

  final KitChoice home;
  final KitChoice away;
  final KitChoice homeGk;
  final KitChoice awayGk;

  Map<String, dynamic> toMap() => {
    'home': home.toMap(),
    'away': away.toMap(),
    'homeGk': homeGk.toMap(),
    'awayGk': awayGk.toMap(),
  };

  static MatchKits? fromMap(Map<String, dynamic>? map) {
    KitChoice? read(String key) =>
        KitChoice.fromMap(map?[key] as Map<String, dynamic>?);
    final home = read('home');
    final away = read('away');
    final homeGk = read('homeGk');
    final awayGk = read('awayGk');
    if (home == null || away == null || homeGk == null || awayGk == null) {
      return null;
    }
    return MatchKits(home: home, away: away, homeGk: homeGk, awayGk: awayGk);
  }
}

/// `fixtures/{id}`: one match (3.0a). Made by the FA; teams and referees
/// read it. Never deleted: a called-off match is cancelled instead.
class Fixture {
  const Fixture({
    required this.id,
    required this.season,
    required this.competitionId,
    required this.category,
    required this.round,
    required this.home,
    required this.away,
    required this.kits,
    required this.venue,
    required this.status,
    this.ageGroup,
    this.kickoffAt,
    this.note,
  });

  final String id;
  final String season;
  final String competitionId;
  final Competition category;

  /// Juvenile matches only: U13, U15 or U17.
  final AgeGroup? ageGroup;

  /// The matchday (league) number, 1 to 99.
  final int round;
  final FixtureSide home;
  final FixtureSide away;
  final MatchKits kits;

  /// Empty only while postponed with no new date yet.
  final DateTime? kickoffAt;
  final String venue;
  final FixtureStatus status;

  /// Why it was postponed, cancelled or last changed (teams read it).
  final String? note;

  /// GEDFA: team sheets are due 1 hour before kick-off.
  static const sheetLead = Duration(hours: 1);

  /// After this long past kick-off, a match counts as played.
  static const matchLength = Duration(hours: 2);

  /// The league of a season: '2026-27_division-league'.
  static String leagueId(String season, Competition category) =>
      '${season}_${category.name}-league';

  DateTime? get sheetDueAt => kickoffAt?.subtract(sheetLead);

  bool get isScheduled => status == FixtureStatus.scheduled;
  bool get isPostponed => status == FixtureStatus.postponed;
  bool get isCancelled => status == FixtureStatus.cancelled;

  /// Kicked off more than [matchLength] ago and not called off.
  bool isPlayed(DateTime now) =>
      isScheduled &&
      kickoffAt != null &&
      now.isAfter(kickoffAt!.add(matchLength));

  bool hasTeam(String teamId) => home.id == teamId || away.id == teamId;
  bool isHome(String teamId) => home.id == teamId;
  FixtureSide opponentOf(String teamId) => isHome(teamId) ? away : home;
  KitChoice kitOf(String teamId) => isHome(teamId) ? kits.home : kits.away;

  /// "Division" or "U15"
  String get competitionLabel => ageGroup?.label ?? category.label;

  static Fixture? fromMap(String id, Map<String, dynamic> data) {
    final kits = MatchKits.fromMap(data['kits'] as Map<String, dynamic>?);
    final category = Competition.fromString(data['category'] as String?);
    if (kits == null || category == null) return null;
    return Fixture(
      id: id,
      season: data['season'] as String? ?? '',
      competitionId: data['competitionId'] as String? ?? '',
      category: category,
      ageGroup: AgeGroup.fromString(data['ageGroup'] as String?),
      round: (data['round'] as num?)?.toInt() ?? 1,
      home: FixtureSide.fromMap(data['home'] as Map<String, dynamic>?),
      away: FixtureSide.fromMap(data['away'] as Map<String, dynamic>?),
      kits: kits,
      kickoffAt: (data['kickoffAt'] as Timestamp?)?.toDate(),
      venue: data['venue'] as String? ?? '',
      status: FixtureStatus.fromString(data['status'] as String?),
      note: data['note'] as String?,
    );
  }
}

/// Juvenile match rules from the GFA colts guidelines (2023/24), shown on
/// juvenile matches. Asked GEDFA to confirm (7 Nov 2026).
extension JuvenileMatchRules on AgeGroup {
  /// "2 × 45 min"
  String get matchLengthText => switch (this) {
    AgeGroup.u17 => '2 × 45 min',
    AgeGroup.u15 => '2 × 40 min',
    AgeGroup.u13 => '2 × 25 min',
  };

  /// Who may play up into this group, or null for U13.
  String? get playUpText => switch (this) {
    AgeGroup.u17 => 'Up to 1 U13 and 5 U15 playing up',
    AgeGroup.u15 => 'U13 players may play up',
    AgeGroup.u13 => null,
  };
}
