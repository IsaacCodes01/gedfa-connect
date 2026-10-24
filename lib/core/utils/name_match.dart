// Name helpers for the FA's "possible duplicates" check (2.3c).
//
// The duplicate key (name + date of birth) only catches exact matches.
// These catch the near misses: "Kwame Asante" vs "Kwame Asante Jnr",
// "Kwame Asanteh" or "Asante Kwame".

/// Lower case, letters and spaces only, single spaces.
/// "  Kwame  ASANTE-Jnr. " → "kwame asante jnr"
String normalizeName(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z\s]'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

/// How many single-letter edits (add, remove, change) turn [a] into [b].
/// "asante" → "asanteh" = 1.
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [
        previous[j] + 1, // remove
        current[j - 1] + 1, // add
        previous[j - 1] + cost, // change
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}

/// True if two names probably belong to the same person:
/// - the same words in any order ("Asante Kwame"),
/// - one name inside the other ("Kwame Asante" / "Kwame Asante Jnr"),
/// - or at most 2 letters different ("Kwame Asante" / "Kwame Asanteh"),
/// - or the same surname-like word plus a first name that starts the same
///   ("K. Asante" is too short to trust, so at least 3 letters).
bool similarNames(String a, String b) {
  final x = normalizeName(a);
  final y = normalizeName(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;

  final xs = x.split(' ')..sort();
  final ys = y.split(' ')..sort();
  if (xs.join(' ') == ys.join(' ')) return true;

  if (x.contains(y) || y.contains(x)) return true;
  if (editDistance(x, y) <= 2) return true;

  // Two shared words of 3+ letters (e.g. "Kwame Asante Mensah" vs
  // "Kwame Mensah Asante Jnr")
  final shared =
      xs.where((w) => w.length >= 3 && ys.contains(w)).toSet().length;
  return shared >= 2;
}
