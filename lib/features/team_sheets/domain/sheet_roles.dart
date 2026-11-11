import 'package:gedfa_connect/features/team_sheets/domain/sheet_picks.dart';

/// Step 2 of a team sheet (3.1b, mockups MS4, MS4b, MS4c): the captain,
/// vice-captain and goalkeeper for this match, and shirt numbers for this
/// match. Nothing here changes the players' registration or Profiles.
///
/// It holds what the team CHOSE. [fitTo] fits it to who is picked, so a
/// captain moved to the bench and back gets the armband back.
class SheetRoles {
  const SheetRoles({
    this.captainId,
    this.viceCaptainId,
    this.goalkeeperId,
    this.numbers = const {},
  });

  /// Must start (Isaac, 10 Nov 2026).
  final String? captainId;

  /// Any of the players on the sheet, never the captain. May be empty.
  final String? viceCaptainId;

  /// Any starter (Isaac, 10 Nov 2026); never changes the registered
  /// position.
  final String? goalkeeperId;

  /// Numbers that differ from a player's usual (registered) number:
  /// player ID → the number for this match.
  final Map<String, int> numbers;

  /// The captain's armband goes to [id]; the vice-captain loses it if it
  /// was theirs (one player can't hold both, as in Profiles).
  SheetRoles withCaptain(String id) => SheetRoles(
    captainId: id,
    viceCaptainId: viceCaptainId == id ? null : viceCaptainId,
    goalkeeperId: goalkeeperId,
    numbers: numbers,
  );

  /// [id] null = no vice-captain.
  SheetRoles withVice(String? id) => SheetRoles(
    captainId: captainId == id ? null : captainId,
    viceCaptainId: id,
    goalkeeperId: goalkeeperId,
    numbers: numbers,
  );

  SheetRoles withGoalkeeper(String id) => SheetRoles(
    captainId: captainId,
    viceCaptainId: viceCaptainId,
    goalkeeperId: id,
    numbers: numbers,
  );

  /// [id] wears [number] in this match; back to [usual] removes the change.
  SheetRoles withNumber(String id, int number, {required int usual}) =>
      SheetRoles(
        captainId: captainId,
        viceCaptainId: viceCaptainId,
        goalkeeperId: goalkeeperId,
        numbers: {
          for (final e in numbers.entries)
            if (e.key != id) e.key: e.value,
          if (number != usual) id: number,
        },
      );

  /// Fits the choices to [picks]:
  /// - the captain only if they start;
  /// - the vice-captain only if on the sheet (and not the captain);
  /// - the goalkeeper if they start; otherwise, when exactly one player
  ///   registered as a goalkeeper ([keepers]) starts, that player.
  SheetRoles fitTo(SheetPicks picks, {required Set<String> keepers}) {
    final starters = picks.starters;
    final picked = {...starters, ...picks.bench};
    final captain = starters.contains(captainId) ? captainId : null;
    final vice = picked.contains(viceCaptainId) && viceCaptainId != captain
        ? viceCaptainId
        : null;
    final keepersStarting = [
      for (final s in starters)
        if (keepers.contains(s)) s,
    ];
    final goalkeeper = starters.contains(goalkeeperId)
        ? goalkeeperId
        : keepersStarting.length == 1
        ? keepersStarting.single
        : null;
    return SheetRoles(
      captainId: captain,
      viceCaptainId: vice,
      goalkeeperId: goalkeeper,
      numbers: {
        for (final e in numbers.entries)
          if (picked.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// True when [goalkeeperId] was picked for the team by [fitTo] (the only
  /// registered goalkeeper starting), not chosen.
  bool keeperPickedFor(SheetRoles chosen) =>
      goalkeeperId != null && goalkeeperId != chosen.goalkeeperId;

  /// The shirt number of every picked player for this match: the changed
  /// one, or the usual one from [usual] (player ID → registered number).
  Map<String, int> numbersFor(SheetPicks picks, Map<String, int> usual) => {
    for (final id in [...picks.starters, ...picks.bench])
      id: numbers[id] ?? usual[id] ?? 0,
  };

  /// The numbers worn by more than one player: number → their IDs.
  static Map<int, List<String>> clashesIn(Map<String, int> numbers) {
    final byNumber = <int, List<String>>{};
    for (final e in numbers.entries) {
      (byNumber[e.value] ??= []).add(e.key);
    }
    return {
      for (final e in byNumber.entries)
        if (e.value.length > 1) e.key: e.value,
    };
  }

  /// Shirt numbers go from 1 to 99 (the rules check this too).
  static bool isValidNumber(int n) => n >= 1 && n <= 99;
}
