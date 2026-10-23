import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:gedfa_connect/features/auth/data/auth_error_messages.dart';

class TeamNameTakenException implements Exception {
  const TeamNameTakenException();
}

/// Another player in this squad already wears this number.
class JerseyTakenException implements Exception {
  const JerseyTakenException(this.number);
  final int number;
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

String appErrorMessage(Object error) {
  if (error is PlayerNotPendingException) {
    return 'This player has already been reviewed or changed. '
        'Go back and open them again.';
  }
  if (error is TeamNameTakenException) {
    return 'Another team already uses this name. Please choose a different one.';
  }
  if (error is JerseyTakenException) {
    return '#${error.number} is already taken in your squad. '
        'Choose another number.';
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
      'canceled' => 'The upload was cancelled.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
