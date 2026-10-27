/// A team may list at most 7 officials: the team manager, the head coach
/// and up to 5 more (2.13).
const maxOfficials = 7;

enum OfficialRole {
  teamManager,
  headCoach,
  assistantCoach,
  chairman,
  secretary,
  kitManager,
  medicalOfficer,

  /// Not in the list: the club types the role (e.g. "Welfare officer").
  /// The only role that can be used more than once.
  other;

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
        OfficialRole.secretary => 'Secretary',
        OfficialRole.kitManager => 'Kit manager',
        OfficialRole.medicalOfficer => 'Medical officer',
        OfficialRole.other => 'Other',
      };

  bool get isRequired =>
      this == OfficialRole.teamManager || this == OfficialRole.headCoach;

  /// The roles the club can add (the chips under "Add an official").
  static const addable = [
    OfficialRole.assistantCoach,
    OfficialRole.chairman,
    OfficialRole.secretary,
    OfficialRole.kitManager,
    OfficialRole.medicalOfficer,
    OfficialRole.other,
  ];
}

class Official {
  const Official({
    required this.role,
    required this.name,
    required this.phone,
    this.title,
    this.licence,
  });

  final OfficialRole role;
  final String name;
  final String phone;

  /// The typed role, only for [OfficialRole.other].
  final String? title;
  final String? licence;

  /// "Head coach", or the typed role for Other.
  String get roleText {
    final typed = title?.trim();
    return role == OfficialRole.other && typed != null && typed.isNotEmpty
        ? typed
        : role.label;
  }

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'name': name.trim(),
        'phone': phone,
        if (role == OfficialRole.other) 'title': title?.trim(),
        'licence': licence,
      };

  static Official? fromMap(Map<String, dynamic> map) {
    final role = OfficialRole.fromString(map['role'] as String?);
    if (role == null) return null;
    return Official(
      role: role,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      title: map['title'] as String?,
      licence: map['licence'] as String?,
    );
  }
}
