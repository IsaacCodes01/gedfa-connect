import 'package:url_launcher/url_launcher.dart';

/// App version: hand the link to the phone (WhatsApp opens for wa.me).
Future<bool> openLink(String url) {
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
