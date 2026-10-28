/// The season and its fee (2.13c). Moves to the FA's league settings in
/// 2.13d; until then it lives here.
class Season {
  Season._();

  /// Saved in Firestore and used in document IDs: '2026-27'.
  static const current = '2026-27';

  /// Shown to people: '2026/27'.
  static String label(String season) => season.replaceAll('-', '/');

  /// The year the season starts: '2026-27' -> 2026. Receipt numbers use it.
  static int startYear(String season) => int.parse(season.substring(0, 4));

  /// The affiliation fee, paid every season, in Ghana cedis.
  static const fee = 1000;

  /// GEDFA's MoMo number. The FA will give the real one later.
  static const momoNumber = '0244-***-***';
}

/// 'GH₵ 1,000'
String cedis(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return 'GH₵ $buffer';
}
