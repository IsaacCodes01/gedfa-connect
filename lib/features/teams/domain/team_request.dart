import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/teams/domain/club_status.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

class TeamRequest {
  const TeamRequest({
    required this.uid,
    required this.teamName,
    required this.shortName,
    required this.town,
    required this.homeGround,
    required this.homeKit,
    required this.awayKit,
    required this.goalkeeperKit,
    required this.officials,
    required this.status,
    this.homeGroundDirections,
    required this.categories,
    this.clubStatus = ClubStatus.existing,
    this.lastLeague,
    this.letterUrl,
    this.licenceUrl,
    this.licenceIsPdf = false,
    this.yearFounded,
    this.email,
    this.logoUrl,
    this.thirdKit,
    this.goalkeeperKit2,
    this.juvenileKits = const {},
    this.colours,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  // Section 1: club details
  final String uid;
  final String teamName;
  final String shortName;
  final String town;
  final String homeGround;
  final String? homeGroundDirections;
  final int? yearFounded;
  final String? email;
  final String? logoUrl;
  // Competitions: division, juvenile, or both
  final Set<Competition> categories;

  // Section 2: club status (2.13)
  final ClubStatus clubStatus;

  /// New clubs only: the league they played in last season.
  final String? lastLeague;

  /// New clubs only: their letter to the GEDFA chairman (PDF).
  final String? letterUrl;

  /// Optional club licence, a photo or a PDF.
  final String? licenceUrl;
  final bool licenceIsPdf;

  // Section 3: kits
  final Kit homeKit;
  final Kit awayKit;
  final Kit? thirdKit;
  final Kit goalkeeperKit;
  final Kit? goalkeeperKit2;

  /// A club in both competitions: the juvenile sides' own kits (2.13b).
  /// Empty otherwise: a club in one competition has only `kits`.
  final Map<KitSlot, Kit> juvenileKits;

  bool get hasSeparateJuvenileKits => categories.length > 1;

  /// Behind the initials when the logo can't load: the home colour, or
  /// the home shirt on requests sent before team colours.
  Color get logoColor => colours?.home.main ?? homeKit.primary;

  /// Home and away colours (2.13b). Null on requests sent before.
  final TeamColours? colours;

  /// The Division kits as one map, like [juvenileKits].
  Map<KitSlot, Kit> get divisionKits => {
        KitSlot.home: homeKit,
        KitSlot.away: awayKit,
        KitSlot.goalkeeper: goalkeeperKit,
        KitSlot.third: ?thirdKit,
        KitSlot.goalkeeper2: ?goalkeeperKit2,
      };

  // Section 4: officials
  final List<Official> officials;

  // Review
  final ApprovalStatus status;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canEdit =>
      status == ApprovalStatus.pending || status == ApprovalStatus.rejected;

  Official? officialFor(OfficialRole role) {
    for (final official in officials) {
      if (official.role == role) return official;
    }
    return null;
  }

  Map<String, dynamic> toEditableMap() {
    String? blankToNull(String? value) {
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    return {
      'teamName': teamName.trim(),
      'shortName': shortName.trim().toUpperCase(),
      'town': town.trim(),
      'homeGround': homeGround.trim(),
      'homeGroundDirections': blankToNull(homeGroundDirections),
      'yearFounded': yearFounded,
      'email': blankToNull(email),
      'logoUrl': logoUrl,
      'categories': Competition.toList(categories),
      'clubStatus': clubStatus.value,
      // Only new clubs keep a league and a letter
      'lastLeague':
          clubStatus == ClubStatus.newClub ? blankToNull(lastLeague) : null,
      'letterUrl': clubStatus == ClubStatus.newClub ? letterUrl : null,
      'licenceUrl': licenceUrl,
      'licenceType':
          licenceUrl == null ? null : (licenceIsPdf ? 'pdf' : 'image'),
      'kits': {
        'home': homeKit.toMap(),
        'away': awayKit.toMap(),
        'goalkeeper': goalkeeperKit.toMap(),
        if (thirdKit != null) 'third': thirdKit!.toMap(),
        if (goalkeeperKit2 != null) 'goalkeeper2': goalkeeperKit2!.toMap(),
      },
      // A club in both competitions keeps separate juvenile kits.
      // A club in one competition has just `kits`.
      'juvenileKits': hasSeparateJuvenileKits
          ? {
              for (final entry in juvenileKits.entries)
                entry.key.name: entry.value.toMap(),
            }
          : null,
      'colours': colours?.toMap(),
      'officials': officials.map((official) => official.toMap()).toList(),
    };
  }

  factory TeamRequest.fromMap(String uid, Map<String, dynamic> data) {
    final kits = data['kits'] as Map<String, dynamic>?;

    Kit kitOrWhite(String key) =>
        Kit.fromMap(kits?[key] as Map<String, dynamic>?) ??
        const Kit(
          primary: Color(0xFFFFFFFF),
          shorts: Color(0xFFFFFFFF),
          socks: Color(0xFFFFFFFF),
        );

    final juvenile = data['juvenileKits'] as Map<String, dynamic>?;

    final officials = (data['officials'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Official.fromMap)
        .whereType<Official>()
        .toList();

    return TeamRequest(
      uid: uid,
      teamName: data['teamName'] as String? ?? '',
      shortName: data['shortName'] as String? ?? '',
      town: data['town'] as String? ?? '',
      homeGround: data['homeGround'] as String? ?? '',
      homeGroundDirections: data['homeGroundDirections'] as String?,
      yearFounded: data['yearFounded'] as int?,
      email: data['email'] as String?,
      logoUrl: data['logoUrl'] as String?,
      categories: Competition.fromList(data['categories'] as List<dynamic>?),
      clubStatus: ClubStatus.fromString(data['clubStatus'] as String?),
      lastLeague: data['lastLeague'] as String?,
      letterUrl: data['letterUrl'] as String?,
      licenceUrl: data['licenceUrl'] as String?,
      licenceIsPdf: data['licenceType'] == 'pdf',
      homeKit: kitOrWhite('home'),
      awayKit: kitOrWhite('away'),
      thirdKit: Kit.fromMap(kits?['third'] as Map<String, dynamic>?),
      goalkeeperKit: kitOrWhite('goalkeeper'),
      goalkeeperKit2: Kit.fromMap(kits?['goalkeeper2'] as Map<String, dynamic>?),
      juvenileKits: {
          for (final slot in KitSlot.values)
          slot: ?Kit.fromMap(juvenile?[slot.name] as Map<String, dynamic>?),
      },
      colours: TeamColours.fromMap(data['colours'] as Map<String, dynamic>?),
      officials: officials,
      status: ApprovalStatus.fromString(data['status'] as String? ?? 'pending'),
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}