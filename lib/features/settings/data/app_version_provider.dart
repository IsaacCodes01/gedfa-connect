import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The app's version from pubspec.yaml (e.g. "1.0.0"), read once.
///
/// Bump `version:` in pubspec.yaml and the About row follows by itself.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
