import 'package:web/web.dart' as web;

/// Web version: a new tab, opened during the tap so Safari allows it.
Future<bool> openLink(String url) async {
  web.window.open(url, '_blank');
  return true;
}
