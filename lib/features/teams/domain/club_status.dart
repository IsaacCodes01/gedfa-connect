/// Is the club already in Gomoa East, or joining the district? (2.13)
///
/// A new club must say which league it played in last season and upload
/// a letter to the GEDFA chairman. Clubs already in the district don't.
enum ClubStatus {
  existing('existing'),
  newClub('new');

  const ClubStatus(this.value);

  /// What is saved in Firestore ('existing' or 'new').
  final String value;

  /// Requests sent before 2.13 have no status: they were district clubs.
  static ClubStatus fromString(String? value) =>
      value == 'new' ? ClubStatus.newClub : ClubStatus.existing;

  String get label => switch (this) {
        ClubStatus.existing => 'Already in the district',
        ClubStatus.newClub => 'New club joining the district',
      };

  /// The second line on the choice card.
  String get description => switch (this) {
        ClubStatus.existing =>
          'We played in Gomoa East before. No letter needed.',
        ClubStatus.newClub =>
          'Upload a letter to the chairman and tell us your last league.',
      };

  /// Short text for the review screens.
  String get shortLabel => switch (this) {
        ClubStatus.existing => 'Already in the district',
        ClubStatus.newClub => 'New club joining',
      };
}
