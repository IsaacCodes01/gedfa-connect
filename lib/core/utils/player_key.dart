/// The key that stops the same person being registered twice:
/// normalised full name + '_' + date of birth.
///
/// 'Kwame  ASANTE', 15 Mar 2004  →  'kwame-asante_2004-03-15'
String playerKeyFor(String fullName, DateTime dob) {
  final name = fullName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '-') // spaces → one dash
      .replaceAll(RegExp(r'[^a-z0-9-]'), '') // drop anything else
      .replaceAll(RegExp(r'-+'), '-') // no double dashes
      .replaceAll(RegExp(r'^-|-$'), ''); // no dash at the ends

  final year = dob.year.toString().padLeft(4, '0');
  final month = dob.month.toString().padLeft(2, '0');
  final day = dob.day.toString().padLeft(2, '0');

  return '${name}_$year-$month-$day';
}

/// The ID of a jersey reservation inside a team:
/// 'division-10', or for a juvenile side 'juvenile-U13-10'.
/// Division and each juvenile age group have their own numbers.
/// Must match jerseyIdOf in firestore.rules.
String jerseyIdFor(String category, int jerseyNo, {String? ageGroup}) =>
    ageGroup == null || category != 'juvenile'
        ? '$category-$jerseyNo'
        : '$category-$ageGroup-$jerseyNo';

/// The duplicate-check key for a competition. A 16- or 17-year-old may
/// play for a club's Division AND Juvenile sides (GEDFA, 30 Oct 2026),
/// so juvenile players get their own key: 'kofi-mensah_2010-03-15_juvenile'.
String competitionPlayerKey(String baseKey, String category) =>
    category == 'juvenile' ? '${baseKey}_juvenile' : baseKey;
