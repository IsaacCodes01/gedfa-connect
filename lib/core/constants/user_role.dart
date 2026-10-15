enum UserRole {
  faAdmin,
  teamAdmin,
  referee;

  static UserRole? fromString(String? value) {
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }
}