import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// How a club's side is called in a competition (juvenile side names,
/// GEDFA 8 Nov 2026, mockup JS1–JS6).
///
/// A club in BOTH competitions keeps one name for its Division side. Its
/// juvenile sides (U13, U15 and U17 alike) play as:
/// - its own juvenile name, once it has one ("Royal Unique Colts", "RUC"),
/// - otherwise its name with " B" ("Royal Unique FC B", "RUF B").
///
/// A club in one competition plays under its own name everywhere.
/// The rules work it out the same way (`sideNameOf` in firestore.rules).
({String name, String shortName}) sideNames({
  required String name,
  required String shortName,
  required Set<Competition> categories,
  required Competition category,
  String? juvenileName,
  String? juvenileShortName,
}) {
  final isJuvenileOfBoth =
      category == Competition.juvenile && categories.length > 1;
  if (!isJuvenileOfBoth) return (name: name, shortName: shortName);
  if (juvenileName != null && juvenileName.isNotEmpty) {
    return (name: juvenileName, shortName: juvenileShortName ?? shortName);
  }
  return (name: '$name B', shortName: '$shortName B');
}

/// A "B" side's short name ends with " B" ("RUF B"); an own short name is
/// 3–4 capitals with no space, so the two can never be mixed up.
bool isBSideShortName(String shortName) => shortName.endsWith(' B');
