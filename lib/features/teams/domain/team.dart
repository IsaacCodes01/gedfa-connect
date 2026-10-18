import 'package:flutter/material.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';

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
  });

  final String id;
  final String name;
  final String shortName;
  final String town;
  final Set<Competition> categories;
  final List<String> adminUids;
  final String? logoUrl;
  final Kit? homeKit;

  /// Colour behind the initials when there is no logo.
  Color get logoColor => homeKit?.primary ?? const Color(0xFF1E88E5);

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
    );
  }
}
