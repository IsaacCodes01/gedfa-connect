import 'package:flutter/material.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/suspension.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';

/// What a suspended team reads when it tries to add or edit (2.11c).
const suspendedMessage =
    'Your team is suspended. You can add and edit again once the FA lifts '
    'it. Contact the FA.';

/// An approved team (`teams/{teamId}`).
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.town,
    required this.categories,
    required this.adminUids,
    this.logoUrl,
    this.homeKit,
    this.colours,
    this.requestUid,
    this.suspension,
  });

  final String id;
  final String name;
  final String shortName;
  final String town;
  final Set<Competition> categories;
  final List<String> adminUids;
  final String? logoUrl;
  final Kit? homeKit;

  /// Home and away colours (2.13b); null for teams approved before.
  final TeamColours? colours;

  /// The club's account that registered the team. Its season fee is kept
  /// under this uid (2.13c).
  final String? requestUid;

  /// Set by the chairman (2.11c); may have ended (see [isSuspended]).
  final Suspension? suspension;

  /// Suspended now: no adding or editing players, profile edits or
  /// change requests.
  bool get isSuspended => suspension?.isActive ?? false;

  /// Colour behind the initials when there is no logo.
  Color get logoColor =>
      colours?.home.main ?? homeKit?.primary ?? const Color(0xFF1E88E5);

  bool get hasBoth => categories.length > 1;

  factory Team.fromMap(String id, Map<String, dynamic> data) {
    final kits = data['kits'] as Map<String, dynamic>?;
    return Team(
      id: id,
      name: data['name'] as String? ?? '',
      shortName: data['shortName'] as String? ?? '',
      town: data['town'] as String? ?? '',
      categories: Competition.fromList(data['categories'] as List<dynamic>?),
      adminUids: [
        for (final uid in data['adminUids'] as List<dynamic>? ?? const [])
          if (uid is String) uid,
      ],
      logoUrl: data['logoUrl'] as String?,
      homeKit: Kit.fromMap(kits?['home'] as Map<String, dynamic>?),
      colours: TeamColours.fromMap(data['colours'] as Map<String, dynamic>?),
      requestUid: data['requestUid'] as String?,
      suspension: Suspension.fromTeamMap(
        data['suspension'] as Map<String, dynamic>?,
      ),
    );
  }
}
