import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(Object error) {
  if (error is TimeoutException) {
    return 'This is taking too long. Check your connection and try again.';
  }

    if (error is UnsupportedError) {
    return 'Google sign-in is coming soon on Android. Use your email for now.';
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
              'popup-closed-by-user' ||
      'cancelled-popup-request' =>
        'Google sign-in was cancelled.',
      'popup-blocked' =>
        'Your browser blocked the Google window. Allow pop-ups for this site and try again.',
      'account-exists-with-different-credential' =>
        'This email already has an account. Log in with your email and password.',
      'operation-not-allowed' =>
        'Google sign-in is not available right now. Contact the GEDFA office.',
      'requires-recent-login' =>
        'For your safety, log out and log in again, then try once more.',
      'no-current-user' || 'user-token-expired' =>
        'You have been logged out. Please log in again.',
      'missing-email' => 'This account has no email address.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  return 'Something went wrong. Please try again.';

}

bool isInfoAuthError(Object error) {
  if (error is UnsupportedError) return true;

  return error is FirebaseAuthException &&
      (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request');
}