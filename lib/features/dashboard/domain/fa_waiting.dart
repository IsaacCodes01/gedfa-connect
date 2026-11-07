/// What is waiting for the FA right now (the dashboard's "Needs you",
/// 2.12a). Each number opens its own screen.
class FaWaiting {
  const FaWaiting({
    required this.newTeams,
    required this.teamChanges,
    required this.players,
    required this.screening,
    required this.payments,
    required this.correctionsBack,
  });

  /// Team registration requests to review.
  final int newTeams;

  /// Teams with a name, short name, logo or competition change waiting.
  final int teamChanges;

  /// Division players to approve (new and changed).
  final int players;

  /// Juvenile players waiting for a screening day.
  final int screening;

  /// Season fee payments sent by teams, not confirmed yet.
  final int payments;

  /// Teams that sent back a correction the FA asked for (2.11b).
  final int correctionsBack;

  int get total =>
      newTeams + teamChanges + players + screening + payments + correctionsBack;

  bool get isEmpty => total == 0;
}
