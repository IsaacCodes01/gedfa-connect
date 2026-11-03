/// The permanent player ID: 'GE' + two-digit year + '-' + 4-digit number.
///
/// playerCodeFor(43, 2026) -> 'GE26-0043'
///
/// The year is the year of the player's FIRST approval. The security rules
/// build the same text (playerCodeFor in firestore.rules), so both must
/// stay the same.
String playerCodeFor(int number, int year) {
  final yy = (year % 100).toString().padLeft(2, '0');
  final nnnn = number.toString().padLeft(4, '0');
  return 'GE$yy-$nnnn';
}

/// A juvenile player's ID (2.14c): 'GJ' instead of 'GE', with its own
/// counter. juvenilePlayerCodeFor(1, 2026) -> 'GJ26-0001'.
/// Must match juvenileCodeFor in firestore.rules.
String juvenilePlayerCodeFor(int number, int year) =>
    'GJ${playerCodeFor(number, year).substring(2)}';
