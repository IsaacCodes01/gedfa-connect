import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';

/// One line of role history (`roleLog/{id}`), e.g. "Invited as referee by
/// Kofi Mensah". Never edited or deleted.
class RoleLogEntry {
  const RoleLogEntry({
    required this.action,
    required this.role,
    required this.byName,
    this.at,
  });

  /// 'invited', 'accepted', 'declined', 'cancelled' or 'removed'
  final String action;
  final UserRole role;
  final String byName;
  final DateTime? at;

  factory RoleLogEntry.fromMap(Map<String, dynamic> data) {
    return RoleLogEntry(
      action: data['action'] as String? ?? '',
      role: UserRole.fromString(data['role'] as String?) ?? UserRole.referee,
      byName: data['byName'] as String? ?? '',
      at: (data['at'] as Timestamp?)?.toDate(),
    );
  }
}
