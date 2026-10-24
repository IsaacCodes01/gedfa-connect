import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';

/// How long an invitation stays open.
const inviteLifetime = Duration(days: 14);

/// The invitation's document ID: the email, trimmed and in lower case.
String inviteIdFor(String email) => email.trim().toLowerCase();

/// `invites/{email}`: someone the FA invited as an FA official or referee.
class Invite {
  const Invite({
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.invitedBy,
    required this.invitedByName,
    this.createdAt,
    this.expiresAt,
  });

  final String email; // also the document ID
  final String name;
  final UserRole role; // faAdmin (FA official) or referee
  final String status; // 'pending' or 'accepted'
  final String invitedBy;
  final String invitedByName;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Still waiting, and not expired: the person can accept it.
  bool get isOpen => status == 'pending' && !isExpired;

  /// Whole days left, at least 0.
  int get daysLeft {
    final end = expiresAt;
    if (end == null) return 0;
    final days = end.difference(DateTime.now()).inHours / 24;
    return days < 0 ? 0 : days.ceil();
  }

  factory Invite.fromMap(String id, Map<String, dynamic> data) {
    return Invite(
      email: data['email'] as String? ?? id,
      name: data['name'] as String? ?? '',
      role: UserRole.fromString(data['role'] as String?) ?? UserRole.referee,
      status: data['status'] as String? ?? 'pending',
      invitedBy: data['invitedBy'] as String? ?? '',
      invitedByName: data['invitedByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}
