const _ignoredWords = {'fc', 'sc', 'club', 'the'};

String suggestShortName(String teamName) {
  final words = teamName
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((word) => word.replaceAll(RegExp(r'[^a-z]'), ''))
      .where((word) => word.isNotEmpty && !_ignoredWords.contains(word))
      .toList();

  if (words.isEmpty) return '';

  final String suggestion;
  if (words.length >= 3) {
    suggestion = words.take(3).map((word) => word[0]).join();
  } else if (words.length == 2) {
    final second = words[1];
    suggestion = words[0][0] + second.substring(0, second.length < 2 ? 1 : 2);
  } else {
    final word = words[0];
    suggestion = word.substring(0, word.length < 3 ? word.length : 3);
  }
  return suggestion.toUpperCase();
}