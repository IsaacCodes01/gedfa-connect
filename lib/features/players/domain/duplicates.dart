import 'package:gedfa_connect/core/utils/name_match.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';

/// Another player who might be the same person (FA review, 2.3c).
class PossibleDuplicate {
  const PossibleDuplicate(this.player, this.reason);

  final Player player;
  final String reason;
}

/// Players who might be the same person as [player]:
/// 1. the same date of birth and a similar name ("Kwame Asante Jnr"), or
/// 2. exactly the same name and a date of birth within 2 years (a typo
///    in the date, or a wrong year).
///
/// Exact matches (same name AND date of birth) never get this far: the
/// player key already blocks them when the team saves.
List<PossibleDuplicate> possibleDuplicates(
  Player player,
  Iterable<Player> others,
) {
  final name = normalizeName(player.fullName);
  final results = <PossibleDuplicate>[];

  for (final other in others) {
    if (other.id == player.id) continue;

    final sameDob = other.dob == player.dob;
    if (sameDob && similarNames(player.fullName, other.fullName)) {
      results.add(PossibleDuplicate(other, 'Same date of birth, similar name'));
      continue;
    }

    final yearsApart = (other.dob.difference(player.dob).inDays / 365).abs();
    if (normalizeName(other.fullName) == name && yearsApart <= 2) {
      results.add(PossibleDuplicate(other, 'Same name, different date of birth'));
    }
  }
  return results;
}
