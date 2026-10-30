import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/utils/search_keys.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/core/utils/player_key.dart';

class Player {
  const Player({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.category,
    required this.fullName,
    required this.dob,
    required this.position,
    required this.jerseyNo,
    required this.status,
    this.playerCode,
    this.photoUrl,
    this.thumbUrl,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.changes = const {},
    this.ageGroup,
    this.guardian,
  });

  /// Firestore document ID ('' for a player not saved yet).
  final String id;

  // Team
  final String teamId;
  final String teamName;
  final Competition category;

  // Player
  final String fullName;
  final DateTime dob;
  final Position position;
  final int jerseyNo;
  final String? photoUrl;
  final String? thumbUrl;

  // FA review
  final ApprovalStatus status;
  final String? playerCode; // e.g. GE26-0042, only after approval
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;

  /// What the team changed since the FA last reviewed this player (2.3c),
  /// e.g. {'jerseyNo': PlayerChange('#10', '#14')}. Empty when nothing
  /// is waiting. Cleared by the FA's approval or rejection.
  final Map<String, PlayerChange> changes;

  /// Juvenile only (2.14): the group the player is registered in. It can
  /// be older than their own group (playing up), never younger.
  final AgeGroup? ageGroup;

  /// Juvenile only: parent or guardian (required).
  final Guardian? guardian;

  bool get isJuvenile => category == Competition.juvenile;

  /// Juvenile players wait for the FA's screening day instead of a review
  /// in the app (2.14).
  bool get isWaitingForScreening =>
      isJuvenile && status == ApprovalStatus.pending;

  /// The jersey reservation's ID: 'division-10' or 'juvenile-U13-10'.
  String get jerseyId =>
      jerseyIdFor(category.name, jerseyNo, ageGroup: ageGroup?.label);

  PositionGroup get positionGroup => position.group;

  bool get isApproved => status == ApprovalStatus.approved;

  /// The duplicate-check key, e.g. 'kwame-asante_2004-03-15'
  /// (juvenile players: '…_juvenile').
  String get playerKey =>
      competitionPlayerKey(playerKeyFor(fullName, dob), category.name);

  /// Age today, in full years.
  int get age {
    final now = DateTime.now();
    var years = now.year - dob.year;
    final hadBirthday = now.month > dob.month ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) years--;
    return years;
  }

  /// True if the search text matches the name or player ID.
  /// Used for the team admin's squad search (in the app, no extra reads).
  bool matches(String search) {
    final text = search.trim().toLowerCase();
    if (text.isEmpty) return true;
    return fullName.toLowerCase().contains(text) ||
        (playerCode?.toLowerCase().contains(text) ?? false) ||
        '#$jerseyNo' == text;
  }

  /// The fields a team admin writes. Status, player ID and dates
  /// are added by the repository.
  Map<String, dynamic> toEditableMap() {
    final name = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    return {
      'teamId': teamId,
      'teamName': teamName,
      'category': category.name,
      'fullName': name,
      'fullNameLower': name.toLowerCase(),
      'searchKeys': searchKeysFor(name),
      'playerKey': competitionPlayerKey(playerKeyFor(name, dob), category.name),
      if (isJuvenile) 'ageGroup': ageGroup?.label,
      if (isJuvenile) 'guardian': guardian?.toMap(),
      // Midnight UTC, so the date never shifts with time zones
      'dob': Timestamp.fromDate(DateTime.utc(dob.year, dob.month, dob.day)),
      'position': position.code,
      'positionGroup': position.group.code,
      'jerseyNo': jerseyNo,
      'photoUrl': photoUrl,
      'thumbUrl': thumbUrl,
    };
  }

  factory Player.fromMap(String id, Map<String, dynamic> data) {
    final dob = (data['dob'] as Timestamp?)?.toDate().toUtc();
    return Player(
      id: id,
      teamId: data['teamId'] as String? ?? '',
      teamName: data['teamName'] as String? ?? '',
      category: Competition.fromString(data['category'] as String?) ??
          Competition.division,
      fullName: data['fullName'] as String? ?? '',
      dob: dob == null
          ? DateTime(2000)
          : DateTime(dob.year, dob.month, dob.day),
      position: Position.fromCode(data['position'] as String?) ?? Position.cm,
      jerseyNo: (data['jerseyNo'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String?,
      thumbUrl: data['thumbUrl'] as String?,
      status: ApprovalStatus.fromString(data['status'] as String? ?? 'pending'),
      playerCode: data['playerCode'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      changes: PlayerChange.mapFrom(data['changes']),
      ageGroup: AgeGroup.fromString(data['ageGroup'] as String?),
      guardian: Guardian.fromMap(data['guardian']),
    );
  }
}

/// One change the team made, as text the FA can read: from → to.
/// For the photo, [from] and [to] are the two photo links.
class PlayerChange {
  const PlayerChange(this.from, this.to);

  final String from;
  final String to;

  Map<String, String> toMap() => {'from': from, 'to': to};

  static Map<String, PlayerChange> mapFrom(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key.toString(): PlayerChange(
            (entry.value as Map)['from']?.toString() ?? '',
            (entry.value as Map)['to']?.toString() ?? '',
          ),
    };
  }

  /// The order and names the FA sees.
  static const labels = {
    'fullName': 'Name',
    'dob': 'Date of birth',
    'jerseyNo': 'Jersey number',
    'position': 'Position',
    'photo': 'Passport photo',
  };
}
