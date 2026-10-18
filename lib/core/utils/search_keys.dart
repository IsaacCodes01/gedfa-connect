/// Builds the `searchKeys` list for a name: every word and each of its
/// beginnings from 2 letters, all lowercase, no repeats.
///
/// 'Kwame  Asante' → [kw, kwa, kwam, kwame, as, asa, asan, asant, asante]
List<String> searchKeysFor(String fullName) {
  final words = fullName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty);

  final keys = <String>{};
  for (final word in words) {
    if (word.length == 1) {
      keys.add(word);
      continue;
    }
    for (var end = 2; end <= word.length; end++) {
      keys.add(word.substring(0, end));
    }
  }
  return keys.toList();
}

/// Turns what someone typed into one search word, or null if too short.
/// 'Asa ' → 'asa'
String? normaliseSearch(String text) {
  final cleaned = text.trim().toLowerCase();
  return cleaned.length < 2 ? null : cleaned;
}
