import 'package:url_launcher/url_launcher.dart';

/// Android and iOS app version: url_launcher opens the dialler.
Future<bool> callPhone(String number) {
  return launchUrl(Uri(scheme: 'tel', path: number));
}
