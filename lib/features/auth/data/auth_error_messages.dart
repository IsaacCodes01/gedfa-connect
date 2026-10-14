import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(Object error) {
  if (error is TimeoutException) {
    return 'This is taking too long. Check your connection and try again.';
  }

  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Email or password is incorrect.',
      'invalid-email' => "That email address doesn't look right.",
      'user-disabled' =>
        'This account has been disabled. Contact the GEDFA office.',
      'email-already-in-use' =>
        'An account with this email already exists. Try logging in instead.',
      'weak-password' => 'Choose a stronger password (at least 8 characters).',
      'too-many-requests' =>
        'Too many attempts. Please wait a few minutes and try again.',
      'network-request-failed' =>
        'No internet connection. Check your data or Wi-Fi and try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  return 'Something went wrong. Please try again.';
}