import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/utils/search_keys.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

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

  PositionGroup get positionGroup => position.group;

  bool get isApproved => status == ApprovalStatus.approved;

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
    );
  }
}
