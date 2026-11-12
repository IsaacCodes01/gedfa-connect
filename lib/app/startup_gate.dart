import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The start-up screen shows for at least this long (Isaac, 12 Nov 2026):
/// the logo grows, then breathes. Longer only while the account loads.
const startupMinimum = Duration(milliseconds: 2500);

/// R-a2: the door of the start-up screen. Closed (false) when the app opens;
/// the router keeps everyone on the start-up screen until it opens. The
/// start-up screen opens it once the minimum time has passed and the next
/// screen's fonts and pictures are loaded, so nothing jumps or lags.
/// It stays open until the app is closed.
class StartupGate extends Notifier<bool> {
  @override
  bool build() => false;

  /// The page asked for when the app opened (a web refresh or a link), so
  /// the router can go there after the start-up screen.
  String? _wanted;

  /// True while the logo glides from the start-up screen into Log in: Log in
  /// then appears without its own transition and slides its card up.
  bool _glideToLogin = false;

  bool get glideToLogin => _glideToLogin;

  void rememberWanted(String location) => _wanted ??= location;

  String? takeWanted() {
    final wanted = _wanted;
    _wanted = null;
    return wanted;
  }

  /// Log in asks once (to slide its card up), then it is forgotten.
  bool takeGlide() {
    final glide = _glideToLogin;
    _glideToLogin = false;
    return glide;
  }

  void open({bool glideToLogin = false}) {
    if (state) return;
    _glideToLogin = glideToLogin;
    state = true;
  }
}

final startupGateProvider = NotifierProvider<StartupGate, bool>(
  StartupGate.new,
);
