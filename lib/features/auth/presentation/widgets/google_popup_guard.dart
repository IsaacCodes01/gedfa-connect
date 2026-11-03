import 'dart:async';

import 'package:flutter/widgets.dart';

/// Stops the "Continue with Google" spinner when the person closes the
/// Google window without signing in.
///
/// Why it's needed: Firebase finds out the window was closed by checking
/// it every so often. Some browsers (and the Auth emulator's sign-in page)
/// block that check, so `signInWithPopup` never finishes and the spinner
/// turns forever.
///
/// How it works: opening the Google window takes the focus away from our
/// app (the app becomes "inactive"). When the person comes back to the
/// app ("resumed") and sign-in still hasn't finished [grace] later, we
/// treat it as cancelled and call [onGaveUp].
class GooglePopupGuard {
  GooglePopupGuard({
    required this.onGaveUp,
    this.grace = const Duration(seconds: 4),
  });

  final VoidCallback onGaveUp;
  final Duration grace;

  AppLifecycleListener? _listener;
  Timer? _timer;
  bool _leftApp = false;

  /// Call just before opening the Google window.
  void start() {
    stop();
    _leftApp = false;
    _listener = AppLifecycleListener(
      // The Google window took the focus
      onInactive: () {
        _leftApp = true;
        _timer?.cancel();
      },
      // Back in our app: give Firebase a moment to finish first
      onResume: () {
        if (!_leftApp) return;
        _timer?.cancel();
        _timer = Timer(grace, onGaveUp);
      },
    );
  }

  /// Call when sign-in finished (signed in, failed or cancelled).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _listener?.dispose();
    _listener = null;
  }
}
