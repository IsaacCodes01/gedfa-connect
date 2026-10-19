enum UserRole {
  faAdmin('FA admin'),
  teamAdmin('Team admin'),
  referee('Referee');

  const UserRole(this.label);

  /// Shown to people, e.g. on the Settings account card.
  final String label;

  static UserRole? fromString(String? value) {
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }
}
