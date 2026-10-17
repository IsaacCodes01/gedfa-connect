/// The competitions a club can enter. A club picks one or both.
enum Competition {
  division('Division', 'Third Division · senior league'),
  juvenile('Juvenile', 'Youth league · all three age groups');

  const Competition(this.label, this.description);

  final String label;
  final String description;

  /// Juvenile always means all three age groups.
  static const juvenileAgeGroups = ['U13', 'U15', 'U17'];

  static Competition? fromString(String? value) {
    for (final competition in values) {
      if (competition.name == value) return competition;
    }
    return null;
  }

  /// Reads `categories` from Firestore.
  /// Old requests saved before this field existed count as Division.
   static Set<Competition> fromList(List<dynamic>? raw) {
    final result = <Competition>{
      for (final item in raw ?? const []) ?fromString(item as String?),
    };
    return result.isEmpty ? {Competition.division} : result;
  }

  /// Writes `categories` for Firestore, always in the same order.
  static List<String> toList(Set<Competition> competitions) => [
        for (final competition in values)
          if (competitions.contains(competition)) competition.name,
      ];
}