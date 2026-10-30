/// The season and its fee. The FA's chairman sets them in League settings
/// (2.13d); the app keeps the live values here so every screen can read
/// them. [apply] is called whenever `settings/league` changes.
class Season {
  Season._();

  /// Used until the league settings have loaded (and if they don't exist).
  static const defaultSeason = '2026-27';
  static const defaultFee = 1000;
  static const defaultMomoNumber = '0244-***-***';

  /// Saved in Firestore and used in document IDs: '2026-27'.
  static String current = defaultSeason;

  /// The affiliation fee, paid every season, in Ghana cedis.
  static int fee = defaultFee;

  /// GEDFA's MoMo number.
  static String momoNumber = defaultMomoNumber;

  /// Takes the values from the league settings.
  static void apply({
    required String season,
    required int fee,
    required String momoNumber,
  }) {
    current = season;
    Season.fee = fee;
    Season.momoNumber = momoNumber;
  }

  /// Shown to people: '2026/27'.
  static String label(String season) => season.replaceAll('-', '/');

  /// The year the season starts: '2026-27' -> 2026. Receipt numbers use it.
  static int startYear(String season) => int.parse(season.substring(0, 4));
}

/// 'GH₵ 1,000'
String cedis(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return 'GH₵ $buffer';
}
