import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';

/// R-b (Isaac, 12 Nov 2026): the intro shows **once per phone or browser**,
/// the first time the app opens after installing. Remembered on the device
/// (shared preferences), not in Firestore: it is about the phone, not the
/// person.
class IntroSeenNotifier extends Notifier<bool> {
  static const key = 'introSeen';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? false;

  /// Get started, Skip, or anyone already signed in on this device.
  Future<void> markSeen() async {
    if (state) return;
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(key, true);
  }
}

final introSeenProvider = NotifierProvider<IntroSeenNotifier, bool>(
  IntroSeenNotifier.new,
);
