import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';

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
    this.yearFounded,
    this.email,
    this.logoUrl,
    this.thirdKit,
    this.goalkeeperKit2,
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

  // Section 2: kits
  final Kit homeKit;
  final Kit awayKit;
  final Kit? thirdKit;
  final Kit goalkeeperKit;
  final Kit? goalkeeperKit2;

  // Section 3: officials
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
      'kits': {
        'home': homeKit.toMap(),
        'away': awayKit.toMap(),
        'goalkeeper': goalkeeperKit.toMap(),
        if (thirdKit != null) 'third': thirdKit!.toMap(),
        if (goalkeeperKit2 != null) 'goalkeeper2': goalkeeperKit2!.toMap(),
      },
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
      homeKit: kitOrWhite('home'),
      awayKit: kitOrWhite('away'),
      thirdKit: Kit.fromMap(kits?['third'] as Map<String, dynamic>?),
      goalkeeperKit: kitOrWhite('goalkeeper'),
      goalkeeperKit2: Kit.fromMap(kits?['goalkeeper2'] as Map<String, dynamic>?),
      officials: officials,
      status: ApprovalStatus.fromString(data['status'] as String? ?? 'pending'),
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}