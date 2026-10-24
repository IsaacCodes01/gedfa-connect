import 'package:gedfa_connect/core/constants/user_role.dart';

/// An FA admin or referee (`users/{uid}` with one of those roles).
class Member {
  const Member({
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    this.isChairman = false,
    this.inviteId,
  });

  final String uid;
  final UserRole role;
  final String name;
  final String email;
  final bool isChairman;

  /// The accepted invitation (null for the chairman, set up by hand).
  final String? inviteId;

  /// "Chairman", "FA official" or "Referee".
  String get roleLabel => isChairman ? 'Chairman' : roleLabelFor(role);

  factory Member.fromMap(String uid, Map<String, dynamic> data) {
    return Member(
      uid: uid,
      role: UserRole.fromString(data['role'] as String?) ?? UserRole.referee,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      isChairman: data['isChairman'] == true,
      inviteId: data['inviteId'] as String?,
    );
  }
}

/// What people call each invitable role.
String roleLabelFor(UserRole role) => switch (role) {
      UserRole.faAdmin => 'FA official',
      UserRole.referee => 'Referee',
      UserRole.teamAdmin => 'Team admin',
    };
