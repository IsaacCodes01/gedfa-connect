import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:gedfa_connect/features/auth/data/auth_error_messages.dart';

class TeamNameTakenException implements Exception {
  const TeamNameTakenException();
}

/// The juvenile side's own name is already another club's (JSb).
class JuvenileNameTakenException implements Exception {
  const JuvenileNameTakenException();
}

/// Another player in this squad already wears this number.
class JerseyTakenException implements Exception {
  const JerseyTakenException(this.number);
  final int number;
}

/// Passing a child in an older group (2.14c), but their jersey number is
/// already worn by another child of the team in that group.
class MoveUpJerseyTakenException implements Exception {
  const MoveUpJerseyTakenException(this.number, this.group);
  final int number;
  final String group;
}

/// A player with the same name and date of birth is already registered
/// (with this team or another one).
class DuplicatePlayerException implements Exception {
  const DuplicatePlayerException({required this.sameTeam});
  final bool sameTeam;
}

/// The FA tried to review a player who is no longer pending
/// (someone else reviewed them, or the team changed them meanwhile).
class PlayerNotPendingException implements Exception {
  const PlayerNotPendingException();
}

/// The FA tried to confirm a payment that is no longer waiting
/// (another FA official reviewed it first).
class PaymentNotWaitingException implements Exception {
  const PaymentNotWaitingException();
}

/// This email already has an open invitation.
class InviteExistsException implements Exception {
  const InviteExistsException();
}

/// This email already belongs to an FA admin or referee.
class AlreadyMemberException implements Exception {
  const AlreadyMemberException();
}

/// A team sheet can't change any more: it locked 1 hour before kick-off,
/// or the match was postponed or cancelled (3.1a2).
class SheetLockedException implements Exception {
  const SheetLockedException();
}

String appErrorMessage(Object error) {
  if (error is SheetLockedException) {
    return 'This team sheet is locked: it closed 1 hour before kick-off, '
        'or the match is no longer scheduled.';
  }
  if (error is InviteExistsException) {
    return 'This email already has an open invitation. Share it again from '
        'the Invited tab, or cancel it first.';
  }
  if (error is AlreadyMemberException) {
    return 'This email already belongs to an FA admin or referee.';
  }
  if (error is PaymentNotWaitingException) {
    return 'This payment has already been reviewed. Go back and open it again.';
  }
  if (error is PlayerNotPendingException) {
    return 'This player has already been reviewed or changed. '
        'Go back and open them again.';
  }
  if (error is JuvenileNameTakenException) {
    return 'Another club already uses this juvenile side name. '
        'Please choose a different one.';
  }
  if (error is TeamNameTakenException) {
    return 'Another team already uses this name. Please choose a different one.';
  }
  if (error is JerseyTakenException) {
    return '#${error.number} is already taken in your squad. '
        'Choose another number.';
  }
  if (error is MoveUpJerseyTakenException) {
    return '#${error.number} is already worn by another ${error.group} player '
        'of this team. Ask the team to change one of the numbers, then pass '
        'the child.';
  }
  if (error is DuplicatePlayerException) {
    return error.sameTeam
        ? 'This player is already in your squad.'
        : 'A player with this name and date of birth is already registered '
            'with another team. Contact the FA if this is a transfer.';
  }
  if (error is FirebaseAuthException || error is TimeoutException) {
    return authErrorMessage(error);
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' || 'unauthorized' =>
        "You're not allowed to do that. If you just confirmed your email, log out and log in again.",
      'unavailable' || 'network-request-failed' || 'retry-limit-exceeded' =>
        'No internet connection. Check your data or Wi-Fi and try again.',
      'failed-precondition' =>
        'The database is still being set up. Please try again in a few minutes.',
      'canceled' => 'The upload was cancelled.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
