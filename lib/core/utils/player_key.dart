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
/// competition + '-' + number, e.g. 'division-10'.
/// Division and Juvenile squads each have their own numbers.
String jerseyIdFor(String category, int jerseyNo) => '$category-$jerseyNo';
