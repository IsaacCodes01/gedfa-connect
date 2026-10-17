enum OfficialRole {
  teamManager,
  headCoach,
  assistantCoach,
  chairman,
  secretary,
  kitManager,
  medicalOfficer;

  static OfficialRole? fromString(String? value) {
    for (final role in OfficialRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }

  String get label => switch (this) {
        OfficialRole.teamManager => 'Team manager',
        OfficialRole.headCoach => 'Head coach',
        OfficialRole.assistantCoach => 'Assistant coach',
        OfficialRole.chairman => 'Chairman / owner',
        OfficialRole.secretary => 'Team secretary',
        OfficialRole.kitManager => 'Kit manager',
        OfficialRole.medicalOfficer => 'Medical officer / physio',
      };

  bool get isRequired =>
      this == OfficialRole.teamManager || this == OfficialRole.headCoach;
}

class Official {
  const Official({
    required this.role,
    required this.name,
    required this.phone,
    this.licence,
  });

  final OfficialRole role;
  final String name;
  final String phone;
  final String? licence;

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'name': name.trim(),
        'phone': phone,
        'licence': licence,
      };

  static Official? fromMap(Map<String, dynamic> map) {
    final role = OfficialRole.fromString(map['role'] as String?);
    if (role == null) return null;
    return Official(
      role: role,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      licence: map['licence'] as String?,
    );
  }
}