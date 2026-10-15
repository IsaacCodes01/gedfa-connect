import 'package:gedfa_connect/core/constants/user_role.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.role,
    this.teamId,
    this.displayName,
    this.email,
  });

  final String uid;
  final UserRole? role;
  final String? teamId;
  final String? displayName;
  final String? email;

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      role: UserRole.fromString(data['role'] as String?),
      teamId: data['teamId'] as String?,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
    );
  }
}