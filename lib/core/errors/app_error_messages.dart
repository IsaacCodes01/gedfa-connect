import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:gedfa_connect/features/auth/data/auth_error_messages.dart';

class TeamNameTakenException implements Exception {
  const TeamNameTakenException();
}

String appErrorMessage(Object error) {
  if (error is TeamNameTakenException) {
    return 'Another team already uses this name. Please choose a different one.';
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