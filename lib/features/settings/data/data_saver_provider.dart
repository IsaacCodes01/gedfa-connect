import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';

/// Data saver: when on, lists show initials instead of downloading player
/// photos. Opening a player still shows their passport photo.
///
/// Saved on this phone, like the theme. Off by default.
class DataSaverNotifier extends Notifier<bool> {
  static const _key = 'dataSaver';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;
  }

  Future<void> setOn(bool on) async {
    state = on;
    await ref.read(sharedPreferencesProvider).setBool(_key, on);
  }
}

final dataSaverProvider =
    NotifierProvider<DataSaverNotifier, bool>(DataSaverNotifier.new);
