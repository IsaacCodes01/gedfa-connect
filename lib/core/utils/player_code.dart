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
